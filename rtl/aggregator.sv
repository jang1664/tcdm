/*
 *TODO flush signal. when reg data not complete, flush siganl...
*/
module aggregator #(
    parameter int unsigned MAS_DATA_WIDTH = 32,
    parameter int unsigned SLV_DATA_WIDTH = 128,
    parameter int unsigned ADDR_WIDTH = 32
) (
    input logic clk_i,
    input logic resetn_i,
    mem_intf.slave master_port,
    mem_intf.master slave_port
);
  localparam NB_BLK = (SLV_DATA_WIDTH / MAS_DATA_WIDTH);

  //------------------------------------------------------------------
  //- signals
  //------------------------------------------------------------------
  logic [ADDR_WIDTH-1:0] addr_d;
  logic [ADDR_WIDTH-1:0] depth_d;
  logic [ADDR_WIDTH-1:0] offset_d;

  logic [NB_BLK-1:0][ADDR_WIDTH-1:0] wr_addr_q;
  logic [NB_BLK-1:0][ADDR_WIDTH-1:0] wr_depth_q;
  logic [NB_BLK-1:0][ADDR_WIDTH-1:0] wr_offset_q;
  logic [NB_BLK-1:0] w_valid_q;
  logic all_w_valid;
  logic any_w_valid;
  logic master_write_hs;
  logic slave_write_hs;
  logic wr_err;

  logic [NB_BLK-1:0][MAS_DATA_WIDTH-1:0] data_reg;

  logic r_valid_q;
  logic [ADDR_WIDTH-1:0] r_addr_q;
  logic [ADDR_WIDTH-1:0] r_addr_q_;
  logic [ADDR_WIDTH-1:0] r_depth_addr_q;
  logic [ADDR_WIDTH-1:0] r_depth_addr_q_;
  logic r_depth_addr_match_d;  // whether master req address is matched with reg read depth address
  logic r_depth_addr_match;  // whether master req address is matched with reg read depth address
  logic master_read_hs;
  logic slave_read_hs;

  //------------------------------------------------------------------
  //- implementation
  //------------------------------------------------------------------
  generate
    if (SLV_DATA_WIDTH < MAS_DATA_WIDTH) begin
`ifdef FUNCTIONAL
      localparam string message = $sformatf(
          "[%m]: In Aggregator, Slave port width should be larger than Master port width"
      );
      $error(
          "%s", message
      );
`endif
    end else if (SLV_DATA_WIDTH == MAS_DATA_WIDTH) begin
      `TCDM_ASSIGN_INTF(slave_port, master_port)
    end else begin
      //* parameter sanity check
      if (SLV_DATA_WIDTH % MAS_DATA_WIDTH != 0) begin
`ifdef FUNCTIONAL
        localparam string message = $sformatf(
            "[%m]: In Aggregator, Slave port width should be divisible by Master port width"
        );
        $error(
            "%s", message
        );
`endif
      end
      //* address parsing
      assign addr_d = master_port.addr;
      assign depth_d = addr_d[ADDR_WIDTH-1:$clog2(SLV_DATA_WIDTH/8)];
      assign offset_d = addr_d[$clog2(SLV_DATA_WIDTH/8)-1:$clog2(MAS_DATA_WIDTH/8)];

      //* ports handshake
      assign master_write_hs = master_port.req & master_port.gnt & master_port.wen;
      assign slave_write_hs = slave_port.req & slave_port.gnt & slave_port.wen;
      assign master_read_hs = master_port.req & master_port.gnt & ~master_port.wen;
      assign slave_read_hs = slave_port.req & slave_port.gnt & ~slave_port.wen;

      //* latch write address, drive wvalid_q
      assign all_w_valid = &w_valid_q;
      assign any_w_valid = |w_valid_q;
      always_ff @(posedge clk_i, negedge resetn_i) begin
        if (~resetn_i) begin
          wr_addr_q <= '0;
          w_valid_q <= '0;
        end else begin
          case ({
            master_write_hs, slave_write_hs
          })
            2'b11: begin  //* back to back write
              for (int i = 0; i < NB_BLK; i++) begin
                if (i == offset_d) begin
                  wr_addr_q[i] <= addr_d;
                  w_valid_q[i] <= 1'b1;
                end else begin
                  wr_addr_q[i] <= '0;
                  w_valid_q[i] <= '0;
                end
              end
            end

            2'b10: begin
              wr_addr_q[offset_d] <= addr_d;
              w_valid_q[offset_d] <= 1'b1;
            end

            2'b01: begin
              wr_addr_q <= '0;
              w_valid_q <= '0;
            end

            2'b00: begin
            end

            default: begin
              wr_addr_q <= 'x;
              w_valid_q <= 'x;
            end
          endcase
        end
      end

      for (genvar i = 0; i < NB_BLK; i++) begin : blk
        assign wr_depth_q[i]  = wr_addr_q[i][ADDR_WIDTH-1:$clog2(SLV_DATA_WIDTH/8)];
        assign wr_offset_q[i] = wr_addr_q[i][$clog2(SLV_DATA_WIDTH/8)-1:$clog2(MAS_DATA_WIDTH/8)];
      end

      //* drive rvalid_q, read_match flag
      always_ff @(posedge clk_i, negedge resetn_i) begin
        if (~resetn_i) begin
          r_valid_q <= '0;
        end else begin
          if (slave_port.r_valid) begin
            r_valid_q <= '1;
          end else if (slave_write_hs & (slave_port.addr == r_addr_q)) begin
            r_valid_q <= '0;
          end
        end
      end

      assign slave_port.r_ready = 1'b1;
      assign r_depth_addr_q_ = slave_port.addr[ADDR_WIDTH-1:$clog2(SLV_DATA_WIDTH/8)];
      assign r_depth_addr_q = r_addr_q[ADDR_WIDTH-1:$clog2(SLV_DATA_WIDTH/8)];
      assign r_depth_addr_match_d = (r_depth_addr_q_ == depth_d);
      assign r_depth_addr_match = (r_depth_addr_q == depth_d);
      always_ff @(posedge clk_i, negedge resetn_i) begin
        if (~resetn_i) begin
          r_addr_q_ <= '0;
          r_addr_q  <= '0;
        end else begin
          if (slave_read_hs) begin
            r_addr_q_ <= slave_port.addr;
          end
          if (slave_port.r_valid) begin
            r_addr_q <= r_addr_q_;
          end
        end
      end

      //*******************************************************
      //* master port
      //*******************************************************
      //* gnt generation
      always_comb begin
        master_port.gnt = 1'b0;
        casez ({
          master_port.req, master_port.wen
        })
          2'b0?: begin
            master_port.gnt = 1'b0;
          end

          2'b10: begin  // read request
            if (r_depth_addr_match & r_valid_q) begin
              master_port.gnt = 1'b1;  // 1 cycle delay needed to r_valid and r_data
            end
          end

          2'b11: begin  // write request
            if (~w_valid_q[offset_d] | (slave_write_hs)) begin  // not yet reg valid or wvalid will be deasserted
              master_port.gnt = 1'b1;
            end
          end

          default: begin
            master_port.gnt = 'x;
          end
        endcase
      end

      //* read channel generation
      always_ff @(posedge clk_i, negedge resetn_i) begin
        if (~resetn_i) begin
          master_port.r_valid <= '0;
          master_port.r_data  <= '0;
        end else begin
          if (master_read_hs) begin
            master_port.r_valid <= 1'b1;
            master_port.r_data  <= data_reg[offset_d];
          end else begin
            master_port.r_valid <= '0;
            master_port.r_data  <= '0;
          end
        end
      end

      //*******************************************************
      //* slave port
      //*******************************************************
      //* req, addr, wen, data
      assign slave_port.be   = '1;
      assign slave_port.wen  = all_w_valid;
      assign slave_port.addr = (slave_port.wen) ? wr_addr_q[0] : master_port.addr;
      assign slave_port.data = (slave_port.wen) ? data_reg : '0;
      always_comb begin
        slave_port.req = 1'b0;
        case (any_w_valid)
          1'b0: begin  // read phase or idle
            if (master_port.req & ~master_port.wen & (~r_depth_addr_match | ~r_valid_q) & (~slave_port.r_valid | ~r_depth_addr_match_d)) begin
              slave_port.req = 1'b1;
            end
          end

          1'b1: begin  // write phase
            slave_port.req = all_w_valid;
          end

          default: begin
            slave_port.req = 'x;
          end
        endcase
      end

      //* data reg
      always_ff @(posedge clk_i, negedge resetn_i) begin
        if (~resetn_i) begin
          data_reg <= '0;
        end else begin
          if (master_write_hs) begin
            data_reg[offset_d] <= master_port.data;
          end else if (slave_port.r_valid) begin
            data_reg <= slave_port.r_data;
          end
        end
      end
    end
  endgenerate

  //--------------------------------------------------------------------------
  //- verification
  //--------------------------------------------------------------------------
`ifdef FUNCTIONAL
  always_comb begin
    int depth_addr;
    wr_err = 1'b0;
    if (all_w_valid) begin
      depth_addr = wr_depth_q[0];
      for (int i = 1; i < NB_BLK; i++) begin
        if (depth_addr != wr_depth_q[i]) begin
          wr_err = 1'b1;
        end
      end
    end
  end
`endif
endmodule
