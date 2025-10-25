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

  // master port
  input  logic [NUM_MASTER-1:0]                     mas_req_i,
  output logic [NUM_MASTER-1:0]                     mas_gnt_o,
  input  logic [NUM_MASTER-1:0][    ADDR_WIDTH-1:0] mas_addr_i,
  input  logic [NUM_MASTER-1:0]                     mas_wen_i,
  input  logic [NUM_MASTER-1:0][(DATA_WIDTH/8)-1:0] mas_be_i,
  input  logic [NUM_MASTER-1:0][    DATA_WIDTH-1:0] mas_data_i,
  output logic [NUM_MASTER-1:0][    DATA_WIDTH-1:0] mas_r_data_o,
  output logic [NUM_MASTER-1:0]                     mas_r_valid_o,
  input  logic [NUM_MASTER-1:0]                     mas_r_ready_i,

  // slave port
  output  logic [NUM_SLAVE-1:0]                     slv_req_o,
  input   logic [NUM_SLAVE-1:0]                     slv_gnt_i,
  output  logic [NUM_SLAVE-1:0][    ADDR_WIDTH-1:0] slv_addr_o,
  output  logic [NUM_SLAVE-1:0]                     slv_wen_o,
  output  logic [NUM_SLAVE-1:0][(DATA_WIDTH/8)-1:0] slv_be_o,
  output  logic [NUM_SLAVE-1:0][    DATA_WIDTH-1:0] slv_data_o,
  input   logic [NUM_SLAVE-1:0][    DATA_WIDTH-1:0] slv_r_data_i,
  input   logic [NUM_SLAVE-1:0]                     slv_r_valid_i,
  output  logic [NUM_SLAVE-1:0]                     slv_r_ready_o
);

  // Interface declarations
  mem_intf #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) master_ports[NUM_MASTER] (.clk(clk_i));

  mem_intf #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) slave_ports[NUM_SLAVE] (.clk(clk_i));

  // Connect master ports (exploded signals to interface)
  generate
    for (genvar m = 0; m < NUM_MASTER; m++) begin : gen_master_connect
      `TCDM_SLAVE_EXPLODE_IO(master_ports[m], mas, _i[m], _o[m])
    end
  endgenerate

  // Connect slave ports (interface to exploded signals)
  generate
    for (genvar s = 0; s < NUM_SLAVE; s++) begin : gen_slave_connect
      `TCDM_MASTER_EXPLODE_IO(slave_ports[s], slv, _i[s], _o[s])
    end
  endgenerate

  // Instantiate the interface-based crossbar
  tcdm_xbar_intf #(
    .NUM_MASTER(NUM_MASTER),
    .NUM_SLAVE(NUM_SLAVE),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .BE_WIDTH(BE_WIDTH)
  ) u_tcdm_xbar_intf (
    .clk_i(clk_i),
    .resetn_i(resetn_i),
    .master_ports(master_ports),
    .slave_ports(slave_ports)
  );

endmodule