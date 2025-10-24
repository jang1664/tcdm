`timescale 1ns / 1ps

`define WAIT_POSEDGE(clk) @(posedge clk_i); #(1);

module tb_outbuf_system;
  import npu_global_params::*;
  import npu_pkg::*;

  localparam string tb_name = "tb_outbuf_system";

  localparam PERIOD = `PERIOD;
  localparam FREQ = `FREQ;
  localparam string OBJ = `OBJ;
  localparam string FILE_POSTFIX = `FILE_POSTFIX;

  //------------------------------------------------------------
  //- testbench variables
  //------------------------------------------------------------
  parameter ADDR_WIDTH = 32;
  parameter SRAM_DEPTH = 32;
  parameter SRAM_BANK_WIDTH = _OB_DW;
  parameter SRAM_BANK_NUM = _LANE_NUM;
  localparam int unsigned MEM_SIZE = (SRAM_BANK_WIDTH * SRAM_DEPTH * SRAM_BANK_NUM) / 8;
  localparam int unsigned IO_BYTES = _IO_WIDTH / 8;
  localparam int unsigned SRAM_BANK_WIDTH_BYTES = SRAM_BANK_WIDTH / 8;

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
      .DATA_WIDTH(_IO_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) master_port[_LANE_NUM] (
      .clk(clk_i)
  );

  virtual mem_intf #(
      .DATA_WIDTH(_IO_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) master_port_vif[_LANE_NUM];


  //------------------------------------------------------------
  //- implementation
  //------------------------------------------------------------
  outbuf_system u_outbuf_system (
      .clk_i(clk_i),
      .resetn_i(resetn_i),
      .offchip_master(offchip_master_port),
      .lane_master(master_port)
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
    for(genvar i = 0; i < _LANE_NUM; i++) begin : gen_lane
      initial master_port_vif[i] = master_port[i];
    end
  endgenerate

  class Driver;
    task offchip_write();
      begin
        for(int i=0; i<MEM_SIZE/4; i++) begin
          offchip_master_port.addr <= i * 4;
          offchip_master_port.data <= {16'(2*i+1), 16'(2*i)};
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

    task onchip_write();
      bit [_LANE_NUM-1:0] write_done;
      begin
        for(int lane_=0; lane_<_LANE_NUM; lane_++) begin
          int lane = lane_;
          fork : lane_fork
            begin
              // $display("Lane %0d: Writing to on-chip memory", lane);
              for(int i=0; i<(SRAM_DEPTH * SRAM_BANK_WIDTH_BYTES)/IO_BYTES; i++) begin
                master_port_vif[lane].addr <= i * IO_BYTES;
                master_port_vif[lane].data <= (((_OB_DW/_IO_WIDTH) * _LANE_NUM)*(i/4) + (_OB_DW/_IO_WIDTH)*lane + i%(_OB_DW/_IO_WIDTH));
                master_port_vif[lane].req  <= 1'b1;
                master_port_vif[lane].wen  <= '1;
                master_port_vif[lane].be   <= '1;

                do begin
                  @(posedge clk_i);
                end while (!master_port_vif[lane].gnt);
              end
              master_port_vif[lane].req <= 1'b0;
              write_done[lane]=1;
              $display("[%0t] Lane %0d: Write to on-chip memory completed", $time, lane);
            end
          join_none
        end

        do begin
          @(posedge clk_i);
        end while (&write_done != 1);
        $display("[%0t] All lanes have completed writing to on-chip memory", $time);
      end
    endtask

    task onchip_read();
      bit [_LANE_NUM-1:0] read_done;
      begin
        for(int lane_=0; lane_<_LANE_NUM; lane_++) begin
          int lane = lane_;
          fork : lane_fork
            begin
              // $display("Lane %0d: reading to on-chip memory", lane);
              for(int i=0; i<(SRAM_DEPTH * SRAM_BANK_WIDTH_BYTES)/IO_BYTES; i++) begin
                master_port_vif[lane].addr <= i * IO_BYTES;
                master_port_vif[lane].data <= '0;
                master_port_vif[lane].req  <= 1'b1;
                master_port_vif[lane].wen  <= '0;
                master_port_vif[lane].be   <= '1;

                do begin
                  @(posedge clk_i);
                end while (!master_port_vif[lane].gnt);
              end
              master_port_vif[lane].req <= 1'b0;
              read_done[lane]=1;
            end
          join_none
        end

        do begin
          @(posedge clk_i);
        end while (&read_done != 1);
      end
    endtask

    task read_rsp();
      while(1) begin
        @(posedge clk_i);
        offchip_master_port.r_ready <= $urandom();
        for(int i=0; i<_LANE_NUM; i++) master_port_vif[i].r_ready <= $urandom();
      end
    endtask
  endclass

  //* monitor memory transction
  logic [31:0] offchip_read_data[$];
  logic [_OB_DW-1:0] onchip_read_data[_LANE_NUM][$];

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
      for(int i=0; i<_LANE_NUM; i++) begin
        if (master_port_vif[i].r_valid & master_port_vif[i].r_ready) begin
          onchip_read_data[i].push_back(master_port_vif[i].r_data);
        end
      end
    end
  end

  task sim_func();
    logic err_flag=0;
    logic [15:0] onchip_read_data_temp;
    #0;

    drv = new();

    fork
      drv.read_rsp();
    join_none

    resetn_i <= 1'b0;
    for(int i=0; i<_LANE_NUM; i++) begin
      master_port_vif[i].req <= 1'b0;
      master_port_vif[i].wen <= 1'b0;
      master_port_vif[i].be <= 1'b0;
      master_port_vif[i].addr <= '0;
      master_port_vif[i].data <= '0;
    end

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
      drv.onchip_write();
    join

    // read
    @(posedge clk_i);
    fork
      drv.offchip_read();
      drv.onchip_read();
    join

    repeat(100) @(posedge clk_i);

    // check read data
    $display("----------------------------------- CHECK RESULTS -----------------------------------------");
    if(offchip_read_data.size() != MEM_SIZE/4) begin
      $display("Error: offchip read data size mismatch: expected %0d, got %0d", MEM_SIZE/4, offchip_read_data.size());
      err_flag = 1;
    end
    foreach (offchip_read_data[i]) begin
      if(offchip_read_data[i] != {16'(2*i+1), 16'(2*i)}) begin
        $display("Error: offchip read data mismatch at index %0d: expected %0h, got %0h", i, {16'(2*i+1), 16'(2*i)}, offchip_read_data[i]);
        err_flag = 1;
      end
    end
    if(err_flag) begin
      $display("Test failed: offchip read data mismatch");
    end else begin
      $display("Test passed: all offchip read data match expected values");
    end

    err_flag = 0;
    //check onchip read data queue size

    foreach (onchip_read_data[i]) begin
      if (onchip_read_data[i].size() != (SRAM_DEPTH * SRAM_BANK_WIDTH_BYTES)/IO_BYTES) begin
      $display("Error: onchip read data size mismatch at lane %0d: expected %0d, got %0d", 
           i, (SRAM_DEPTH * SRAM_BANK_WIDTH_BYTES)/IO_BYTES, onchip_read_data[i].size());
      err_flag = 1;
      end
    end

    foreach (onchip_read_data[i, j]) begin
      onchip_read_data_temp = (((_OB_DW/_IO_WIDTH) * _LANE_NUM)*(j/4) + (_OB_DW/_IO_WIDTH)*i + j%(_OB_DW/_IO_WIDTH));
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
