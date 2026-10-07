// Turbo9S TurbOS SoC: shared aligned 16-bit Wishbone memory bus,
// 64 KiB initialized RAM, 60 Hz timer and 115200-baud terminal.
module soc_turbos #(
  parameter CLOCK_HZ = 50000000,
  parameter EVEN_FILE = "turbos_even.hex",
  parameter ODD_FILE = "turbos_odd.hex"
)(
  input HARD_RST_I, SOFT_RST_I, CLK_I,
  input RXD_PIN_I,
  output TXD_PIN_O,
  output [7:0] GPO_PORT_O
);
  wire reset = HARD_RST_I | SOFT_RST_I;
  wire [15:0] address, write_data;
  wire [1:0] lanes;
  wire [4:0] request_tag;
  wire we, strobe;
  reg ack;
  reg [4:0] response_tag;
  reg [7:0] ram_even, ram_odd;
  reg [15:0] io_data;
  reg io_read;
  wire [7:0] uart_rx, uart_status;
  wire io_select = address == 16'hff00 || address == 16'hff02;
  // UART empty is registered. Freeze the shared bus and its response while
  // the transmit holding register is occupied; each transfer occurs once.
  wire busy = !uart_status[4];
  wire accept = strobe && !busy && !reset;
  wire tx_write = accept && we && address == 16'hff00 && lanes[1];
  wire status_write = accept && we && address == 16'hff02 && lanes[1];
  wire rx_ack = status_write && write_data[9];
  reg [7:0] control;
  reg timer_pending;
  reg [$clog2(CLOCK_HZ)-1:0] timer_phase;
  wire [$clog2(CLOCK_HZ):0] phase_next = {1'b0,timer_phase} + 60;
  wire timer_tick = control[0] && phase_next >= CLOCK_HZ;
  wire [7:0] status = {6'b0, uart_status[3], timer_pending};
  wire irq_n = !(|(status[1:0] & control[1:0]));
  reg [7:0] ticks;

  // Single shared RAM port. The Turbo9S Wishbone bridge arbitrates instruction
  // and data requests, and splits unaligned words into two aligned transfers.
  (* ram_style = "block" *) reg [7:0] even_mem [0:32767];
  (* ram_style = "block" *) reg [7:0] odd_mem [0:32767];
  initial begin $readmemh(EVEN_FILE, even_mem); $readmemh(ODD_FILE, odd_mem); end
  always @(posedge CLK_I) begin
    if (!busy) begin
      ram_even <= even_mem[address[15:1]];
      ram_odd <= odd_mem[address[15:1]];
      if (accept && we && !io_select) begin
        if (lanes[1]) even_mem[address[15:1]] <= write_data[15:8];
        if (lanes[0]) odd_mem[address[15:1]] <= write_data[7:0];
      end
    end
  end
  always @(posedge CLK_I) begin
    if (reset) begin
      ack <= 0; response_tag <= 0; io_read <= 0; io_data <= 0;
    end else if (!busy) begin
      ack <= strobe;
      response_tag <= strobe ? request_tag : 5'b0;
      io_read <= io_select;
      case (address)
        16'hff00: io_data <= {8'b0, uart_rx};
        16'hff02: io_data <= {status, control};
        default: io_data <= 0;
      endcase
    end
  end
  always @(posedge CLK_I) begin
    if (reset) begin
      control <= 0; timer_pending <= 0; timer_phase <= 0; ticks <= 0;
    end else begin
      if (accept && we && address == 16'hff02 && lanes[0]) control <= write_data[7:0];
      if (!control[0]) timer_phase <= 0;
      else if (timer_tick) timer_phase <= phase_next - CLOCK_HZ;
      else timer_phase <= phase_next[$clog2(CLOCK_HZ)-1:0];
      if (status_write && write_data[8]) timer_pending <= 0;
      if (timer_tick) begin timer_pending <= 1; ticks <= ticks + 1'b1; end
    end
  end
  t6551 uart (
    .RST_I(reset), .CLK_I(CLK_I), .TX_DATA_I(write_data[15:8]),
    .TX_DATA_WR_EN_I(tx_write), .RXD_PIN_I(RXD_PIN_I),
    .RX_DATA_RD_EN_I(rx_ack), .TXD_PIN_O(TXD_PIN_O),
    .RX_DATA_O(uart_rx), .STATUS_DATA_O(uart_status)
  );
  turbo9_s #(.TURBO9_CPU_WB_PIPELINE_REG(1), .TURBO9_CPU_QUEUE_SIZE(6)) cpu (
    .RST_I(reset), .CLK_I(CLK_I), .IRQ_N_I(irq_n), .FIRQ_N_I(1'b1), .NMI_N_I(1'b1),
    .DAT_I(io_read ? io_data : {ram_even,ram_odd}), .TGD_I(response_tag),
    .ACK_I(ack), .STALL_I(busy), .ADR_O(address), .DAT_O(write_data),
    .SEL_O(lanes), .TGD_O(request_tag), .WE_O(we), .STB_O(strobe), .CYC_O()
  );
  assign GPO_PORT_O = {ticks[5], control[1:0], timer_pending, 4'b0};
endmodule
