//-----------------------------------------------------------------------------
// Title         : TCDM Demultiplexer
//-----------------------------------------------------------------------------
// File          : tcdm_demux.sv
// Author        : Manuel Eggimann  <meggimann@iis.ee.ethz.ch>
// Created       : 29.10.2020
//-----------------------------------------------------------------------------
// Description :
// This IP demultiplexes transactions on an input TCDM port to several TCDM output
// ports.
//-----------------------------------------------------------------------------
// Copyright (C) 2013-2020 ETH Zurich, University of Bologna
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//-----------------------------------------------------------------------------

module mem_intf_demux
  import mem_pkg::*;
  import npu_global_params::*;
#(
    parameter int unsigned NR_OUTPUTS = 2,
    parameter int unsigned NR_ADDR_MAP_RULES=1,
    parameter addr_map_rule_t [NR_ADDR_MAP_RULES-1:0] addr_map_rules=0,
    parameter int unsigned BE_WIDTH = 2,
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32,
    localparam int unsigned SLAVE_SEL_WIDTH = $clog2(NR_OUTPUTS)
) (
    input logic           clk_i,
    input logic           resetn_i,
          mem_intf.slave  master_port,
          mem_intf.master slave_ports[NR_OUTPUTS]
);
  // Do **not** change. The TCDM interface uses hardcoded bus widths so we cannot just change them here.

  // Explode the output interfaces to  individual signals
  `TCDM_EXPLODE_ARRAY_DECLARE_PARAM(slave_ports, NR_OUTPUTS, DATA_WIDTH, ADDR_WIDTH);
  for (genvar i = 0; i < NR_OUTPUTS; i++) begin : gen_bridge
    `TCDM_SLAVE_EXPLODE(slave_ports[i], slave_ports, [i])  // exploded (master) -> interface(master)
  end

  //The Address Decoder module generates the select signal for the demux. If there is no match in the input rules, the
  //address decoder will select port 0 by default.
  logic [SLAVE_SEL_WIDTH-1:0] port_sel;
  addr_decode #(
      .NoIndices(NR_OUTPUTS),
      .NoRules(NR_ADDR_MAP_RULES),
      .addr_t(logic [_SLV_INTF_ADDR_WIDTH-1:0]),
      .rule_t(mem_pkg::addr_map_rule_t),
      .addr_map_i(addr_map_rules)
  ) i_addr_decode (
      .addr_i(master_port.addr),
      .idx_o(port_sel),
      .dec_valid_o(),
      .dec_error_o(),
      .en_default_idx_i(1'b1),
      .default_idx_i('0)  //If no rule matches we route to the first slave
      //port
  );

  typedef enum logic [0:0] {
    IDLE,
    PENDING
  } state_e;

  state_e state_d, state_q;
  logic [SLAVE_SEL_WIDTH-1:0] active_slave_d, active_slave_q;

  //Flip-Flop for FSM state
  always_ff @(posedge clk_i, negedge resetn_i) begin
    if (!resetn_i) begin
      state_q <= IDLE;
      active_slave_q <= '0;
    end else begin
      state_q <= state_d;
      active_slave_q <= active_slave_d;
    end
  end

  //Broadcast to all slaves. Only the request is actualy demultiplexed

  //Transaction FSM
  always_comb begin
    slave_ports_addr           = '0;
    slave_ports_wen            = '1;
    slave_ports_data           = '0;
    slave_ports_be             = '0;
    slave_ports_r_ready        = '0;

    slave_ports_addr[port_sel] = master_port.addr - addr_map_rules[port_sel].start_addr;
    slave_ports_wen[port_sel]  = master_port.wen;
    slave_ports_data[port_sel] = master_port.data;
    slave_ports_be[port_sel]   = master_port.be;
    slave_ports_r_ready[port_sel] = master_port.r_ready;

    master_port.r_data         = '0;
    master_port.r_valid        = 1'b0;
    master_port.gnt            = 1'b0;
    slave_ports_req            = '0;
    state_d                    = state_q;
    active_slave_d             = active_slave_q;
    case (state_q)
      IDLE: begin
        if (master_port.req) begin
          //Issue the request to the right port and change the state
          slave_ports_req[port_sel] = master_port.req;
          active_slave_d            = port_sel;
          //Wait until we receive the grant signal from the slave
          if (slave_ports_gnt[port_sel]) begin
            master_port.gnt = 1'b1;
            if (master_port.wen == 0) begin
              state_d = PENDING;
            end else begin
              state_d = IDLE;
            end
          end else begin
            master_port.gnt = 1'b0;
            state_d = IDLE;
          end
        end else begin
          state_d = IDLE;
        end
      end  // case: IDLE

      PENDING: begin
        master_port.r_valid = slave_ports_r_valid[active_slave_q];
        master_port.r_data  = slave_ports_r_data[active_slave_q];
        //Wait until we receive the r_valid
        if (slave_ports_r_valid[active_slave_q]) begin
          //Check if we receive another request back to back
          if (master_port.req) begin
            slave_ports_req[port_sel] = master_port.req;
            active_slave_d            = port_sel;
            //If we receive the grant we remain in the pending state. Otherwise we switch to IDLE state
            if (slave_ports_gnt[port_sel]) begin
              master_port.gnt = 1'b1;
              if (master_port.wen == 0) begin
                state_d = PENDING;
              end else begin
                state_d = IDLE;
              end
            end else begin
              master_port.gnt = 1'b0;
              state_d = IDLE;
            end
          end else begin
            state_d = IDLE;
          end
        end else begin
          state_d = PENDING;
        end
      end
    endcase
  end

endmodule
