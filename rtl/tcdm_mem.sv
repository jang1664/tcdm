module tcdm_mem 
  import sram_type_pkg::*;
#(
`ifdef FUNCTIONAL
    parameter string NAME = "tcdm_mem",
    parameter string DATA_FORMAT = "int",
`endif
    parameter BANK_WIDTH = 256,  // Total width of the combined bank
    parameter BANK_DEPTH = 256,  // Total depth of the combined bank
    parameter tech_e TECH = TECH_FDSOI,
    parameter type1_e TYPE1 = TYPE1_RA,
    parameter type2_e TYPE2 = TYPE2_HD,
    parameter vth_e VTH = VTH_L,
    parameter wmask_e WMASK_EN = WMASK_DISABLE,
    parameter VBANK_NUM = 1,     // Number of banks vertically (depth direction)
    parameter HBANK_NUM = 1,     // Number of banks horizontally (width direction)
    parameter REG_MEM_USE = 1
) (
    input logic clk_i,
    input logic resetn_i,
    mem_intf.slave port
);

  // Calculate individual bank dimensions
  localparam PHYSICAL_BANK_WIDTH = BANK_WIDTH / HBANK_NUM;  // Width of each physical bank
  localparam PHYSICAL_BANK_DEPTH = BANK_DEPTH / VBANK_NUM;  // Depth of each physical bank
  localparam TOTAL_BANK_NUM = VBANK_NUM * HBANK_NUM;        // Total number of physical banks
  
  localparam BANK_SIZE = (BANK_WIDTH * BANK_DEPTH) / 8;
  localparam PHYSICAL_BANK_ADDR_WIDTH = $clog2(PHYSICAL_BANK_DEPTH);
  localparam ADDR_LSB = $clog2(BANK_WIDTH / 8);
  localparam VBANK_ADDR_WIDTH = $clog2(VBANK_NUM);
  localparam HBANK_ADDR_WIDTH = $clog2(HBANK_NUM);

  // ************************************************************
  // * sram bank signals
  // ************************************************************
  logic [PHYSICAL_BANK_ADDR_WIDTH-1:0] sram_addr;
  logic [PHYSICAL_BANK_WIDTH-1:0] sram_wdata [TOTAL_BANK_NUM];
  logic sram_wen;
  logic [TOTAL_BANK_NUM-1:0] sram_csn;
  logic [PHYSICAL_BANK_WIDTH/8-1:0] sram_be [TOTAL_BANK_NUM];
  logic [TOTAL_BANK_NUM-1:0][PHYSICAL_BANK_WIDTH-1:0] sram_rdata;
  logic [BANK_WIDTH-1:0] sram_rdata_bus;

  logic [$clog2(VBANK_NUM)-1:0] rvalid_vbank_idx;
  logic [$clog2(HBANK_NUM)-1:0] rvalid_hbank_idx;

  // ************************************************************
  // * Address decoding and bank selection
  // ************************************************************
  
  // Address breakdown: [vbank_addr][physical_bank_addr][byte_offset]
  logic [$clog2(VBANK_NUM)-1:0] vbank_idx;
  logic [$clog2(HBANK_NUM)-1:0] hbank_idx;

  generate
    if(VBANK_NUM > 1) begin : gen_vbank_more_than_one
      // Vertical bank selection
      assign vbank_idx = port.addr[ADDR_LSB + PHYSICAL_BANK_ADDR_WIDTH + VBANK_ADDR_WIDTH - 1 : ADDR_LSB + PHYSICAL_BANK_ADDR_WIDTH];
    end else begin : gen_vbank_one
      assign vbank_idx = '0; // No vertical banking, use single bank
    end
  endgenerate
  
  // assign vbank_idx = (VBANK_NUM > 1) ? port.addr[ADDR_LSB + PHYSICAL_BANK_ADDR_WIDTH + VBANK_ADDR_WIDTH - 1 : ADDR_LSB + PHYSICAL_BANK_ADDR_WIDTH] : '0;
  assign hbank_idx = '0; // Horizontal banking is handled by data/be mapping
  assign sram_addr = port.addr[ADDR_LSB + PHYSICAL_BANK_ADDR_WIDTH - 1 : ADDR_LSB];
  
  assign port.r_data = sram_rdata_bus;
  assign port.gnt = ~(port.r_valid & ~port.r_ready);
  assign sram_wen = port.wen;

  // Data and byte enable distribution across horizontal banks
  generate
    for (genvar v = 0; v < VBANK_NUM; v++) begin : gen_vbank
      for (genvar h = 0; h < HBANK_NUM; h++) begin : gen_hbank
        localparam bank_idx = v * HBANK_NUM + h;
        
        // Data mapping: each horizontal bank gets a portion of the data width
        assign sram_wdata[bank_idx] = port.data[(h+1)*PHYSICAL_BANK_WIDTH-1 : h*PHYSICAL_BANK_WIDTH];
        assign sram_be[bank_idx] = port.be[(h+1)*(PHYSICAL_BANK_WIDTH/8)-1 : h*(PHYSICAL_BANK_WIDTH/8)];
      end
    end
  endgenerate

  // Reconstruct read data from horizontal banks
  always_comb begin
    sram_rdata_bus = '0;
    for (int h = 0; h < HBANK_NUM; h++) begin
      automatic int bank_idx = rvalid_vbank_idx * HBANK_NUM + h;
      sram_rdata_bus[h*PHYSICAL_BANK_WIDTH +: PHYSICAL_BANK_WIDTH] = sram_rdata[bank_idx];
    end
  end

  // Bank selection - only the selected vertical bank row is enabled
  always_comb begin
    sram_csn = '1;
    if (port.req & port.gnt) begin
      // Enable all horizontal banks in the selected vertical bank row
      for (int h = 0; h < HBANK_NUM; h++) begin
        automatic int bank_idx = vbank_idx * HBANK_NUM + h;
        sram_csn[bank_idx] = 1'b0;
      end
    end
  end

  always_ff @(posedge clk_i, negedge resetn_i) begin
    if (~resetn_i) begin
      port.r_valid <= 1'b0;
      rvalid_vbank_idx <= '0;
      rvalid_hbank_idx <= '0;
    end else begin
      if (port.req & port.gnt & ~port.wen) begin
        rvalid_vbank_idx <= vbank_idx;
        rvalid_hbank_idx <= hbank_idx;
        port.r_valid <= 1'b1;
      end else if(port.r_valid & port.r_ready) begin
        rvalid_vbank_idx <= '0;
        rvalid_hbank_idx <= '0;
        port.r_valid <= 1'b0;
      end
    end
  end

  generate
    for (genvar v = 0; v < VBANK_NUM; v++) begin : gen_vbank_inst
      for (genvar h = 0; h < HBANK_NUM; h++) begin : gen_hbank_inst
        localparam bank_idx = v * HBANK_NUM + h;
        
        sram_bank #(
            .DATA_WIDTH(PHYSICAL_BANK_WIDTH),
            .DEPTH(PHYSICAL_BANK_DEPTH),
            .TECH(TECH),
            .TYPE1(TYPE1),
            .TYPE2(TYPE2),
            .VTH(VTH),
            .WMASK_EN(WMASK_EN),
            .REG_MEM_USE(REG_MEM_USE)
        ) u_sram_bank (
            .clk_i(clk_i),
            .csn_i(sram_csn[bank_idx]),
            .be_i(sram_be[bank_idx]),
            .we_i(sram_wen),
            .addr_i(sram_addr),
            .wdata_i(sram_wdata[bank_idx]),
            .rdata_o(sram_rdata[bank_idx])
        );
      end
    end
  endgenerate
`ifdef FUNCTIONAL
  int fd;
  initial begin
    fd = $fopen($sformatf("./logs/%m.log"), "w");
  end

  always_ff @(posedge clk_i) begin
    if(port.req & port.gnt & port.wen) begin
      $fwrite(fd, "[%0t] | write | addr: 0x%0h | data: 0x%0h | be:0x%0h\n", $time, port.addr, port.data, port.be);
    end

    if(port.req & port.gnt & ~port.wen) begin
      $fwrite(fd, "[%0t] | read  | addr: 0x%0h\n", $time, port.addr);
    end

    if(port.r_valid & port.r_ready) begin
      $fwrite(fd, "[%0t] | resp | data: 0x%0h\n", $time, port.r_data);
    end
  end

  typedef struct packed {
    logic [BANK_WIDTH-1:0] data;
    logic [PHYSICAL_BANK_ADDR_WIDTH-1:0] addr;
    logic [BANK_WIDTH/8-1:0] be;
  } wr_info_t;

  typedef struct packed {
    logic [BANK_WIDTH-1:0] data;
    logic [PHYSICAL_BANK_ADDR_WIDTH-1:0] addr;
  } rd_info_t;

  wr_info_t wr_stack[$];
  rd_info_t rd_stack[$];
  wr_info_t wr_info;
  rd_info_t rd_info;

  always_ff @(posedge clk_i) begin
    if(port.req & port.gnt & port.wen) begin
      wr_info.data = port.data;
      wr_info.addr = port.addr[ADDR_LSB+PHYSICAL_BANK_ADDR_WIDTH-1:ADDR_LSB];
      wr_info.be = port.be;
      wr_stack.push_back(wr_info);
    end

    if(port.req & port.gnt & ~port.wen) begin
      rd_info.data = '0; // Data is not known at this point
      rd_info.addr = port.addr[ADDR_LSB+PHYSICAL_BANK_ADDR_WIDTH-1:ADDR_LSB];
      rd_stack.push_back(rd_info);
    end
    if(port.r_valid & port.r_ready) begin
      if(rd_stack.size() > 0) begin
        rd_stack[rd_stack.size()-1].data = port.r_data;
      end
    end
  end

  function wr_info_t get_wr_info(int idx);
    if(idx < wr_stack.size()) begin
      return wr_stack[idx];
    end else begin
      $fatal("Index out of bounds for write stack: %0d", idx);
    end
  endfunction

  function rd_info_t get_rd_info(int idx);
    if(idx < rd_stack.size()) begin
      return rd_stack[idx];
    end else begin
      $fatal("Index out of bounds for read stack: %0d", idx);
    end
  endfunction
`endif
endmodule

