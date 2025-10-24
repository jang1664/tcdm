module tcdm_slice
  #(
    parameter  ADDR_WIDTH      = 11,
    parameter  DATA_WIDTH      = 32,
    localparam BE_WIDTH        = DATA_WIDTH/8
  )
  (
    input logic                     clk_i,
    input logic                     rstn_i,

    // Slave interface (input from master)
    input logic                     slv_req_i,
    output logic                    slv_gnt_o,
    input logic [ADDR_WIDTH-1:0]    slv_addr_i,
    input logic                     slv_wen_i,
    input logic [BE_WIDTH-1:0]      slv_be_i,
    input logic [DATA_WIDTH-1:0]    slv_data_i,
    input logic                     slv_r_ready_i,
    output logic [DATA_WIDTH-1:0]   slv_r_data_o,
    output logic                    slv_r_valid_o,

    // Master interface (output to slave)
    output logic                    mst_req_o,
    input logic                     mst_gnt_i,
    output logic [ADDR_WIDTH-1:0]   mst_addr_o,
    output logic                    mst_wen_o,
    output logic [BE_WIDTH-1:0]     mst_be_o,
    output logic [DATA_WIDTH-1:0]   mst_data_o,
    output logic                    mst_r_ready_o,
    input logic [DATA_WIDTH-1:0]    mst_r_data_i,
    input logic                     mst_r_valid_i
  );

  // Internal signals between request and response pipelines
  logic                     req_pipe_gnt;
  logic                     resp_pipe_valid;
  logic [DATA_WIDTH-1:0]    resp_pipe_data;

  // Request pipeline instance
  tcdm_pipe_req #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) u_req_pipe (
    .clk_i          (clk_i),
    .rstn_i         (rstn_i),
    
    // Input from slave interface
    .data_req_i     (slv_req_i),
    .data_add_i     (slv_addr_i),
    .data_wen_i     (slv_wen_i),
    .data_wdata_i   (slv_data_i),
    .data_be_i      (slv_be_i),
    .data_gnt_i     (mst_gnt_i),
    
    // Output to master interface
    .data_gnt_o     (slv_gnt_o),
    .data_req_SRAM_o(mst_req_o),
    .data_add_SRAM_o(mst_addr_o),
    .data_wen_SRAM_o(mst_wen_o),
    .data_wdata_SRAM_o(mst_data_o),
    .data_be_SRAM_o (mst_be_o)
  );

  // Response pipeline instance
  tcdm_pipe_resp #(
    .DATA_WIDTH(DATA_WIDTH)
  ) u_resp_pipe (
    .clk_i                  (clk_i),
    .rstn_i                 (rstn_i),
    
    // Input from master interface
    .data_r_rdata_SRAM_i    (mst_r_data_i),
    .rvalid_i               (mst_r_valid_i),
    
    // Output to slave interface
    .data_r_rdata_o         (slv_r_data_o),
    .data_r_valid_o         (slv_r_valid_o)
  );

  // Pass through r_ready signal (no pipelining needed for backpressure)
  assign mst_r_ready_o = slv_r_ready_i;

endmodule
