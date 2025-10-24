`timescale 1ns / 1ps

`define WAIT_POSEDGE(clk) @(posedge clk_i); #(1);

module tb_psum_buf_system;
  import npu_global_params::*;
  import npu_pkg::*;

  localparam string tb_name = "tb_psum_buf_system";

  localparam PERIOD = `PERIOD;
  localparam FREQ = `FREQ;
  localparam string OBJ = `OBJ;
  localparam string FILE_POSTFIX = `FILE_POSTFIX;

  //------------------------------------------------------------
  //- testbench variables
  //------------------------------------------------------------
  parameter ADDR_WIDTH = 32;
  parameter SRAM_BANK_WIDTH = _PSUM_WIDTH;
  parameter SRAM_DEPTH = _PB_DEPTH;
  parameter SRAM_BANK_NUM = 2*_LANE_NUM;

  localparam int unsigned MEM_SIZE = (SRAM_BANK_WIDTH * SRAM_DEPTH * SRAM_BANK_NUM) / 8;
  localparam MEM_SIZE_PER_LANE = MEM_SIZE / _LANE_NUM;
  localparam int unsigned SRAM_BANK_WIDTH_BYTES = SRAM_BANK_WIDTH / 8;
  localparam NUM_MASTER = 2*_LANE_NUM;

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
      .DATA_WIDTH(SRAM_BANK_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) master_ports[NUM_MASTER] (
      .clk(clk_i)
  );

  virtual mem_intf #(
      .DATA_WIDTH(SRAM_BANK_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) master_ports_vif[NUM_MASTER];

  //------------------------------------------------------------
  //- implementation
  //------------------------------------------------------------
  psum_buf_system u_psum_buf_system (
      .clk_i(clk_i),
      .resetn_i(resetn_i),
      .lane_master(master_ports)
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

  generate
    for(genvar i = 0; i < NUM_MASTER; i++) begin : gen_lane
      initial master_ports_vif[i] = master_ports[i];
    end
  endgenerate

  class Driver;
    task write();
      bit [NUM_MASTER-1:0] write_done;
      begin
        for(int lane_=0; lane_<NUM_MASTER; lane_++) begin
          int lane = lane_;
          fork : lane_fork
            begin
              // $display("Lane %0d: Writing to on-chip memory", lane);
              for(int i=0; i<MEM_SIZE_PER_LANE/SRAM_BANK_WIDTH_BYTES; i++) begin
                master_ports_vif[lane].addr <= i * SRAM_BANK_WIDTH_BYTES;
                master_ports_vif[lane].data <= i;
                master_ports_vif[lane].req  <= 1'b1;
                master_ports_vif[lane].wen  <= '1;
                master_ports_vif[lane].be   <= '1;

                do begin
                  @(posedge clk_i);
                end while (!master_ports_vif[lane].gnt);
              end
              master_ports_vif[lane].req <= 1'b0;
              write_done[lane] = 1'b1;
            end
          join_none
        end

        do begin
          @(posedge clk_i);
        end while (write_done != {NUM_MASTER{1'b1}});
      end
    endtask

    task read();
      bit [NUM_MASTER-1:0] read_done;
      begin
        for(int lane_=0; lane_<NUM_MASTER; lane_++) begin
          int lane = lane_;
          fork : lane_fork
            begin
              // $display("Lane %0d: reading to on-chip memory", lane);
              for(int i=0; i<MEM_SIZE_PER_LANE/SRAM_BANK_WIDTH_BYTES; i++) begin
                master_ports_vif[lane].addr <= i * SRAM_BANK_WIDTH_BYTES;
                master_ports_vif[lane].data <= '0;
                master_ports_vif[lane].req  <= 1'b1;
                master_ports_vif[lane].wen  <= '0;
                master_ports_vif[lane].be   <= '1;

                do begin
                  @(posedge clk_i);
                end while (!master_ports_vif[lane].gnt);
              end
              master_ports_vif[lane].req <= 1'b0;
              read_done[lane] = 1'b1;
            end
          join_none
        end

        do begin
          @(posedge clk_i);
        end while (read_done != {NUM_MASTER{1'b1}});
      end
    endtask

    task read_rsp();
      while(1) begin
        @(posedge clk_i);
        for(int i=0; i<NUM_MASTER; i++) master_ports_vif[i].r_ready <= $urandom();
      end
    endtask
  endclass

  //* monitor memory transction
  logic [SRAM_BANK_WIDTH-1:0] onchip_read_data[NUM_MASTER][$];

  initial begin
    while(1) begin
      @(posedge clk_i);
      for(int i=0; i<NUM_MASTER; i++) begin
        if (master_ports_vif[i].r_valid & master_ports_vif[i].r_ready) begin
          onchip_read_data[i].push_back(master_ports_vif[i].r_data);
        end
      end
    end
  end

  task sim_func();
    logic err_flag=0;
    logic [SRAM_BANK_WIDTH-1:0] onchip_read_data_temp;
    #0;

    drv = new();

    fork
      drv.read_rsp();
    join_none

    resetn_i <= 1'b0;
    for(int i=0; i<NUM_MASTER; i++) begin
      master_ports_vif[i].req <= 1'b0;
      master_ports_vif[i].wen <= 1'b0;
      master_ports_vif[i].be <= 1'b0;
      master_ports_vif[i].addr <= '0;
      master_ports_vif[i].data <= '0;
    end

    @(posedge clk_i);
    resetn_i <= 1'b1;

    // write
    fork
      drv.write();
    join

    // read
    @(posedge clk_i);
    fork
      drv.read();
    join

    repeat(100) @(posedge clk_i);

    // check read data
    $display("----------------------------------- CHECK RESULTS -----------------------------------------");
    err_flag = 0;

    // Check if the size of onchip_read_data matches expected size
    $display("Checking onchip read data size for each lane...");
    for (int i = 0; i < NUM_MASTER; i++) begin
      if (onchip_read_data[i].size() != MEM_SIZE_PER_LANE/SRAM_BANK_WIDTH_BYTES) begin
        $display("Error: onchip read data size mismatch at lane %0d: expected %0d, got %0d", 
             i, MEM_SIZE_PER_LANE/SRAM_BANK_WIDTH_BYTES, onchip_read_data[i].size());
        err_flag = 1;
      end else begin
        $display("Lane %0d: onchip read data size is correct: %0d", i, onchip_read_data[i].size());
      end
    end

    foreach (onchip_read_data[i, j]) begin
      onchip_read_data_temp = j;
      if (onchip_read_data[i][j] != onchip_read_data_temp) begin
      $display("Error: onchip read data mismatch at lane %0d, index %0d: expected %0h, got %0h", i, j, onchip_read_data_temp, onchip_read_data[i][j]);
      err_flag = 1;
      end
    end
    if (err_flag) begin
      $display("Test failed: onchip read data mismatch");
    end else begin
      $display("Test passed: all onchip read data match expected values");
    end

    $display("----------------------------------- END CHECK RESULTS -----------------------------------------");

    $finish;
  endtask

  task sim_power();
  endtask

endmodule
