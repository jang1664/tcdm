`define WAIT_POSEDGE(clk_i) @(posedge clk_i); #1; 

module tb_mem_ctrl;
  localparam string name = "tb_mem_interconnect";

  parameter int SLV_NUM = 2;
  parameter int MAS_NUM = 4;
  parameter int SLV_DATA_WIDTH[SLV_NUM] = '{16,64};
  parameter int MAS_DATA_WIDTH = 32;
  parameter int ADDR_WIDTH = 32;

  localparam MEM_GROUP_BYTE_WIDTH = MAS_DATA_WIDTH / 8;
  localparam TOTAL_BYTE_WIDTH = (MAS_DATA_WIDTH * MAS_NUM) / 8;

  typedef int getDataByteWidth_t[SLV_NUM];
  function getDataByteWidth_t getDataByteWidth;
    int data_byte_width[SLV_NUM];
    for (int i = 0; i < SLV_NUM; i++) begin
      data_byte_width[i] = SLV_DATA_WIDTH[i] / 8;
    end
    return data_byte_width;
  endfunction

  function int getMaxDataWidth;
    int max_data_width = 0;
    for (int i = 0; i < SLV_NUM; i++) begin
      if (SLV_DATA_WIDTH[i] > max_data_width) begin
        max_data_width = SLV_DATA_WIDTH[i];
      end
    end
    return max_data_width;
  endfunction

  localparam SLV_MAX_DATA_WIDTH = getMaxDataWidth();
  localparam getDataByteWidth_t DATA_BYTE_WIDTH = getDataByteWidth();

  parameter PERIOD = 10;

  logic clk_i;
  logic rst_ni;
  mem_intf #(
      .DATA_WIDTH(SLV_MAX_DATA_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) slv_port[SLV_NUM] (.clk(clk_i));
  mem_intf #(
      .DATA_WIDTH(MAS_DATA_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) mas_port[MAS_NUM] (.clk(clk_i));

  generate
    for (genvar i = 0; i < MAS_NUM; i++) begin
      mem_group #(
          .BANK_WIDTH (MAS_DATA_WIDTH),
          .BANK_DEPTH (2**10),
          .BANK_NUM   (8)
      ) u_mem_group (
          .clk_i      (clk_i),
          .resetn_i   (rst_ni),
          .port(mas_port[i])
      );
    end
  endgenerate

  mem_interconnect #(
      .SLV_NUM(SLV_NUM),
      .MAS_NUM(MAS_NUM),
      .SLV_DATA_WIDTH(SLV_DATA_WIDTH),
      .MAS_DATA_WIDTH(MAS_DATA_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) u_mem_interconnect(
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .slv_port(slv_port),
      .mas_port(mas_port)
  );

  `TCDM_EXPLODE_ARRAY_DECLARE_PARAM(slv_port, SLV_NUM, SLV_MAX_DATA_WIDTH, ADDR_WIDTH);
  `TCDM_EXPLODE_ARRAY_DECLARE_PARAM(mas_port, MAS_NUM, MAS_DATA_WIDTH, ADDR_WIDTH);
  generate
    for(genvar i=0; i<SLV_NUM; i++) begin
      `TCDM_SLAVE_EXPLODE(slv_port[i], slv_port, [i]);
    end
    // for(genvar i=0; i<MAS_NUM; i++) begin
    //   `TCDM_SLVAE_EXPLODE(mas_port[i], mas_port, [i]);
    // end
  endgenerate


  initial clk_i = 1'b0;
  always #(PERIOD/2) clk_i = ~clk_i;

  task automatic write(int idx, int addr, logic [SLV_MAX_DATA_WIDTH-1:0] data, logic [SLV_MAX_DATA_WIDTH/8-1:0] be);
    begin
      @(posedge clk_i);
      slv_port_req[idx]  <= 1;
      slv_port_addr[idx] <= addr;
      slv_port_data[idx] <= data;
      slv_port_be[idx]   <= be;
      slv_port_wen[idx]  <= 1;
      while(1)begin
        @(posedge clk_i);
        if(slv_port_req[idx] && slv_port_gnt[idx]) begin
          break;
        end
      end
      slv_port_req[idx] <= 0;
    end
  endtask

  task automatic read(int idx, input int addr, ref logic [SLV_MAX_DATA_WIDTH-1:0] data, input logic [SLV_MAX_DATA_WIDTH/8-1:0] be);
    begin
      @(posedge clk_i);
      slv_port_req[idx]  <= 1;
      slv_port_addr[idx] <= addr;
      slv_port_data[idx] <= data;
      slv_port_be[idx]   <= be;
      slv_port_wen[idx]  <= 0;
      while(1) begin
        @(posedge clk_i);
        if(slv_port_req[idx] && slv_port_gnt[idx]) begin
          break;
        end
      end
      slv_port_req[idx] <= 0;
      while(1) begin
        @(posedge clk_i);
        if(slv_port_r_valid[idx] && slv_port_r_ready[idx]) begin
          break;
        end
      end
      data = slv_port_r_data[idx];
      // #(PERIOD+1); data = slv_port_r_data[idx];
    end
  endtask

  string fsdb_file_path;
  initial begin
    $sformat(fsdb_file_path, "./reports/%s.fsdb", name);
    $fsdbDumpfile(fsdb_file_path);
    $fsdbDumpvars(0, "+all", "+parameter", "+functions");
  end

  int fd[SLV_NUM];
  initial begin
    rst_ni = 1'b0;
    slv_port_req = '0;
    slv_port_r_ready = '1;
    `WAIT_POSEDGE(clk_i);
    rst_ni = 1'b1;
    fd[0] = $fopen("slv_0.log", "w");
    fd[1] = $fopen("slv_1.log", "w");
    fork
      begin
        logic [  SLV_MAX_DATA_WIDTH-1:0] temp_data;
        logic [SLV_MAX_DATA_WIDTH/8-1:0] temp_be;
        logic [  ADDR_WIDTH-1:0] temp_addr;

        for (int i = 0; i < 128; i++) begin
          temp_addr = TOTAL_BYTE_WIDTH * i;
          temp_data = (2**SLV_DATA_WIDTH[0]-1) - i;
          for (int j = 0; j < DATA_BYTE_WIDTH[0]; j++) begin
            temp_be[j] = 1;
          end
          write(0, temp_addr, temp_data, temp_be);
          temp_data = '0;
          read(0, temp_addr, temp_data, temp_be);
          $fdisplay(fd[0], "[%8t] idx: %d, addr: %d, data: %d", $time, 0, temp_addr, temp_data[SLV_DATA_WIDTH[0]-1:0]);
          // repeat($urandom_range(0,4)) @(posedge clk_i);
        end
      end

      begin
        logic [  SLV_MAX_DATA_WIDTH-1:0] temp_data;
        logic [SLV_MAX_DATA_WIDTH/8-1:0] temp_be;
        logic [  ADDR_WIDTH-1:0] temp_addr;

        for (int i = 0; i < 128; i++) begin
          temp_addr = TOTAL_BYTE_WIDTH * i + DATA_BYTE_WIDTH[0];
          temp_data = (2**SLV_DATA_WIDTH[1]-1) - i;
          for (int j = 0; j < DATA_BYTE_WIDTH[1]; j++) begin
            temp_be[j] = 1;
          end
          write(1, temp_addr, temp_data, temp_be);
          temp_data = '0;
          read(1, temp_addr, temp_data, temp_be);
          $fdisplay(fd[1], "[%8t] idx: %d, addr: %d, data: %d", $time, 1, temp_addr, temp_data[SLV_DATA_WIDTH[1]-1:0]);
          // repeat($urandom_range(0,4)) @(posedge clk_i);
        end
      end
    join
    repeat(10) `WAIT_POSEDGE(clk_i);
    $fsdbDumpoff();
    $finish;
  end

endmodule
