module resp_demux #(
  parameter int unsigned NUM_OUTPUTS = 4,
  parameter int unsigned DATA_WIDTH = 32
)(
  input logic clk_i,
  input logic resetn_i,

  input logic req_i,
  input logic gnt_i,
  input logic [$clog2(NUM_OUTPUTS)-1:0] master_idx_i,

  // slave
  input logic [DATA_WIDTH-1:0] rdata_i,
  input logic rvalid_i,
  output logic rready_o,

  // master
  input logic [NUM_OUTPUTS-1:0] wen_i,
  input logic [NUM_OUTPUTS-1:0] rready_i,
  output logic [NUM_OUTPUTS-1:0][DATA_WIDTH-1:0] rdata_o,
  output logic [NUM_OUTPUTS-1:0] rvalid_o
);

  logic [$clog2(NUM_OUTPUTS)-1:0] service_master_idx;

  always_ff @(posedge clk_i, negedge resetn_i) begin
    if(~resetn_i) begin
      service_master_idx <= '0;
    end else begin
      if(req_i & gnt_i & ~wen_i[master_idx_i]) begin
        service_master_idx <= master_idx_i;
      end
    end
  end

  assign rready_o = rready_i[service_master_idx];
  always_comb begin
    rdata_o = '0;
    rdata_o[service_master_idx] = rdata_i;

    rvalid_o = '0;
    rvalid_o[service_master_idx] = rvalid_i;
  end

endmodule