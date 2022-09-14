//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

// Default values for ports not used in this core
assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

assign AUDIO_S = 0;
assign AUDIO_L = 0;
assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

// Configuration String
`include "build_id.v"
localparam CONF_STR = {
	"A.TROPANG;;",
	"-;",
	"O[4:3],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O[5:3],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"H0O[2],Orientation,Vert,Horz;",
	"-;",
	"DIP;",
	"-;",
	"R[0],Reset;",
	"J1,Gas,Trick,Start,Coin;",
	"jn,A,B,Start,Select;",
	"V,v",`BUILD_DATE
};

// HPS
logic [127:0] status;
logic   [1:0] buttons;
logic         forced_scandoubler;
logic         direct_video;
logic         ioctl_download;
logic         ioctl_wr;
logic  [24:0] ioctl_addr;
logic   [7:0] ioctl_dout;
logic   [7:0] ioctl_index;
logic  [15:0] joystick_0,joystick_1;
logic  [21:0] gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_menumask(direct_video),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1)
);

// Clocks
logic clk_36, clk_48, pll_locked;
logic clk_sys = clk_36;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_48),
	.outclk_1(clk_36),
	.locked(pll_locked)
);

logic reset;
always_ff @(posedge clk_sys) reset <=(RESET | status[0] | buttons[1] | ioctl_download);

// ROM Loading

/* ROM structure
00000 - 07FFF main CPU    32k  ta-a-3k ta-a-3m ta-a-3n ta-a-3q
08000 - 09FFF  snd CPU     8k  ta-s-1a
0A000 - 0FFFF gfx1        24k  ta-a-3e ta-a-3d ta-a-3c
10000 - 1BFFF gfx2        48k  ta-b-5j ta-b-5h ta-b-5e ta-b-5d ta-b-5c ta-b-5a
1C000 - 1C0FF chr pal lo 256b  ta-a-5a
1C100 - 1C1FF chr pal hi 256b  ta-a-5b
1C200 - 1C2FF spr pal    256b  ta-b-3d
1C300 - 1C31F spr lut     32b  ta-b-1b
*/

// Inputs
logic m_up_1    = joystick_0[3];
logic m_down_1  = joystick_0[2];
logic m_left_1  = joystick_0[1];
logic m_right_1 = joystick_0[0];
logic m_gas_1   = joystick_0[4];
logic m_trick_1 = joystick_0[5];
logic m_start_1 = joystick_0[6];
logic m_coin_1  = joystick_0[7];

logic m_up_2    = joystick_1[3];
logic m_down_2  = joystick_1[2];
logic m_left_2  = joystick_1[1];
logic m_right_2 = joystick_1[0];
logic m_gas_2   = joystick_1[4];
logic m_trick_2 = joystick_1[5];
logic m_start_2 = joystick_1[6];
logic m_coin_2  = joystick_1[7];

// Video
logic [1:0] ar = status[122:121];
assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

logic hblank, vblank;
logic hs, vs;
logic [1:0] rs;
logic [2:0] g;
logic [2:0] b;
logic [2:0] r={rs,1'b0};

logic ce_pix;
always_ff @(posedge clk_48) begin
	logic [2:0] div;
	div <= div + 1'd1;
	ce_pix <= !div;
end

arcade_video #(384,9) arcade_video
(
	.*,

	.clk_video(clk_48),
	.RGB_in({r,g,b}),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),
	.fx(status[5:3])
);

// Audio
logic [10:0] audio;
assign AUDIO_L = {audio, 5'd0};
assign AUDIO_R = {audio, 5'd0};
assign AUDIO_S = 0;

logic aud_ce;
always_ff @(posedge clk_36) begin
	logic [15:0] sum;
	aud_ce = 0;
	sum = sum + 16'd895;
	if(sum >= 36000) begin
		sum = sum - 16'd36000;
		aud_ce = 1;
	end
end

// Core
TropicalAngel TropicalAngel
(
	.clock_36(clk_36),
	.ce_0p895(aud_ce),
	.reset(reset),
	.video_r(rs),
	.video_g(g),
	.video_b(b),
	.video_hs(hs),
	.video_vs(vs),
	.video_hblank(hblank),
	.video_vblank(vblank),
	.audio_out(audio),
	.dip_switch_1(sw[0]),
	.dip_switch_2(sw[1]),
	.input_0(~{4'd0, m_coin_1, 1'b0 /*service*/, m_start_2, m_start_1}),
	.input_1(~{m_gas_1, 1'b0, m_trick_1, 1'b0, m_up_1, m_down_1, m_left_1, m_right_1}),
	.input_2(~{m_gas_2, 1'b0, m_trick_2, m_coin_2, m_up_2, m_down_2, m_left_2, m_right_2})
	.dl_clk(clk_sys),
	.dl_addr(ioctl_addr[16:0]),
	.dl_data(ioctl_dout),
	.dl_wr(ioctl_wr && !ioctl_index)
);

endmodule
