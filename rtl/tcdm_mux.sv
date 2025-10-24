module tcdm_mux #(
  parameter int unsigned NUM_MASTER = 2,
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned ADDR_WIDTH = 32,
  parameter int unsigned ExtPrio = 1
) (
  input logic clk_i,
  input logic resetn_i,
  input logic [$clog2(NUM_MASTER)-1:0] rr_i,
  mem_intf.slave tcdm_master_port [NUM_MASTER],
  mem_intf.master tcdm_slave_port
);

    logic [$clog2(NUM_MASTER)-1:0] m_idx;
    `TCDM_EXPLODE_ARRAY_DECLARE_PARAM(tcdm_master_port, NUM_MASTER, DATA_WIDTH, ADDR_WIDTH);
    for(genvar midx=0; midx < NUM_MASTER; midx++) begin : gen_master_port
      `TCDM_MASTER_EXPLODE(tcdm_master_port[midx], tcdm_master_port, [midx]);
    end

    // arbiter
    rr_arb_tree #(
        .NumIn    (NUM_MASTER),
        .DataWidth(DATA_WIDTH),
        .AxiVldRdy(1'b0),
        .LockIn   (1'b0),
        .FairArb  (1'b1),
        .ExtPrio  (ExtPrio)
    ) u_rr_arb_tree (
        .clk_i  (clk_i),
        .rst_ni (resetn_i),
        .flush_i(1'b0),
        .rr_i   (rr_i),
        .req_i  (tcdm_master_port_req),
        .gnt_o  (tcdm_master_port_gnt),
        .data_i (tcdm_master_port_data),
        .req_o  (tcdm_slave_port.req),
        .gnt_i  (tcdm_slave_port.gnt),
        .data_o (tcdm_slave_port.data),
        .idx_o  (m_idx)
    );

    assign tcdm_slave_port.addr = tcdm_master_port_addr[m_idx];
    assign tcdm_slave_port.wen  = tcdm_master_port_wen[m_idx];
    assign tcdm_slave_port.be   = tcdm_master_port_be[m_idx];

    resp_demux #(
        .NUM_OUTPUTS(NUM_MASTER),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_resp_demux (
        .clk_i       (clk_i),
        .resetn_i    (resetn_i),
        .req_i       (tcdm_slave_port.req),
        .gnt_i       (tcdm_slave_port.gnt),
        .master_idx_i(m_idx),
        
        .rdata_i     (tcdm_slave_port.r_data),
        .rvalid_i    (tcdm_slave_port.r_valid),
        .rready_o    (tcdm_slave_port.r_ready),

        .wen_i       (tcdm_master_port_wen),
        .rready_i    (tcdm_master_port_r_ready),
        .rdata_o     (tcdm_master_port_r_data),
        .rvalid_o    (tcdm_master_port_r_valid)
    );

endmodule
