`timescale 1ns / 1ps

`define WAIT_POSEDGE(clk) @(posedge clk_i); #(1);

module tb_wb;
  import npu_global_params::*;

  localparam string tb_name = "tb_weight_buffer";

  localparam PERIOD = `PERIOD;
  localparam FREQ = `FREQ;
  localparam string OBJ = `OBJ;
  localparam string FILE_POSTFIX = `FILE_POSTFIX;

`ifdef PRE
  `define PRE_OR_POST
`elsif POST
  `define PRE_OR_POST
`endif

  //------------------------------------------------------------
  //- testbench variables
  //------------------------------------------------------------
  parameter DATA_WIDTH = WB_DATA_WIDTH;
  parameter MEM_SIZE = WB_MEM_SIZE;
  parameter ADDR_WIDTH = WB_ADDR_WIDTH;
  parameter MUX_NUM = WB_MUX_NUM;
  parameter NB_PORT = WB_NB_PORT;

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
  // .ADDR_WIDTH(ADDR_WIDTH)
  mem_intf #(
      .DATA_WIDTH(DATA_WIDTH)
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
`ifdef PRE_OR_POST
  wb_svsim #(
      .DATA_WIDTH(DATA_WIDTH),
      .MEM_SIZE(MEM_SIZE),
      .ADDR_WIDTH(ADDR_WIDTH),
      .MUX_NUM(MUX_NUM),
      .NB_PORT(NB_PORT)
  ) u_wb(
      .clk_i(clk_i),
      .resetn_i(resetn_i),
      .master_port(master_port)
  );
`else
  wb #(
      .DATA_WIDTH(DATA_WIDTH),
      .MEM_SIZE(MEM_SIZE),
      .ADDR_WIDTH(ADDR_WIDTH),
      .MUX_NUM(MUX_NUM),
      .NB_PORT(NB_PORT)
  ) u_wb(
      .clk_i(clk_i),
      .resetn_i(resetn_i),
      .master_port(master_port)
  );
`endif

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

`ifdef sdf_gate
    $sdf_annotate("/home1/mpw7201/FICIM/hw/memory_system/wb/sta.rev3/PRE/wb.sdf_PT", u_wb.wb);
    //`define DELAY 0.001
    `define DELAY 0.1
`elsif sdf_post_wst
    $sdf_annotate("/home1/mpw7201/FICIM/hw/memory_system/wb/sta.rev3/POST/MAX/results/wb_max.sdf_PT", u_wb.wb);
    `define DELAY 0.1
`elsif sdf_post_bst
    $sdf_annotate("/home1/mpw7201/FICIM/hw/memory_system/wb/sta.rev3/POST/MIN/results/wb_min.sdf_PT", u_wb.wb);
    `define DELAY 0.01
`else
    `define DELAY 0.001
`endif
  end

  generate
    localparam string OBJ_ = OBJ;
    initial begin
      if (OBJ_ == "power") begin
        sim_power();
      end else if (OBJ_ == "func") begin
        sim_func();
      end else begin
        sim_func();
        // $display("please set proper objective of the simulation");
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
        #(`DELAY);
        master_port_addr[idx] <= addr;
        master_port_data[idx] <= data;
        master_port_req[idx]  <= 1'b1;
        master_port_wen[idx]  <= 1'b1;
        master_port_be[idx]   <= '1;

        while(1) begin
          @(negedge clk_i);
          #(0.4*PERIOD);
          if(master_port_gnt[idx] & master_port_req[idx]) begin
            break;
          end
        end

        @(posedge clk_i); 
        #(`DELAY)
        master_port_addr[idx] <= '0;
        master_port_data[idx] <= '0;
        master_port_req[idx]  <= 1'b0;
        master_port_wen[idx]  <= 1'b0;
        master_port_be[idx]   <= '0;
      end
    endtask

    task read(int idx, bit [ADDR_WIDTH-1:0] addr, ref bit [DATA_WIDTH-1:0] data);
      begin
        @(posedge clk_i);
        #(`DELAY);
        master_port_addr[idx] <= addr;
        master_port_req[idx]  <= 1'b1;
        master_port_wen[idx]  <= 1'b0;
        master_port_wen[idx]  <= 1'b0;
        master_port_be[idx]   <= '0;

        while(1) begin
          @(negedge clk_i);
          #(0.4*PERIOD);
          if(master_port_gnt[idx] & master_port_req[idx]) begin
            break;
          end
        end

        fork
          begin
            @(negedge clk_i);
            wait (master_port_r_valid[idx] == 1);
            @(posedge clk_i);
            #(`DELAY);
            data = master_port_r_data[idx];
          end
        join_none

        @(posedge clk_i);
        #(`DELAY);
        master_port_addr[idx] <= '0;
        master_port_req[idx]  <= 1'b0;
        master_port_wen[idx]  <= 1'b0;
        master_port_wen[idx]  <= 1'b0;
        master_port_be[idx]   <= '0;
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
        int addr;
        while (1) begin
          @(negedge clk_i);
          if (master_port[i].gnt) begin
            if (master_port[i].wen) begin
              $fdisplay(log_fd, "[%8t] %8s, data:%4d, addr:%4d, port:%1d", $time, "write",
                        master_port[i].data, master_port[i].addr, i);
            end else begin
              fork
                begin
                  addr = master_port[i].addr;
                  @(posedge clk_i);
                  #(0.8*PERIOD);
                  $fdisplay(log_fd, "[%8t] %8s, data:%4d, addr:%4d, port:%1d", $time, "read",
                            master_port[i].r_data, addr, i);
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

    drv = new();
    gen = new();
    mon = new();
    sc  = new();

    resetn_i <= 1'b0;
    master_port_addr <= '0;
    master_port_data <= '0;
    master_port_req <= '0;
    master_port_wen <= '0;
    master_port_be <= '0;

    repeat (4) begin
      @(posedge clk_i);
    end
    #(`DELAY);
    resetn_i <= 1'b1;

    // drv.write(.idx(0), .addr(DATA_WIDTH/8 * 0), .data(1));
    // drv.write(.idx(1), .addr(DATA_WIDTH/8 * 1), .data(2));
    // drv.write(.idx(0), .addr(DATA_WIDTH/8 * 2), .data(4));
    // drv.write(.idx(1), .addr(DATA_WIDTH/8 * 3), .data(5));

    // drv.read(.idx(0), .addr(DATA_WIDTH/8 * 0), .data(read_data[0]));
    // drv.read(.idx(1), .addr(DATA_WIDTH/8 * 1), .data(read_data[1]));
    // drv.read(.idx(0), .addr(DATA_WIDTH/8 * 2), .data(read_data[0]));
    // drv.read(.idx(1), .addr(DATA_WIDTH/8 * 3), .data(read_data[1]));

    fork
      drv.write(.idx(0), .addr(UNIT_STRIDE * 0), .data(1));
      drv.write(.idx(1), .addr(UNIT_STRIDE * 1), .data(2));
      drv.write(.idx(2), .addr(UNIT_STRIDE * 2), .data(3));
      // drv.write(.idx(3), .addr(UNIT_STRIDE * 3), .data(3));
    join

    fork
      drv.write(.idx(0), .addr(UNIT_STRIDE * 3), .data(4));
      drv.write(.idx(1), .addr(UNIT_STRIDE * 4), .data(5));
      drv.write(.idx(2), .addr(UNIT_STRIDE * 5), .data(6));
      //drv.write(.idx(3), .addr(UNIT_STRIDE * 7), .data(7));
    join

    fork
      drv.read(.idx(0), .addr(UNIT_STRIDE * 0), .data(read_data[0]));
      drv.read(.idx(1), .addr(UNIT_STRIDE * 1), .data(read_data[1]));
      drv.read(.idx(2), .addr(UNIT_STRIDE * 2), .data(read_data[2]));
      //drv.read(.idx(3), .addr(UNIT_STRIDE * 3), .data(read_data[3]));
    join

    fork
      drv.read(.idx(0), .addr(UNIT_STRIDE * 3), .data(read_data[0]));
      drv.read(.idx(1), .addr(UNIT_STRIDE * 4), .data(read_data[1]));
      drv.read(.idx(2), .addr(UNIT_STRIDE * 5), .data(read_data[2]));
      //drv.read(.idx(3), .addr(UNIT_STRIDE * 7), .data(read_data[3]));
    join

    #(10 * PERIOD);
    //u_mem_multiport_model.display_mem(log_fd);
    //u_mem_multiport_model.display_mem();
    //u_mem_multiport_model.track_trans();

    $finish;
  endtask

  task sim_power();
  endtask

endmodule
