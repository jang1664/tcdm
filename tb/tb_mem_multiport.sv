`timescale 1ns / 1ps

`define WAIT_POSEDGE(clk) @(posedge clk_i); #(1);

module tb_mem_multiport;
//   import npu_global_params::*;
//   import npu_pkg::*;
//   import ipp_pkg::*;
//   import psp_pkg::*;
//   import cu_pkg::*;

  localparam string tb_name = "tb_mem_multiport";

  localparam PERIOD = `PERIOD;
  localparam FREQ = `FREQ;
  localparam string OBJ = `OBJ;
  localparam string FILE_POSTFIX = `FILE_POSTFIX;

  //------------------------------------------------------------
  //- testbench variables
  //------------------------------------------------------------
  parameter DATA_WIDTH = 256;
  parameter ADDR_WIDTH = 32;
  parameter SRAM_DEPTH = 32;
  parameter NB_PORT = 3;
  parameter SRAM_BANK_WIDTH = 32;
  parameter SRAM_BANK_NUM = 8;
  localparam int unsigned MAX_BURST_LEN = 16;
  localparam int unsigned UNIT_STRIDE = DATA_WIDTH / 8;
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
      .DATA_WIDTH(DATA_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) master_port[NB_PORT] (
      .clk(clk_i)
  );

  `TCDM_EXPLODE_ARRAY_DECLARE_PARAM(master_port, NB_PORT, DATA_WIDTH, ADDR_WIDTH)
  generate
    for (genvar i = 0; i < NB_PORT; i++) begin : explode
      `TCDM_SLAVE_EXPLODE(master_port[i], master_port, [i])
    end
  endgenerate

  //------------------------------------------------------------
  //- implementation
  //------------------------------------------------------------
  mem_multiport_reg #(
      .DATA_WIDTH(DATA_WIDTH),
      .MEM_SIZE(2048),
      .ADDR_WIDTH(ADDR_WIDTH),
      .MUX_NUM(1),
      .NB_PORT(NB_PORT),
      .SRAM_BANK_WIDTH(SRAM_BANK_WIDTH),
      .SRAM_DEPTH(SRAM_DEPTH)
  ) (
      .clk_i(clk_i),
      .resetn_i(resetn_i),
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

  typedef class Generator;
  typedef class Driver;
  typedef class Monitor;
  typedef class ScoreBoard;

  Generator gen;
  Driver drv;
  Monitor mon;
  ScoreBoard sc;

  class Generator;
  endclass

  class Driver;
    task write(int idx, bit [ADDR_WIDTH-1:0] addr, bit [DATA_WIDTH-1:0] data);
      begin
        @(posedge clk_i); 
        master_port_addr[idx] <= addr;
        master_port_data[idx] <= data;
        master_port_req[idx]  <= 1'b1;
        master_port_wen[idx]  <= 1'b1;
        // master_port_be[idx]   <= '1;
        master_port_be[idx]   <= {((DATA_WIDTH/(8*2))){2'b01}};

        wait (master_port_gnt[idx] == 1);
        // master_port_addr[idx] <= addr;
        // master_port_data[idx] <= data;
        // master_port_wen[idx]  <= 1'b1;
        // master_port_be[idx]   <= '1;
        @(posedge clk_i); 
        master_port_req[idx] <= '0;
      end
    endtask

    task read(int idx, bit [ADDR_WIDTH-1:0] addr, ref bit [DATA_WIDTH-1:0] data);
      begin
        @(posedge clk_i);
        master_port_addr[idx] <= addr;
        master_port_req[idx]  <= 1'b1;
        master_port_wen[idx]  <= 1'b0;

        wait (master_port_gnt[idx] == 1);
        // master_port_addr[idx] <= addr;
        // master_port_wen[idx]  <= 1'b0;

        fork
          begin
            wait (master_port_r_valid[idx] == 1);
            @(posedge clk_i);
            data = master_port_r_data[idx];
          end
        join_none
        @(posedge clk_i);
        master_port_req[idx] <= '0;
      end
    endtask

    // task write_burst(bit [ADDR_WIDTH-1:0] addr, bit [MAX_BURST_LEN-1:0][DATA_WIDTH-1:0] data,
    //                  int burst_len);
    //   begin
    //     for (int i = 0; i < burst_len; i++) begin
    //       @(posedge clk_i);
    //       master_port.addr <= addr + 4 * i;
    //       master_port.data <= data[i];
    //       master_port.req  <= 1'b1;
    //       master_port.wen  <= 1'b1;
    //       master_port.be   <= '1;

    //       wait (master_port.gnt == 1);
    //     end
    //     @(posedge clk_i);
    //     master_port.req <= '0;
    //   end
    // endtask

    // task read_burst(bit [ADDR_WIDTH-1:0] addr,
    //                 ref bit [MAX_BURST_LEN-1:0][DATA_WIDTH-1:0] data, int burst_len);
    //   begin
    //     for (int i = 0; i < burst_len; i++) begin
    //       @(posedge clk_i);
    //       master_port.addr <= addr + 4 * i;
    //       master_port.req  <= 1'b1;
    //       master_port.wen  <= 1'b0;

    //       wait (master_port.gnt == 1);
    //       fork
    //         begin
    //           int idx = i;
    //           wait (master_port.r_valid == 1);
    //           @(posedge clk_i);
    //           #0;
    //           data[idx] = master_port.r_data;
    //         end
    //       join_none
    //     end
    //     @(posedge clk_i);
    //     master_port.req <= '0;
    //   end
    // endtask
  endclass

  class Monitor;
  endclass

  //* monitor memory transction
  generate
    for (genvar i = 0; i < NB_PORT; i++) begin : tb_gen
      initial begin
        while (1) begin
          @(posedge clk_i);
          if (master_port[i].gnt) begin
            if (master_port[i].wen) begin
              $fdisplay(log_fd, "[%8t] %8s, data:%4d, addr:%4d, port:%1d", $time, "write",
                        master_port[i].data, master_port[i].addr, i);
            end else begin
              fork
                begin
                  @(posedge clk_i);
                  $fdisplay(log_fd, "[%8t] %8s, data:%4d, addr:%4d, port:%1d", $time, "read",
                            master_port[i].r_data, master_port[i].addr, i);
                end
              join_none
            end
          end
        end
      end
    end
  endgenerate

  class ScoreBoard;
  endclass

  typedef bit [DATA_WIDTH-1:0] data_t;

  task sim_func();
    byte random_byte;
    bit [DATA_WIDTH-1:0] read_data[NB_PORT-1:0];
    bit [DATA_WIDTH-1:0] write_data[NB_PORT-1:0];

    if(NB_PORT != 3) $fatal(0, "NB_PORT must be 3");

    drv = new();
    gen = new();
    mon = new();
    sc  = new();

    @(posedge clk_i);
    resetn_i <= 1'b0;
    master_port_addr <= '0;
    master_port_data <= '0;
    master_port_req <= '0;
    master_port_wen <= '0;
    master_port_be <= '0;
    @(posedge clk_i);
    resetn_i <= 1'b1;

    // drv.write(.idx(0), .addr(DATA_WIDTH/8 * 0), .data(0));
    // drv.write(.idx(1), .addr(DATA_WIDTH/8 * 1), .data(1));
    // drv.write(.idx(2), .addr(DATA_WIDTH/8 * 2), .data(2));
    // drv.write(.idx(0), .addr(DATA_WIDTH/8 * 4), .data(4));
    // drv.write(.idx(1), .addr(DATA_WIDTH/8 * 5), .data(5));
    // drv.write(.idx(2), .addr(DATA_WIDTH/8 * 6), .data(6));

    // drv.read(.idx(0), .addr(DATA_WIDTH/8 * 0), .data(read_data[0]));
    // drv.read(.idx(1), .addr(DATA_WIDTH/8 * 1), .data(read_data[1]));
    // drv.read(.idx(2), .addr(DATA_WIDTH/8 * 2), .data(read_data[2]));
    // drv.read(.idx(0), .addr(DATA_WIDTH/8 * 4), .data(read_data[0]));
    // drv.read(.idx(1), .addr(DATA_WIDTH/8 * 5), .data(read_data[1]));
    // drv.read(.idx(2), .addr(DATA_WIDTH/8 * 6), .data(read_data[2]));

`define WRITE_TRANS(idx_, depth) \
  begin \
    for(int i=0; i<DATA_WIDTH/8; i++) begin \
      write_data[idx_][i*8+:8] = (i+idx_+depth)%256; \
    end \
    drv.write(.idx(idx_), .addr(DATA_WIDTH/8 * depth), .data(write_data[idx_])); \
  end

`define READ_TRANS(idx_, depth) \
  begin \
    drv.read(.idx(idx_), .addr(DATA_WIDTH/8 * depth), .data(read_data[idx_])); \
  end

    fork
      `WRITE_TRANS(0, 0);
      `WRITE_TRANS(1, 1);
      `WRITE_TRANS(2, 2);
    join

    fork
      `WRITE_TRANS(0, 3);
      `WRITE_TRANS(1, 4);
      `WRITE_TRANS(2, 5);
    join

    fork
      `READ_TRANS(0, 0);
      `READ_TRANS(1, 1);
      `READ_TRANS(2, 2);
    join

    fork
      `READ_TRANS(0, 3);
      `READ_TRANS(1, 4);
      `READ_TRANS(2, 5);
    join

    #(10 * PERIOD);

    $finish;
  endtask

  task sim_power();
  endtask

endmodule
