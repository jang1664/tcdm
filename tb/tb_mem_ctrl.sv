`define WAIT_POSEDGE(clk_i) @(posedge clk_i); #1; 

module tb_mem_ctrl;
  localparam string name = "tb_mem_ctrl";

  parameter DATA_WIDTH = 32;
  parameter ADDR_WIDTH = 32;
  parameter MEM_GROUP_NUM = 4;
  parameter MEM_GROUP_DATA_WIDTH = 32;
  localparam MEM_GROUP_BYTE_WIDTH = MEM_GROUP_DATA_WIDTH / 8;
  localparam TOTAL_BYTE_WIDTH = (MEM_GROUP_DATA_WIDTH * MEM_GROUP_NUM) / 8;
  localparam DATA_BYTE_WIDTH = DATA_WIDTH / 8;

  parameter PERIOD = 10;

  logic clk_i;
  logic rst_ni;
  mem_intf #(
      .DATA_WIDTH(DATA_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) slv_port (.clk(clk_i));

  mem_intf #(
      .DATA_WIDTH(MEM_GROUP_DATA_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) mas_port[MEM_GROUP_NUM] (.clk(clk_i));

  logic [  DATA_WIDTH-1:0] temp_data;
  logic [DATA_WIDTH/8-1:0] temp_be;
  logic [  ADDR_WIDTH-1:0] temp_addr;

  generate
    for (genvar i = 0; i < MEM_GROUP_NUM; i++) begin
      mem_group #(
          .BANK_WIDTH (MEM_GROUP_DATA_WIDTH),
          .BANK_DEPTH (2**10),
          .BANK_NUM   (8)
      ) u_mem_group (
          .clk_i      (clk_i),
          .resetn_i   (rst_ni),
          .port(mas_port[i])
      );
    end
  endgenerate

  mem_ctrl #(
      .DATA_WIDTH          (DATA_WIDTH),
      .ADDR_WIDTH          (ADDR_WIDTH),
      .MEM_GROUP_NUM       (MEM_GROUP_NUM),
      .MEM_GROUP_DATA_WIDTH(MEM_GROUP_DATA_WIDTH)
  ) u_mem_ctrl (
      .clk_i   (clk_i),
      .rst_ni  (rst_ni),
      .slv_port(slv_port),
      .mas_port(mas_port)
  );


  initial clk_i = 1'b0;
  always #(PERIOD/2) clk_i = ~clk_i;

  task write(int addr, logic [DATA_WIDTH-1:0] data, logic [DATA_WIDTH/8-1:0] be);
    begin
      @(posedge clk_i);
      slv_port.req  <= 1;
      slv_port.addr <= addr;
      slv_port.data <= data;
      slv_port.be   <= be;
      slv_port.wen  <= 1;
      while(1)begin
        @(posedge clk_i);
        if(slv_port.req && slv_port.gnt) begin
          break;
        end
      end
      slv_port.req <= 0;
    end
  endtask

  task read(input int addr, ref logic [DATA_WIDTH-1:0] data, input logic [DATA_WIDTH/8-1:0] be);
    begin
      @(posedge clk_i);
      slv_port.req  <= 1;
      slv_port.addr <= addr;
      slv_port.data <= data;
      slv_port.be   <= be;
      slv_port.wen  <= 0;
      while(1) begin
        @(posedge clk_i);
        if(slv_port.req && slv_port.gnt) begin
          break;
        end
      end
      slv_port.req <= 0;
      #(PERIOD+1); data = slv_port.r_data;
    end
  endtask

  string fsdb_file_path;
  initial begin
    $sformat(fsdb_file_path, "./reports/%s.fsdb", name);
    $fsdbDumpfile(fsdb_file_path);
    $fsdbDumpvars(0, "+all", "+parameter", "+functions");
  end

  initial begin
    rst_ni = 1'b0;
    slv_port.req = '0;
    slv_port.r_ready = 1;
    `WAIT_POSEDGE(clk_i);
    rst_ni = 1'b1;
    for (int i = 0; i < 128; i++) begin
      temp_addr = DATA_BYTE_WIDTH * i;
      temp_data = i;
      for (int j = 0; j < DATA_BYTE_WIDTH; j++) begin
        temp_be[j] = 1;
      end
      write(temp_addr, temp_data, temp_be);
      temp_data = '0;
      read(temp_addr, temp_data, temp_be);
      $display("addr: %d, data: %d", temp_addr, temp_data);
    end
    repeat(10) `WAIT_POSEDGE(clk_i);
    $fsdbDumpoff();
    $finish;
  end

endmodule
