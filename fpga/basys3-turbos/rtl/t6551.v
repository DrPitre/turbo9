// [TURBO9_HEADER_START]
//////////////////////////////////////////////////////////////////////////////
//                          Turbo9 Microprocessor IP
//////////////////////////////////////////////////////////////////////////////
// Website: www.turbo9.org
// Contact: team[at]turbo9[dot]org
//////////////////////////////////////////////////////////////////////////////
// [TURBO9_LICENSE_START]
// BSD-1-Clause
//
// Copyright (c) 2020-2023
// Kevin Phillipson
// Michael Rywalt
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS AND CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
// [TURBO9_LICENSE_END]
//////////////////////////////////////////////////////////////////////////////
// Engineer: Kevin Phillipson
// Description: 6551 compatible UART
//
//////////////////////////////////////////////////////////////////////////////
// History:
// 07.14.2023 - Kevin Phillipson
//   File header added
//
//////////////////////////////////////////////////////////////////////////////
// [TURBO9_HEADER_END]

/////////////////////////////////////////////////////////////////////////////
//                                MODULE
/////////////////////////////////////////////////////////////////////////////
`include "turbo9_rtl_config.vh"

module t6551
(
  // Inputs: Clock & Reset
  input          RST_I,
  input          CLK_I,

  // Inputs
  input [ 7:0]   TX_DATA_I,
  input          TX_DATA_WR_EN_I,
  input          RXD_PIN_I,
  input          RX_DATA_RD_EN_I,

  // Outputs
  output         TXD_PIN_O,
  output [ 7:0]  RX_DATA_O,
  output [ 7:0]  STATUS_DATA_O
);


/////////////////////////////////////////////////////////////////////////////
//                             INTERNAL SIGNALS
/////////////////////////////////////////////////////////////////////////////
reg [2:0] frac_cycle_cnt_reg;
localparam frac_cycle_cnt_rst = 3'b000;

reg   [5:0] baud_div_cnt_reg;
localparam  baud_div_cnt_rst = 6'h00;

wire				baud_div_en;
reg         baud_div_en_reg;
localparam  baud_div_en_rst = 1'b0;

wire  rx_overrun;
wire  rx_framing_error;
wire  rx_data_reg_full;
wire  tx_data_reg_empty;

/////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////
//                        1.8432MHz CLOCK ENABLE
/////////////////////////////////////////////////////////////////////////////
//
// 50 MHz / 27.125 gives a 1.843318 MHz enable for 115200 baud.
// Use divisor 28 once per eight enables and divisor 27 for the rest.
// Counts are divisor minus one because the terminal count is zero.
//
`ifdef TURBO9_RTL_SYNC_RESET
always @(posedge CLK_I) begin
`else
always @(posedge CLK_I, posedge RST_I) begin
`endif
  if (RST_I) begin
    baud_div_cnt_reg    <= baud_div_cnt_rst;
    frac_cycle_cnt_reg  <= frac_cycle_cnt_rst;
    baud_div_en_reg     <= baud_div_en_rst;
  end else begin

    if (baud_div_cnt_reg == 6'd0) begin
      //
      if (frac_cycle_cnt_reg == 3'd0) begin
        baud_div_cnt_reg <= 6'd27;
      end else begin
        baud_div_cnt_reg <= 6'd26;
      end
      //
      frac_cycle_cnt_reg  <= frac_cycle_cnt_reg - 'd1;
      //
      baud_div_en_reg     <= 1'b1;
    end else begin
      baud_div_cnt_reg    <= baud_div_cnt_reg - 6'd1;
      baud_div_en_reg     <= 1'b0;
    end

  end
end

`ifdef TURBO9_RTL_SIM_T6551_FAST
assign baud_div_en = 1'b1;
`else
assign baud_div_en = baud_div_en_reg;
`endif

//
/////////////////////////////////////////////////////////////////////////////


/////////////////////////////////////////////////////////////////////////////
//                       Receive & Transmit
/////////////////////////////////////////////////////////////////////////////
t6551_rx I_t6551_rx
(
  // Inputs: Clock & Reset
  .RST_I                (RST_I            ),
  .CLK_I                (CLK_I            ),

  // Inputs
  .PROG_RST_I           (1'b0             ),
  .RXD_PIN_I            (RXD_PIN_I        ),
  .BAUD_DIV_EN_I        (baud_div_en      ),
  .RX_DATA_REG_RD_EN_I  (RX_DATA_RD_EN_I  ),

  // Outputs
  .RX_OVERRUN_O         (rx_overrun       ),
  .RX_FRAMING_ERROR_O   (rx_framing_error ),
  .RX_DATA_REG_FULL_O   (rx_data_reg_full ),
  .RX_DATA_REG_O        (RX_DATA_O        )
);


t6551_tx I_t6551_tx
(
  // Inputs: Clock & Reset
  .RST_I                (RST_I              ),
  .CLK_I                (CLK_I              ),

  // Inputs
  .BAUD_DIV_EN_I        (baud_div_en        ),
  .TX_DATA_I            (TX_DATA_I          ),
  .TX_DATA_REG_WR_EN_I  (TX_DATA_WR_EN_I    ),

  // Outputs
  .TXD_PIN_O            (TXD_PIN_O          ),
  .TX_DATA_REG_EMPTY_O  (tx_data_reg_empty  )
);



/////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////
//                             ASSIGN OUTPUTS
/////////////////////////////////////////////////////////////////////////////

assign STATUS_DATA_O[7] = 1'b0; // IRQ
assign STATUS_DATA_O[6] = 1'b0; // ~DSR
assign STATUS_DATA_O[5] = 1'b0; // ~DCD
assign STATUS_DATA_O[4] = tx_data_reg_empty;
assign STATUS_DATA_O[3] = rx_data_reg_full;
assign STATUS_DATA_O[2] = rx_overrun;
assign STATUS_DATA_O[1] = rx_framing_error;
assign STATUS_DATA_O[0] = 1'b0; // Parity Error

/////////////////////////////////////////////////////////////////////////////

endmodule
