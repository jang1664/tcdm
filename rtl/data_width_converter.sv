module data_width_converter #(
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

  logic [ADDR_WIDTH-1:0] slv_addr;

  logic master_write_hs;
  logic slave_write_hs;
  logic master_read_hs;
  logic slave_read_hs;

  // read data cacheing
  logic [NB_BLK-1:0][MAS_DATA_WIDTH-1:0] rd_data_cache;
  logic rd_data_cache_valid;

  logic [ADDR_WIDTH-1:0] slv_rd_addr_cached;
  logic [ADDR_WIDTH-1:0] slv_rd_addr_offset_cached;
  logic [ADDR_WIDTH-1:0] slv_rd_addr_last_requested;
  logic [ADDR_WIDTH-1:0] mas_rd_addr_last_requested;

  logic slv_rd_addr_cached_valid;
  logic slv_rd_addr_last_requested_valid;

  logic first_rd_req_issued;
  logic is_rd_req_cached;
  logic is_waiting_rd_resp;
  logic is_waiting_resp_matched_rd_req;

  logic rd_req_addr_matched_with_last_req;
  logic rd_req_addr_matched_with_cached_req;

  // logic [ADDR_WIDTH-1:0] r_depth_addr_q;
  // logic [ADDR_WIDTH-1:0] r_depth_addr_q_;
  // logic r_depth_addr_match;  // whether master req address is matched with reg read depth address

  logic is_master_waiting_rd_resp;

  //------------------------------------------------------------------
  //- implementation
  //------------------------------------------------------------------
`define MAS_TO_SLV_ADDR(addr) ({addr[ADDR_WIDTH-1:$clog2(SLV_DATA_WIDTH/8)], {($clog2(SLV_DATA_WIDTH/8)){1'b0}}})
`define MAS_ADDR_TO_OFFSET(addr) (addr[$clog2(SLV_DATA_WIDTH/8)-1:$clog2(MAS_DATA_WIDTH/8)]) 

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
      assign slv_addr = `MAS_TO_SLV_ADDR(master_port.addr);

      assign rd_req_addr_matched_with_last_req = (slv_rd_addr_last_requested == slv_addr);
      assign rd_req_addr_matched_with_cached_req = (slv_rd_addr_cached == slv_addr);

      //* ports handshake
      assign master_write_hs = master_port.req & master_port.gnt & master_port.wen;
      assign slave_write_hs = slave_port.req & slave_port.gnt & slave_port.wen;
      assign master_read_hs = master_port.req & master_port.gnt & ~master_port.wen;
      assign slave_read_hs = slave_port.req & slave_port.gnt & ~slave_port.wen;

      always_ff @(posedge clk_i, negedge resetn_i) begin
        if(~resetn_i) begin
          first_rd_req_issued <= '0;
        end else begin
          if(master_port.req & master_port.gnt & ~master_port.wen) begin
            first_rd_req_issued <= 1'b1;
          end
        end
      end

      always_ff @(posedge clk_i, negedge resetn_i) begin
        if(~resetn_i) begin
          is_waiting_rd_resp <= '0;
        end else begin
          if(slave_read_hs) begin
            is_waiting_rd_resp <= 1'b1;
          end else if(slave_port.r_valid & slave_port.r_ready) begin
            is_waiting_rd_resp <= 1'b0;
          end
        end
      end

      assign is_waiting_resp_matched_rd_req = (is_waiting_rd_resp & rd_req_addr_matched_with_last_req);

      assign is_rd_req_cached = (slv_addr == slv_rd_addr_last_requested) & first_rd_req_issued;

      always_ff @(posedge clk_i, negedge resetn_i) begin
        if (~resetn_i) begin
          rd_data_cache_valid <= '0;
        end else begin
          if (slave_port.r_valid & slave_port.r_ready) begin
            rd_data_cache_valid <= '1;
          end else if (slave_write_hs & (slave_port.addr == slv_rd_addr_cached)) begin
            rd_data_cache_valid <= '0;
          end else if (slave_read_hs & (slave_port.addr != slv_rd_addr_cached)) begin
            rd_data_cache_valid <= '0;
          end
        end
      end

      always_ff @(posedge clk_i, negedge resetn_i) begin
        if (~resetn_i) begin
          slv_rd_addr_last_requested <= '0;
          mas_rd_addr_last_requested <= '0;
          slv_rd_addr_cached  <= '0;
          // slv_rd_addr_offset_cached <= '0;
        end else begin
          if (slave_read_hs) begin
            slv_rd_addr_last_requested <= slave_port.addr;
          end
          if (master_read_hs) begin
            mas_rd_addr_last_requested <= master_port.addr;
          end
          if (slave_port.r_valid) begin
            slv_rd_addr_cached <= slv_rd_addr_last_requested;
            // slv_rd_addr_offset_cached <= `MAS_ADDR_TO_OFFSET(mas_rd_addr_last_requested);
          end
        end
      end

      // always_ff @(posedge clk_i, negedge resetn_i) begin
      //   if(~resetn_i) begin
      //     slv_rd_addr_cached_valid <= '0;
      //     slv_rd_addr_last_requested_valid <= '0;
      //   end else begin
      //     if(slave_read_hs) begin
      //       slv_rd_addr_last_requested_valid <= 1'b1;
      //     end else if(slave_port.r_valid & slave_port.r_ready) begin
      //       slv_rd_addr_last_requested_valid <= 1'b0;
      //     end

      //     if(slave_port.r_valid) begin
      //       slv_rd_addr_cached_valid <= 1'b1;
      //     end else if(slave_write_hs) begin
      //       slv_rd_addr_cached_valid <= 1'b0;
      //     end
      //   end
      // end

      //* data reg
      always_ff @(posedge clk_i, negedge resetn_i) begin
        if (~resetn_i) begin
          rd_data_cache <= '0;
        end else begin
          if (slave_port.r_valid & slave_port.r_ready) begin
            rd_data_cache <= slave_port.r_data;
          end
        end
      end

      always_ff @(posedge clk_i, negedge resetn_i) begin
        if (~resetn_i) begin
          is_master_waiting_rd_resp <= '0;
        end else begin
          if (master_read_hs) begin
            is_master_waiting_rd_resp <= 1'b1;
          end else if(master_port.r_valid & master_port.r_ready) begin
            is_master_waiting_rd_resp <= '0;
          end
        end
      end
      // ******************************
      // slave port
      // ******************************
      always_comb begin
        slave_port.be = '0;
        slave_port.be[offset_d*(MAS_DATA_WIDTH/8) +: MAS_DATA_WIDTH/8] = master_port.be;
        for(int i=0; i<NB_BLK; i++) begin
          slave_port.data[MAS_DATA_WIDTH*i +: MAS_DATA_WIDTH] = master_port.data;
        end
      end

      assign slave_port.wen  = master_port.wen;
      assign slave_port.addr = slv_addr;

      assign slave_port.req = (master_port.req & master_port.wen) | 
                              (master_port.req & ~master_port.wen & (~is_rd_req_cached | ~rd_data_cache_valid));

      assign slave_port.r_ready = ~rd_data_cache_valid;

      //*******************************************************
      // master port
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
            if (
                 (rd_req_addr_matched_with_last_req & (rd_data_cache_valid | is_waiting_rd_resp)) | // read request matched with cached data
                 slave_port.gnt
               ) begin
              // master_port.gnt = 1'b1;
              master_port.gnt = ~master_port.r_valid | (master_port.r_valid & master_port.r_ready);
            end
          end

          2'b11: begin  // write request
            master_port.gnt = slave_port.gnt;
          end

          default: begin
            master_port.gnt = 'x;
          end
        endcase
      end

      //* read channel generation
      assign master_port.r_data = (rd_data_cache_valid) ? rd_data_cache[`MAS_ADDR_TO_OFFSET(mas_rd_addr_last_requested)] : slave_port.r_data[`MAS_ADDR_TO_OFFSET(mas_rd_addr_last_requested)*MAS_DATA_WIDTH +: MAS_DATA_WIDTH];
      assign master_port.r_valid = (rd_data_cache_valid & is_master_waiting_rd_resp) | slave_port.r_valid;
    end
  endgenerate

  //--------------------------------------------------------------------------
  //- verification
  //--------------------------------------------------------------------------
`ifdef FUNCTIONAL
  int fd;
  initial begin
    fd = $fopen($sformatf("./logs/%m.log"), "w");
  end

  initial begin : track_master_port
    fork
      while(1) begin
        @(negedge clk_i);
        if(master_port.req & master_port.gnt & master_port.wen) begin
          $fwrite(fd, "[%8t] Master write REQ | addr=%h | be=%h | data=%h\n", $time, master_port.addr, master_port.be, master_port.data);
        end
      end

      while(1) begin
        @(negedge clk_i);
        if(master_port.req & master_port.gnt & ~master_port.wen) begin
          $fwrite(fd, "[%8t] Master read REQ | addr=%h\n", $time, master_port.addr);
        end
      end

      while(1) begin
        @(negedge clk_i);
        if(master_port.r_valid & master_port.r_ready) begin
          $fwrite(fd, "[%8t] Master read RESP | data=%h\n", $time, master_port.r_data);
        end
      end
    join_none
  end

  initial begin : track_slv_port
    fork
      while(1) begin
        @(negedge clk_i);
        if(slave_port.req & slave_port.gnt & slave_port.wen) begin
          $fwrite(fd, "[%8t] Slave write REQ | addr=%h | be=%h | data=%h\n", $time, slave_port.addr, slave_port.be, slave_port.data);
        end
      end

      while(1) begin
        @(negedge clk_i);
        if(slave_port.req & slave_port.gnt & ~slave_port.wen) begin
          $fwrite(fd, "[%8t] Slave read REQ | addr=%h\n", $time, slave_port.addr);
        end
      end

      while(1) begin
        @(negedge clk_i);
        if(slave_port.r_valid & slave_port.r_ready) begin
          $fwrite(fd, "[%8t] Slave read RESP | data=%h\n", $time, slave_port.r_data);
        end
      end
    join_none
  end
`endif
endmodule
