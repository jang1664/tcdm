
`timescale 1ns / 1ps

`define WAIT_POSEDGE(clk) @(posedge clk_i); #(1);

module tb_ping_pong_buffer;
//   import npu_global_params::*;
//   import npu_pkg::*;
//   import ipp_pkg::*;
//   import psp_pkg::*;
//   import cu_pkg::*;

  localparam string tb_name = "tb_ping_pong_buffer";

  localparam PERIOD = `PERIOD;
  localparam FREQ = `FREQ;
  localparam string OBJ = `OBJ;
  localparam string FILE_POSTFIX = `FILE_POSTFIX;

  //------------------------------------------------------------
  //- testbench variables
  //------------------------------------------------------------
  parameter ADDR_WIDTH = 32;
  parameter SRAM_DEPTH = 32;
  parameter SRAM_BANK_WIDTH = 32;
  parameter SRAM_BANK_NUM = 32;
  localparam int unsigned MEM_SIZE = (SRAM_BANK_WIDTH * SRAM_DEPTH * SRAM_BANK_NUM) / 8;

  int rpt_fd;
  int log_fd;
  string fsdb_file_path;
  string rpt_file_path;
  string log_file_path;
  string post_fix;
  string name;

  //------------------------------------------------------------
  //- signals
  //------------------------------------------------------------
  //* internal
  logic clk_i;
  logic resetn_i;
  mem_intf #(
      .DATA_WIDTH(32),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) offchip_master_port (
      .clk(clk_i)
  );

  mem_intf #(
      .DATA_WIDTH(32*16),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) master_port (
      .clk(clk_i)
  );

  //------------------------------------------------------------
  //- implementation
  //------------------------------------------------------------
  ping_pong_buffer #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .OFFCHIP_DATA_WIDTH(32),
      .ONCHIP_DATA_WIDTH(SRAM_BANK_WIDTH * (SRAM_BANK_NUM/2)),
      .SRAM_BANK_WIDTH(SRAM_BANK_WIDTH),
      .SRAM_BANK_NUM(SRAM_BANK_NUM),
      .SRAM_DEPTH(SRAM_DEPTH)
  ) u_ub (
      .clk_i      (clk_i),
      .resetn_i   (resetn_i),
      .offchip_master_port(offchip_master_port),
      .master_port(master_port)
  );

  //------------------------------------------------------------
  //- test
  //------------------------------------------------------------
  initial clk_i = 0;
  always #(PERIOD / 2) clk_i = ~clk_i;

  initial begin
    // time setting
    $timeformat(-9, 0, "ns", 0);

    // file name setting
    $sformat(name, "%s.%s", tb_name, FILE_POSTFIX);
    $sformat(fsdb_file_path, "./reports/%s.fsdb", name);
    $sformat(rpt_file_path, "./reports/%s.rpt", name);
    $sformat(log_file_path, "./logs/%s.log", name);

    // fsdb setting
    $fsdbDumpfile(fsdb_file_path);
    $fsdbDumpvars(0, "+all", "+parameter", "+functions");

    // open result files
    rpt_fd = $fopen(rpt_file_path, "w");
    log_fd = $fopen(log_file_path, "w");
  end

  generate
    localparam string OBJ_ = OBJ;
    initial begin
      if (OBJ_ == "power") begin
        sim_power();
      end else if (OBJ_ == "func") begin
        sim_func();
      end else begin
        $display("please set proper objective of the simulation");
      end

      // close resources
      $fsdbDumpoff();
      $fclose(rpt_fd);
      $fclose(log_fd);
      $finish;
    end
  endgenerate

  typedef class Driver;

  Driver drv;

  class Driver;
    task offchip_write();
      begin
        for(int i=0; i<MEM_SIZE/4; i++) begin
          offchip_master_port.addr <= i * 4;
          offchip_master_port.data <= i;
          offchip_master_port.req  <= 1'b1;
          offchip_master_port.wen  <= '1;
          offchip_master_port.be   <= '1;

          do begin
            @(posedge clk_i);
          end while (!offchip_master_port.gnt);
        end
        offchip_master_port.req <= 1'b0;
      end
    endtask

    task offchip_read();
      begin
        for(int i=0; i<MEM_SIZE/4; i++) begin
          offchip_master_port.addr <= i * 4;
          offchip_master_port.data <= 0;
          offchip_master_port.req  <= 1'b1;
          offchip_master_port.wen  <= '0;
          offchip_master_port.be   <= '1;

          do begin
            @(posedge clk_i);
          end while (!offchip_master_port.gnt);
        end
      end
      offchip_master_port.req <= 1'b0;
    endtask

    task read_rsp();
      while(1) begin
        @(posedge clk_i);
        offchip_master_port.r_ready <= $urandom();
        master_port.r_ready <= $urandom();
      end
    endtask

    task ipp_write();
      logic [16*32-1:0] data;
      begin
        for(int i=0; i<MEM_SIZE/(64); i++) begin
          for(int j=0; j<16; j++) begin
            data[j*32 +: 32] = 16*i + j; // simulate memory content
          end
          master_port.addr <= i * 64;
          master_port.data <= data;
          master_port.req  <= 1'b1;
          master_port.wen  <= '1;
          master_port.be   <= '1;

          do begin
            @(posedge clk_i);
          end while (!master_port.gnt);
        end
        master_port.req <= 1'b0;
      end
    endtask

    task ipp_read();
      begin
        for(int i=0; i<MEM_SIZE/(64); i++) begin
          master_port.addr <= i * 64;
          master_port.data <= 0;
          master_port.req  <= 1'b1;
          master_port.wen  <= '0;
          master_port.be   <= '1;

          do begin
            @(posedge clk_i);
          end while (!master_port.gnt);
        end
      end
      master_port.req <= 1'b0;
    endtask
  endclass

  //* monitor memory transction
  logic [31:0] offchip_read_data[$];
  logic [16*32-1:0] ipp_read_data[$];

  initial begin
    while(1) begin
      @(posedge clk_i);
      if (offchip_master_port.r_valid & offchip_master_port.r_ready) begin
        offchip_read_data.push_back(offchip_master_port.r_data);
      end
    end
  end

  initial begin
    while(1) begin
      @(posedge clk_i);
      if (master_port.r_valid & master_port.r_ready) begin
        ipp_read_data.push_back(master_port.r_data);
      end
    end
  end

  task sim_func();
    logic err_flag=0;
    logic [16*32-1:0] ipp_read_data_temp;

    drv = new();

    fork
      drv.read_rsp();
    join_none

    resetn_i <= 1'b0;
    master_port.req <= 1'b0;
    master_port.wen <= 1'b0;
    master_port.be <= 1'b0;
    master_port.addr <= '0;
    master_port.data <= '0;

    offchip_master_port.req <= 1'b0;
    offchip_master_port.wen <= 1'b0;
    offchip_master_port.be <= 1'b0;
    offchip_master_port.addr <= '0;
    offchip_master_port.data <= '0;
    @(posedge clk_i);
    resetn_i <= 1'b1;

    // write
    fork
      drv.offchip_write();
      drv.ipp_write();
    join

    // read
    @(posedge clk_i);
    fork
      drv.offchip_read();
      drv.ipp_read();
    join

    repeat(100) @(posedge clk_i);

    // check read data
    $display("----------------------------------- CHECK RESULTS -----------------------------------------");
    if(offchip_read_data.size() != MEM_SIZE/4) begin
      $display("Error: offchip read data size mismatch: expected %0d, got %0d", MEM_SIZE/4, offchip_read_data.size());
      err_flag = 1;
    end
    foreach (offchip_read_data[i]) begin
      if(offchip_read_data[i] != i) begin
        $display("Error: offchip read data mismatch at index %0d: expected %0d, got %0d", i, i, offchip_read_data[i]);
        err_flag = 1;
      end
    end
    if(err_flag) begin
      $display("Test failed: offchip read data mismatch");
    end else begin
      $display("Test passed: all offchip read data match expected values");
    end

    err_flag = 0;
    if(ipp_read_data.size() != MEM_SIZE/(64)) begin
      $display("Error: ipp read data size mismatch: expected %0d, got %0d", MEM_SIZE/(64), ipp_read_data.size());
      err_flag = 1;
    end
    foreach (ipp_read_data[i]) begin
      for(int j=0; j<16; j++) begin
        ipp_read_data_temp[j*32 +: 32] = 16*i + j;
      end
      if(ipp_read_data[i] != ipp_read_data_temp) begin
        $display("Error: ipp read data mismatch at index %0d: expected %0h, got %0h", i, ipp_read_data_temp, ipp_read_data[i]);
        err_flag = 1;
      end
    end
    if(err_flag) begin
      $display("Test failed: ipp read data mismatch");
    end else begin
      $display("Test passed: all ipp read data match expected values");
    end
    $display("----------------------------------- END CHECK RESULTS -----------------------------------------");

    $finish;
  endtask

  task sim_power();
  endtask

endmodule
