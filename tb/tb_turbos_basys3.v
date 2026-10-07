`timescale 1ns/1ps
module tb_turbos_board;
  parameter TX_STALL = 0;
  integer cycles=0;
  reg clk=0; always #20 clk=~clk;
  reg reset=1;
  wire tx;
  soc_turbos #(.CLOCK_HZ(300000)) dut(.CLK_I(clk),.HARD_RST_I(reset),.SOFT_RST_I(1'b0),.RXD_PIN_I(1'b1),.TXD_PIN_O(tx),.GPO_PORT_O());
  reg rx_ready=0;
  reg [7:0] rx_data=0;
  wire tx_ready = !TX_STALL || cycles % 5000 >= 2500;
  wire [7:0] test_status={3'b0,tx_ready,rx_ready,3'b0};
  reg [47:0] command_bytes={"mfree",8'h0d};
  reg [71:0] tail=0;
  integer prompts=0, input_count=0, timer_acks=0, rx_acks=0;
  reg result_seen=0;
  always @(posedge clk) if (!reset) begin
    cycles=cycles+1;
    if (dut.accept && dut.address[0]) $fatal(1,"unaligned Wishbone request");
    if (dut.tx_write) begin
      $write("%c",dut.write_data[15:8]);
      tail={tail[63:0],dut.write_data[15:8]};
      if (tail[31:0]=="TOS:") prompts=prompts+1;
      if (tail=="pages fre") result_seen=1;
    end
    if (dut.status_write && dut.write_data[8]) timer_acks=timer_acks+1;
    if (dut.rx_ack) begin rx_ready<=0; rx_acks=rx_acks+1; end
    if (prompts>0 && input_count<6 && !rx_ready && cycles%5000==0) begin
      rx_data<=command_bytes[47:40]; command_bytes<={command_bytes[39:0],8'b0};
      input_count=input_count+1; rx_ready<=1;
    end
    if (prompts>=2 && result_seen && rx_acks==6 && timer_acks>5) begin
      $display("\nPASS board SoC: shell, mfree, %0d RX IRQs, %0d timer IRQs",rx_acks,timer_acks); $finish;
    end
    if (cycles>800000) $fatal(1,"timeout PC=%h prompts=%0d timer=%0d rx=%0d",dut.cpu.I_turbo9_pipeline.I_turbo9_execute_stage.I_turbo9_register_array.pc_reg,prompts,timer_acks,rx_acks);
  end
  initial begin
    force dut.uart_status=test_status;
    force dut.uart_rx=rx_data;
    repeat(10) @(negedge clk); reset=0;
  end
endmodule
