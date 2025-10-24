module tcdm_pipe_req
  #(
    parameter  ADDR_WIDTH      = 11,
    parameter  DATA_WIDTH      = 32,
    localparam BE_WIDTH        = DATA_WIDTH/8,
    localparam SRAM_MEM_WIDTH  = ADDR_WIDTH
  )
  (
    input logic                                 clk_i,
    input logic                                 rstn_i,

    input logic                                 data_req_i,            // Data request
    input logic [ADDR_WIDTH-1:0]                data_add_i,            // Data request Address
    input logic                                 data_wen_i,            // Data request type : 0--> Store, 1 --> Load
    input logic [DATA_WIDTH-1:0]                data_wdata_i,          // Data request Write data
    input logic [BE_WIDTH-1:0]                  data_be_i,             // Data request Byte enable
    input logic                                 data_gnt_i,

    output logic                                data_gnt_o,            // Grant Incoming Request
    output logic                                data_req_SRAM_o,       // Data request
    output logic [SRAM_MEM_WIDTH-1:0]           data_add_SRAM_o,       // Data request Address
    output logic                                data_wen_SRAM_o,       // Data request type : 0--> Store, 1 --> Load
    output logic [DATA_WIDTH-1:0]               data_wdata_SRAM_o,     // Data request Write data
    output logic [BE_WIDTH-1:0]                 data_be_SRAM_o         // Data request Byte enable
  );

  // localparam  PIPE_WIDTH = ADDR_WIDTH + 1 + DATA_WIDTH + BE_WIDTH + 1;

  // enum logic [1:0] {IDLE_SCM, SRAM_1}       CS, NS;

  logic [1:0]                 data_req_q;
  logic [1:0][ADDR_WIDTH-1:0] data_add_q;
  logic [1:0]                 data_wen_q;
  logic [1:0][DATA_WIDTH-1:0] data_wdata_q;
  logic [1:0][BE_WIDTH-1:0]   data_be_q;


//`ifdef XILINX
//  (* max_fanout = 4 *) logic wr_pointer;
//  (* max_fanout = 4 *) logic rd_pointer;
//`else
  logic wr_pointer;
  logic rd_pointer;
//`endif

  // logic                               data_req_SRAM_int;
  // logic                               req_PIPE_out;
  // logic [PIPE_WIDTH-1:0]              data_PIPE_out;
  // logic [PIPE_WIDTH-1:0]              data_PIPE_in;

  // logic [ADDR_WIDTH-1:0]              add_PIPE_temp_out;
  // logic [SRAM_MEM_WIDTH-1:0]          add_PIPE_out;
  // logic                               wen_PIPE_out;
  // logic [DATA_WIDTH-1:0]              wdata_PIPE_out;
  // logic [BE_WIDTH-1:0]                be_PIPE_out;

  // logic en_latch;

  // assign add_PIPE_out = add_PIPE_temp_out[SRAM_MEM_WIDTH-1:0];

  // assign to_SCM = 1'b0;

  // interface logic
  logic readyToLatch;
  // assign readyToLatch = ~data_req_q[wr_pointer] | (data_req_q[wr_pointer] & data_gnt_i);
  assign readyToLatch = ~data_req_q[wr_pointer];
  always_ff @(posedge clk_i, negedge rstn_i) begin
    if(rstn_i == 1'b0) begin
      data_req_q   <= '0;
      data_add_q   <= '0;
      data_wen_q   <= '0;
      data_wdata_q <= '0;
      data_be_q    <= '0;
    end else begin
      if(readyToLatch) begin
        data_req_q[wr_pointer]   <= data_req_i;
        data_add_q[wr_pointer]   <= data_add_i;
        data_wen_q[wr_pointer]   <= data_wen_i;
        data_wdata_q[wr_pointer] <= data_wdata_i;
        data_be_q[wr_pointer]    <= data_be_i;
      end
      if(data_req_q[rd_pointer] & data_gnt_i) begin
        data_req_q[rd_pointer]   <= '0;
        //data_add_q[rd_pointer]   <= '0;
        //data_wen_q[rd_pointer]   <= '0;
        //data_wdata_q[rd_pointer] <= '0;
        //data_be_q[rd_pointer]    <= '0;
      end
    end
  end

  // For isolating interface
  // assign data_gnt_o = readyToLatch | ~data_req_i;
  assign data_gnt_o = readyToLatch;

  always_ff @(posedge clk_i, negedge  rstn_i) begin
    if(rstn_i == 1'b0) begin
      wr_pointer <= '0;
    end else begin
      if(readyToLatch & data_req_i) begin
        wr_pointer <= ~wr_pointer;
      end
    end
  end

  always_ff @(posedge clk_i, negedge rstn_i) begin
    if(rstn_i == 1'b0) begin
      rd_pointer <= '0;
    end else begin
      if(data_req_q[rd_pointer] & data_gnt_i) begin
        rd_pointer <= ~rd_pointer;
      end
    end
  end

  // always_ff @(posedge clk_i, negedge rstn_i) begin
  //   if(rstn_i == 1'b0) begin
  //     CS <= IDLE_SCM;
  //   end else begin
  //     CS <= NS;
  //   end
  // end

  // always_comb begin
  //   data_req_SRAM_int = 1'b0;
  //   en_latch = 1'b0;
  //   NS = CS;
  //   case(CS)
  //     IDLE_SCM: begin
  //       data_req_SRAM_int = data_req_i;
  //       if(data_req_i) begin
  //         en_latch = 1'b1;
  //         NS = SRAM_1;
  //       end else begin
  //         NS = IDLE_SCM;
  //       end
  //     end //~IDLE

  //     SRAM_1 : begin
  //       if(data_gnt_i) begin
  //         data_req_SRAM_int = data_req_i;
  //         if(data_req_i) begin
  //           en_latch = 1'b1;
  //           NS = SRAM_1;
  //         end else begin
  //           NS = IDLE_SCM;
  //         end
  //       end else begin
  //         NS = SRAM_1;
  //         data_req_SRAM_int = 1'b1;
  //       end
  //     end

  //     default : begin
  //       NS = IDLE_SCM;
  //       data_req_SRAM_int = 1'b0;
  //     end
  //   endcase
  // end

  // assign data_PIPE_in = {data_add_i,           data_wen_i,      data_wdata_i,      data_be_i   };
  // assign data_PIPE_out = {data_add_q,           data_wen_q,      data_wdata_q,      data_be_q   };
  // assign                {add_PIPE_temp_out,    wen_PIPE_out,    wdata_PIPE_out,    be_PIPE_out } = data_PIPE_out;

  // always_ff @(posedge clk_i, negedge rstn_i) begin
  //   if(rstn_i == 1'b0) begin
  //     req_PIPE_out <= 1'b0;
  //   end else begin
  //     req_PIPE_out <= data_req_SRAM_int;
  //   end
  // end

  // always_ff @(posedge clk_i, negedge rstn_i) begin
  //   if(rstn_i == 1'b0) begin
  //     data_PIPE_out      <= '0;
  //   end else begin
  //     if(en_latch) begin
  //       data_PIPE_out <= data_PIPE_in;
  //     end
  //   end
  // end

  always_comb begin
    data_req_SRAM_o    = data_req_q[rd_pointer];
    data_add_SRAM_o    = data_add_q[rd_pointer][SRAM_MEM_WIDTH-1:0];
    data_wen_SRAM_o    = data_wen_q[rd_pointer];
    data_wdata_SRAM_o  = data_wdata_q[rd_pointer];
    data_be_SRAM_o     = data_be_q[rd_pointer];
  end

endmodule