module tcdm_upcast# (
  parameter int unsigned SLV_WIDTH = 16,
  parameter int unsigned MAS_WIDTH = 16
) (
  input logic clk_i,
  input logic resetn_i,
  mem_intf.slave tcdm_master,
  mem_intf.master tcdm_slave
);

  if(SLV_WIDTH > MAS_WIDTH) begin
    $error("tcdm_upcast: SLV_WIDTH (%0d) must be <= MAS_WIDTH (%0d)", SLV_WIDTH, MAS_WIDTH);
  end
  if(MAS_WIDTH % SLV_WIDTH != 0) begin
    $error("tcdm_upcast: MAS_WIDTH (%0d) must be a multiple of SLV_WIDTH (%0d)", MAS_WIDTH, SLV_WIDTH);
  end

  // derived constants
  localparam int unsigned NARROW_BYTES = SLV_WIDTH/8;
  localparam int unsigned WIDE_BYTES   = MAS_WIDTH/8;

  // alignment offset in bytes
  logic [$clog2(MAS_WIDTH/SLV_WIDTH)-1:0] offset;
  logic [$clog2(MAS_WIDTH/SLV_WIDTH)-1:0] offset_q;
  logic [MAS_WIDTH-1:0] wide_data_out; 
  logic [WIDE_BYTES-1:0] wide_be_out; 
  logic [MAS_WIDTH-1:0] wide_r_data;
  logic [SLV_WIDTH-1:0] narrow_r_data;
  
  assign offset = tcdm_master.addr[$clog2(WIDE_BYTES)-1:$clog2(NARROW_BYTES)];
  always_ff @(posedge clk_i, negedge resetn_i) begin
    if(~resetn_i) begin
      offset_q <= '0;
    end else if(tcdm_master.req & tcdm_master.gnt & ~tcdm_master.wen) begin
      offset_q <= offset;
    end
  end

  // ---- WRITE path ----
  // position narrow data into the correct lanes of the wide bus
  assign wide_data_out = ({{MAS_WIDTH{1'b0}}}) | (tcdm_master.data << (offset * SLV_WIDTH));

  // shift/scale the byte enables the same way
  assign wide_be_out = tcdm_master.be << (offset * NARROW_BYTES);

  // drive wide-side signals when master requests a write
  assign tcdm_slave.req   = tcdm_master.req & (~tcdm_master.r_valid | tcdm_master.r_ready);
  assign tcdm_slave.addr  = {tcdm_master.addr[$bits(tcdm_master.addr)-1:$clog2(WIDE_BYTES)], {$clog2(WIDE_BYTES){1'b0}}};
  assign tcdm_slave.wen   = tcdm_master.wen;
  assign tcdm_slave.data  = wide_data_out;
  assign tcdm_slave.be    = wide_be_out;
  assign tcdm_slave.r_ready = tcdm_master.r_ready;

  // pass grant back
  assign tcdm_master.gnt  = tcdm_slave.gnt & (~tcdm_master.r_valid | tcdm_master.r_ready);

  // ---- READ path ----
  // on a read request, pass it upstream exactly the same way...
  // address must still be aligned to the wide word
  // eagerly issue the wide read, then later extract
  // …so this can all be done combinationally once r_data is valid.

  // once the wide r_data comes back, shift it down
  assign wide_r_data = tcdm_slave.r_data;
  assign narrow_r_data = (wide_r_data >> (offset_q * SLV_WIDTH));

  // drive the narrow read-response
  assign tcdm_master.r_data  = narrow_r_data;
  assign tcdm_master.r_valid = tcdm_slave.r_valid;

  // deactivate unused signals when no request
  // (you may need to add back-pressure logic / handshaking here)

endmodule