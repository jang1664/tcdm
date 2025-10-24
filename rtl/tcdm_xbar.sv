module tcdm_xbar 
  import mem_pkg::*;
#(
  parameter int unsigned NUM_MASTER = 2,
  parameter int unsigned NUM_SLAVE = 2,
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned ADDR_WIDTH = 32,
  parameter int unsigned BE_WIDTH = DATA_WIDTH / 8
)(
  input logic clk_i,
  input logic resetn_i,
  mem_intf.slave master_ports[NUM_MASTER],
  mem_intf.master slave_ports[NUM_SLAVE]
);

  // demux array
  typedef addr_map_rule_t [NUM_SLAVE-1:0] addr_map_type;
  function addr_map_type gen_addr_map();
    addr_map_type addr_map;
    for (int i = 0; i < NUM_SLAVE; i++) begin
      addr_map[i] = '{i, (DATA_WIDTH / 8) * i, (DATA_WIDTH / 8) * (i + 1)};
    end
    return addr_map;
  endfunction
  localparam addr_map_rule_t [NUM_SLAVE-1:0] ADDR_MAP_RULES = gen_addr_map();

  mem_intf #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) internal[NUM_MASTER*NUM_SLAVE] ( .clk(clk_i));
  mem_intf #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) internal_reshape[NUM_MASTER*NUM_SLAVE] ( .clk(clk_i));

  generate
    for(genvar m=0; m<NUM_MASTER; m++) begin : gen_demux
      tcdm_demux #(
        .NR_OUTPUTS(NUM_SLAVE),
        .NR_ADDR_MAP_RULES(NUM_SLAVE),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .BE_WIDTH(BE_WIDTH),
        .INTERLEAVED(1),
        .OFFSET_ADDR_LSB($clog2(DATA_WIDTH / 8) + 1),
        .OFFSET_ADDR_MSB($clog2((DATA_WIDTH * NUM_SLAVE) / 8) - 1),
        .addr_map_rules(ADDR_MAP_RULES)
      ) u_tcdm_demux(
        .clk_i(clk_i),
        .resetn_i(resetn_i),
        .master_port(master_ports[m]),
        .slave_ports(internal[m*NUM_SLAVE +: NUM_SLAVE])
      );
    end

    for(genvar m=0; m<NUM_MASTER; m++) begin
      for(genvar s=0; s<NUM_SLAVE; s++) begin
        `TCDM_ASSIGN_INTF(internal_reshape[s*NUM_MASTER + m], internal[m*NUM_SLAVE + s]);
      end
    end

    for(genvar s=0; s<NUM_SLAVE; s++) begin : gen_mux
      tcdm_mux #(
        .NUM_MASTER(NUM_MASTER),
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .ExtPrio(0)
      ) u_tcdm_mux(
        .clk_i(clk_i),
        .resetn_i(resetn_i),
        .tcdm_master_port(internal_reshape[s*NUM_MASTER +: NUM_MASTER]),
        .tcdm_slave_port(slave_ports[s])
      );
    end
  endgenerate

endmodule