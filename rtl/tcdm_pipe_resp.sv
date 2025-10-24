module tcdm_pipe_resp
  #(
    parameter  DATA_WIDTH      = 32
  )
  (
    input  logic                                 clk_i,
    input  logic                                 rstn_i,

    input  logic [DATA_WIDTH-1:0]                data_r_rdata_SRAM_i,

    input  logic                                 rvalid_i,

    output logic [DATA_WIDTH-1:0]                data_r_rdata_o,
    output logic                                 data_r_valid_o
  );

  logic [DATA_WIDTH-1:0]              data_r_rdata_post_PIPE;
  logic                               data_r_valid_post_PIPE;

  //OK
  always_ff @(posedge clk_i, negedge rstn_i) begin
    if(rstn_i == 1'b0) begin
      data_r_rdata_post_PIPE    <= '0;
      data_r_valid_post_PIPE    <= 1'b0;
    end else begin
      if(rvalid_i) begin
        data_r_rdata_post_PIPE    <= data_r_rdata_SRAM_i;
        data_r_valid_post_PIPE    <= rvalid_i;
      end else begin
        data_r_rdata_post_PIPE    <= 'X;
        data_r_valid_post_PIPE    <= 1'b0;
      end

    end
  end

  always_comb begin
    data_r_rdata_o = '0;
    data_r_valid_o = '0;
    if(data_r_valid_post_PIPE) begin // SRAM from PIPE
      data_r_rdata_o = data_r_rdata_post_PIPE;
      data_r_valid_o = data_r_valid_post_PIPE;
    end
  end

endmodule