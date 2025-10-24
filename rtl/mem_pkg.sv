/*
 * hwpe_stream_package.sv
 * Francesco Conti <f.conti@unibo.it>
 *
 * Copyright (C) 2014-2018 ETH Zurich, University of Bologna
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 */

package mem_pkg;

  typedef struct packed {
    logic empty;
    logic full;
    logic [7:0] push_pointer;
    logic [7:0] pop_pointer;
  } flags_fifo_t;

  typedef struct packed {
    logic [31:0] idx;
    logic [31:0] start_addr;
    logic [31:0] end_addr;
  } addr_map_rule_t;

  `define TCDM_PORT_EXPLODE_ARRAY_DECLARE_PARAM_MASTER(signal_prefix, datawidth, addrwidth) \
output logic                     signal_prefix``_req_o, \
output logic [addrwidth-1:0]     signal_prefix``_addr_o, \
output logic                     signal_prefix``_wen_o, \
output logic [datawidth-1:0]     signal_prefix``_data_o, \
output logic [(datawidth/8)-1:0] signal_prefix``_be_o, \
input  logic                     signal_prefix``_gnt_i, \
input  logic [datawidth-1:0]     signal_prefix``_r_data_i, \
input  logic                     signal_prefix``_r_valid_i, \
output logic                     signal_prefix``_r_ready_o

  `define TCDM_PORT_EXPLODE_ARRAY_DECLARE_PARAM_SLAVE(signal_prefix, datawidth, addrwidth) \
input  logic                     signal_prefix``_req_i, \
input  logic [addrwidth-1:0]     signal_prefix``_addr_i, \
input  logic                     signal_prefix``_wen_i, \
input  logic [datawidth-1:0]     signal_prefix``_data_i, \
input  logic [(datawidth/8)-1:0] signal_prefix``_be_i, \
output logic                     signal_prefix``_gnt_o, \
output logic [datawidth-1:0]     signal_prefix``_r_data_o, \
output logic                     signal_prefix``_r_valid_o, \
input  logic                     signal_prefix``_r_ready_i

  `define TCDM_PORT_EXPLODE_ARRAY_DECLARE_PARAM_MASTER_ARR(signal_prefix, length, datawidth, addrwidth) \
output logic [length-1:0]                    signal_prefix``_req_o, \
output logic [length-1:0][addrwidth-1:0]     signal_prefix``_addr_o, \
output logic [length-1:0]                    signal_prefix``_wen_o, \
output logic [length-1:0][datawidth-1:0]     signal_prefix``_data_o, \
output logic [length-1:0][(datawidth/8)-1:0] signal_prefix``_be_o, \
input  logic [length-1:0]                    signal_prefix``_gnt_i, \
input  logic [length-1:0][datawidth-1:0]     signal_prefix``_r_data_i, \
input  logic [length-1:0]                    signal_prefix``_r_valid_i, \
output logic [length-1:0]                    signal_prefix``_r_ready_o

  `define TCDM_PORT_EXPLODE_ARRAY_DECLARE_PARAM_SLAVE_ARR(signal_prefix, length, datawidth, addrwidth) \
input logic [length-1:0]                    signal_prefix``_req_i, \
input logic [length-1:0][addrwidth-1:0]     signal_prefix``_addr_i, \
input logic [length-1:0]                    signal_prefix``_wen_i, \
input logic [length-1:0][datawidth-1:0]     signal_prefix``_data_i, \
input logic [length-1:0][(datawidth/8)-1:0] signal_prefix``_be_i, \
output  logic [length-1:0]                    signal_prefix``_gnt_o, \
output  logic [length-1:0][datawidth-1:0]     signal_prefix``_r_data_o, \
output  logic [length-1:0]                    signal_prefix``_r_valid_o, \
input logic [length-1:0]                    signal_prefix``_r_ready_i

  `define TCDM_EXPLODE_ARRAY_DECLARE(signal_prefix, length) \
logic [length-1:0]                 signal_prefix``_req; \
logic [length-1:0][31:0]           signal_prefix``_addr; \
logic [length-1:0]                 signal_prefix``_wen; \
logic [length-1:0][31:0]           signal_prefix``_data; \
logic [length-1:0][3:0]            signal_prefix``_be; \
logic [length-1:0]                 signal_prefix``_gnt; \
logic [length-1:0][31:0]           signal_prefix``_r_data; \
logic [length-1:0]                 signal_prefix``_r_valid; \
logic [length-1:0]                 signal_prefix``_r_ready;

  `define TCDM_EXPLODE_ARRAY_DECLARE_PARAM(signal_prefix, length, datawidth, addrwidth) \
logic [length-1:0]                 signal_prefix``_req; \
logic [length-1:0][addrwidth-1:0]           signal_prefix``_addr; \
logic [length-1:0]                 signal_prefix``_wen; \
logic [length-1:0][datawidth-1:0]           signal_prefix``_data; \
logic [length-1:0][(datawidth/8)-1:0]            signal_prefix``_be; \
logic [length-1:0]                 signal_prefix``_gnt; \
logic [length-1:0][datawidth-1:0]           signal_prefix``_r_data; \
logic [length-1:0]                 signal_prefix``_r_valid; \
logic [length-1:0]                 signal_prefix``_r_ready;

  `define TCDM_EXPLODE_DECLARE(signal_prefix) \
logic                  signal_prefix``_req; \
logic [31:0]           signal_prefix``_addr; \
logic                  signal_prefix``_wen; \
logic [31:0]           signal_prefix``_data; \
logic [3:0]            signal_prefix``_be; \
logic                  signal_prefix``_gnt; \
logic [31:0]           signal_prefix``_r_data; \
logic                  signal_prefix``_r_valid; \
logic                  signal_prefix``_r_ready;

  `define TCDM_EXPLODE_DECLARE_PARAM(signal_prefix, datawidth, addrwidth) \
logic                  signal_prefix``_req; \
logic [addrwidth-1:0]           signal_prefix``_addr; \
logic                  signal_prefix``_wen; \
logic [datawidth-1:0]           signal_prefix``_data; \
logic [(datawidth/8)-1:0]            signal_prefix``_be; \
logic                  signal_prefix``_gnt; \
logic [datawidth-1:0]           signal_prefix``_r_data; \
logic                  signal_prefix``_r_valid; \
logic                  signal_prefix``_r_ready;

  //Connect a TCDM Master Interface to a set of exploded interface signals
  `define TCDM_SLAVE_EXPLODE(iface, exploded_prefix, postfix) \
assign iface.req = exploded_prefix``_req postfix; \
assign iface.addr = exploded_prefix``_addr postfix; \
assign iface.wen = exploded_prefix``_wen postfix; \
assign iface.data = exploded_prefix``_data postfix; \
assign iface.be = exploded_prefix``_be postfix; \
assign iface.r_ready = exploded_prefix``_r_ready postfix; \
assign exploded_prefix``_gnt postfix = iface.gnt; \
assign exploded_prefix``_r_data postfix = iface.r_data; \
assign exploded_prefix``_r_valid postfix = iface.r_valid;

  `define TCDM_SLAVE_EXPLODE_IO(iface, exploded_prefix, postfix_i, postfix_o) \
assign iface.req = exploded_prefix``_req``postfix_i; \
assign iface.addr = exploded_prefix``_addr``postfix_i; \
assign iface.wen = exploded_prefix``_wen``postfix_i; \
assign iface.data = exploded_prefix``_data``postfix_i; \
assign iface.be = exploded_prefix``_be``postfix_i; \
assign iface.r_ready = exploded_prefix``_r_ready``postfix_i; \
assign exploded_prefix``_gnt``postfix_o = iface.gnt; \
assign exploded_prefix``_r_data``postfix_o = iface.r_data; \
assign exploded_prefix``_r_valid``postfix_o = iface.r_valid;

  //Connect a TCDM Slave Interface to a set of exploded interface signals
  `define TCDM_MASTER_EXPLODE(iface, exploded_prefix, postfix) \
assign exploded_prefix``_req postfix = iface.req; \
assign exploded_prefix``_addr postfix = iface.addr; \
assign exploded_prefix``_wen postfix = iface.wen; \
assign exploded_prefix``_data postfix = iface.data; \
assign exploded_prefix``_be postfix = iface.be; \
assign exploded_prefix``_r_ready postfix = iface.r_ready; \
assign iface.gnt = exploded_prefix``_gnt postfix; \
assign iface.r_data = exploded_prefix``_r_data postfix; \
assign iface.r_valid = exploded_prefix``_r_valid postfix;

  //Connect a TCDM Slave Interface to a set of exploded interface signals
  `define TCDM_MASTER_EXPLODE_IO(iface, exploded_prefix, postfix_i, postfix_o) \
assign exploded_prefix``_req``postfix_o = iface.req; \
assign exploded_prefix``_addr``postfix_o = iface.addr; \
assign exploded_prefix``_wen``postfix_o = iface.wen; \
assign exploded_prefix``_data``postfix_o = iface.data; \
assign exploded_prefix``_be``postfix_o = iface.be; \
assign exploded_prefix``_r_ready``postfix_o = iface.r_ready; \
assign iface.gnt = exploded_prefix``_gnt``postfix_i; \
assign iface.r_data = exploded_prefix``_r_data``postfix_i; \
assign iface.r_valid = exploded_prefix``_r_valid``postfix_i;

  `define TCDM_ASSIGN_INTF(b, a) \
assign b.req  = a.req; \
assign b.addr  = a.addr; \
assign b.wen  = a.wen; \
assign b.data  = a.data; \
assign b.be  = a.be; \
assign b.r_ready  = a.r_ready; \
assign a.gnt = b.gnt ; \
assign a.r_data= b.r_data ; \
assign a.r_valid = b.r_valid ;

  `define TCDM_ASSIGN(b, postfix_b, a, postfix_a) \
assign b``_req postfix_b  = a``_req postfix_a; \
assign b``_addr postfix_b  = a``_addr postfix_a; \
assign b``_wen postfix_b  = a``_wen postfix_a; \
assign b``_data postfix_b  = a``_data postfix_a; \
assign b``_be postfix_b  = a``_be postfix_a; \
assign b``_r_ready postfix_b  = a``_r_ready postfix_a; \
assign a``_gnt postfix_a = b``_gnt postfix_b ; \
assign a``_r_data postfix_a= b``_r_data postfix_b ; \
assign a``_r_valid postfix_a = b``_r_valid postfix_b ; 

  `define MEM_MASTER_TO_STREAM_PUSH_ASSIGN(master_port, push_port) \
  assign push_port.valid = master_port.req & master_port.wen; \
  assign push_port.data = master_port.data; \
  assign push_port.strb = master_port.be; \
  assign master_port.gnt = master_port.req & master_port.wen & push_port.ready; \
  assign master_port.r_data = '0; \
  assign master_port.r_valid = '0;


  `define TCDM_DBG_ASSIGN(iface, exploded_prefix, postfix_i, postfix_o) \
assign exploded_prefix``_req``postfix_i = iface.req; \
assign exploded_prefix``_addr``postfix_i = iface.addr; \
assign exploded_prefix``_wen``postfix_i = iface.wen; \
assign exploded_prefix``_data``postfix_i = iface.data; \
assign exploded_prefix``_be``postfix_i = iface.be; \
assign exploded_prefix``_r_ready``postfix_i = iface.r_ready; \
assign exploded_prefix``_gnt``postfix_o = iface.gnt; \
assign exploded_prefix``_r_data``postfix_o = iface.r_data; \
assign exploded_prefix``_r_valid``postfix_o = iface.r_valid;

  `define TCDM_MASTER_PORT_CONN(port_prefix, sig_prefix, sig_postfix) \
    .port_prefix``_req_o    (sig_prefix``_req sig_postfix), \
    .port_prefix``_addr_o   (sig_prefix``_addr sig_postfix), \
    .port_prefix``_wen_o    (sig_prefix``_wen sig_postfix), \
    .port_prefix``_data_o   (sig_prefix``_data sig_postfix), \
    .port_prefix``_be_o     (sig_prefix``_be sig_postfix), \
    .port_prefix``_gnt_i    (sig_prefix``_gnt sig_postfix), \
    .port_prefix``_r_data_i (sig_prefix``_r_data sig_postfix), \
    .port_prefix``_r_valid_i(sig_prefix``_r_valid sig_postfix), \
    .port_prefix``_r_ready_o(sig_prefix``_r_ready sig_postfix)
  
  `define TCDM_MASTER_PORT_CONN_INTF(port_prefix, if_prefix) \
    .port_prefix``_req_o    (if_prefix.req), \
    .port_prefix``_addr_o   (if_prefix.addr), \
    .port_prefix``_wen_o    (if_prefix.wen), \
    .port_prefix``_data_o   (if_prefix.data), \
    .port_prefix``_be_o     (if_prefix.be), \
    .port_prefix``_gnt_i    (if_prefix.gnt), \
    .port_prefix``_r_data_i (if_prefix.r_data), \
    .port_prefix``_r_valid_i(if_prefix.r_valid), \
    .port_prefix``_r_ready_o(if_prefix.r_ready)

endpackage
