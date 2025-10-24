// WMASK enabled SRAM instances
`define FDSOI_SRAM_WMASK_INST(type1, type2, vth, depth, width, mux) \
  ln28fds_mc_``type1``1w_``type2``_``vth``vt_``depth``x``width``m``mux``b1c1 u_mem ( \
    .CK(clk_i),         \
    .A(addr_i),         \
    .DI(wdata_i),       \
    .CSN(csn_i),        \
    .WEN(~we_i),        \
    .BWEN(bwe),         \
    .RET(1'b0),         \
    .MCS(2'b01),        \
    .DFTRAM(1'b0),      \
    .SE(1'b0),          \
    .ADME(2'b00),       \
    .DOUT(rdata_o),     \
    .SI_D_L(),          \
    .SI_D_R(),          \
    .SO_D_L(),          \
    .SO_D_R()           \
  );

// No WMASK SRAM instances
`define FDSOI_SRAM_NO_WMASK_INST(type1, type2, vth, depth, width, mux) \
  ln28fds_mc_``type1``1_``type2``_``vth``vt_``depth``x``width``m``mux``b1c1 u_mem ( \
    .CK(clk_i),         \
    .A(addr_i),         \
    .DI(wdata_i),       \
    .CSN(csn_i),        \
    .WEN(~we_i),        \
    .RET(1'b0),         \
    .MCS(2'b01),        \
    .DFTRAM(1'b0),      \
    .SE(1'b0),          \
    .ADME(2'b00),       \
    .DOUT(rdata_o),     \
    .SI_D_L(),          \
    .SI_D_R(),          \
    .SO_D_L(),          \
    .SO_D_R()           \
  );

// Function to calculate MUX_NUM based on DEPTH and DATA_WIDTH
function automatic int calc_mux_num(int depth, int width);
  if (width >= 4 && width <= 256 && depth >= 32 && depth <= 2048) begin
    return 4;
  end
  else if (width >= 4 && width <= 128 && depth >= 64 && depth <= 4096) begin
    return 8;
  end
  else if (width >= 4 && width <= 64 && depth >= 128 && depth <= 8192) begin
    return 16;
  end
  else if (width >= 4 && width <= 32 && depth >= 256 && depth <= 16384) begin
    return 32;
  end
  else begin
    return -1; // Invalid configuration
  end
endfunction

module sram_bank 
  import sram_type_pkg::*;
#(
    parameter  DATA_WIDTH=32,
    parameter  DEPTH=32,
    parameter  REG_MEM_USE = 1,
    parameter  tech_e TECH = TECH_FDSOI,
    parameter  type1_e TYPE1 = TYPE1_RA,
    parameter  type2_e TYPE2 = TYPE2_HD,
    parameter  vth_e VTH = VTH_L,
    parameter  wmask_e WMASK_EN = WMASK_DISABLE,
    localparam BANK_SIZE   = (DATA_WIDTH * DEPTH) / 8,
    localparam ADDR_WIDTH  = $clog2(DEPTH)
) (
    input logic clk_i,
    input logic csn_i,
    input logic we_i,
    input logic [ADDR_WIDTH-1:0] addr_i,
    input logic [DATA_WIDTH/8-1:0] be_i,
    input logic [DATA_WIDTH-1:0] wdata_i,
    output logic [DATA_WIDTH-1:0] rdata_o
);

  generate
    if (REG_MEM_USE) begin : reg_mem
      logic [DEPTH-1:0][DATA_WIDTH-1:0] mem;
      always_ff @(posedge clk_i) begin
        if (csn_i & we_i) begin
          for(int i=0; i<DATA_WIDTH/8; i++) begin
            if (be_i[i]) begin
              mem[addr_i][8*i +: 8] <= wdata_i[8*i +: 8];
            end
          end
          // mem[addr_i] <= wdata_i;
        end
      end
      always_ff @(posedge clk_i) begin
        if (csn_i & ~we_i) begin
          rdata_o <= mem[addr_i];
        end
      end
    end else begin : compile_mem
      logic [DATA_WIDTH-1:0] bwe;
      always_comb begin
        for(int i=0; i<DATA_WIDTH/8; i++) begin
          bwe[i*8 +: 8] = {8{~be_i[i]}};
        end
      end

      if(TECH == TECH_FDSOI) begin
        localparam MUX_NUM = calc_mux_num(DEPTH, DATA_WIDTH);
        
        if (MUX_NUM == -1) begin
          $error("Unsupported DATA_WIDTH or DEPTH: %0d, %0d", DATA_WIDTH, DEPTH);
        end

        // Nested case for type and size combinations
        case({TYPE1, TYPE2, VTH})
          {TYPE1_RA, TYPE2_HD, VTH_L}: begin
            case({DEPTH, DATA_WIDTH, MUX_NUM})
              {32, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 32, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 32, 4, 4)
              end
              {32, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 32, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 32, 8, 4)
              end
              {32, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 32, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 32, 16, 4)
              end
              {32, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 32, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 32, 32, 4)
              end
              {32, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 32, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 32, 64, 4)
              end
              {32, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 32, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 32, 128, 4)
              end
              {32, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 32, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 32, 256, 4)
              end
              {64, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 64, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 64, 4, 4)
              end
              {64, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 64, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 64, 8, 4)
              end
              {64, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 64, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 64, 16, 4)
              end
              {64, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 64, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 64, 32, 4)
              end
              {64, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 64, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 64, 64, 4)
              end
              {64, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 64, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 64, 128, 4)
              end
              {64, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 64, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 64, 256, 4)
              end
              {128, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 128, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 128, 4, 4)
              end
              {128, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 128, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 128, 8, 4)
              end
              {128, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 128, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 128, 16, 4)
              end
              {128, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 128, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 128, 32, 4)
              end
              {128, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 128, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 128, 64, 4)
              end
              {128, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 128, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 128, 128, 4)
              end
              {128, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 128, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 128, 256, 4)
              end
              {256, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 256, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 256, 4, 4)
              end
              {256, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 256, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 256, 8, 4)
              end
              {256, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 256, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 256, 16, 4)
              end
              {256, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 256, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 256, 32, 4)
              end
              {256, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 256, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 256, 64, 4)
              end
              {256, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 256, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 256, 128, 4)
              end
              {256, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 256, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 256, 256, 4)
              end
              {512, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 512, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 512, 4, 4)
              end
              {512, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 512, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 512, 8, 4)
              end
              {512, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 512, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 512, 16, 4)
              end
              {512, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 512, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 512, 32, 4)
              end
              {512, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 512, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 512, 64, 4)
              end
              {512, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 512, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 512, 128, 4)
              end
              {512, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 512, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 512, 256, 4)
              end
              {1024, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 1024, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 1024, 4, 4)
              end
              {1024, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 1024, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 1024, 8, 4)
              end
              {1024, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 1024, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 1024, 16, 4)
              end
              {1024, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 1024, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 1024, 32, 4)
              end
              {1024, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 1024, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 1024, 64, 4)
              end
              {1024, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 1024, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 1024, 128, 4)
              end
              {1024, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 1024, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 1024, 256, 4)
              end
              {2048, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 2048, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 2048, 4, 4)
              end
              {2048, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 2048, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 2048, 8, 4)
              end
              {2048, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 2048, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 2048, 16, 4)
              end
              {2048, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 2048, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 2048, 32, 4)
              end
              {2048, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 2048, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 2048, 64, 4)
              end
              {2048, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 2048, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 2048, 128, 4)
              end
              {2048, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 2048, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 2048, 256, 4)
              end
              {4096, 4, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 4096, 4, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 4096, 4, 8)
              end
              {4096, 8, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 4096, 8, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 4096, 8, 8)
              end
              {4096, 16, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 4096, 16, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 4096, 16, 8)
              end
              {4096, 32, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 4096, 32, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 4096, 32, 8)
              end
              {4096, 64, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 4096, 64, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 4096, 64, 8)
              end
              {4096, 128, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 4096, 128, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 4096, 128, 8)
              end
              {8192, 4, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 8192, 4, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 8192, 4, 16)
              end
              {8192, 8, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 8192, 8, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 8192, 8, 16)
              end
              {8192, 16, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 8192, 16, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 8192, 16, 16)
              end
              {8192, 32, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 8192, 32, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 8192, 32, 16)
              end
              {8192, 64, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 8192, 64, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 8192, 64, 16)
              end
              {16384, 4, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 16384, 4, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 16384, 4, 32)
              end
              {16384, 8, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 16384, 8, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 16384, 8, 32)
              end
              {16384, 16, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 16384, 16, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 16384, 16, 32)
              end
              {16384, 32, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, l, 16384, 32, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, l, 16384, 32, 32)
              end
              default: $error("Unsupported DEPTH/DATA_WIDTH/MUX_NUM combination: %0d/%0d/%0d", DEPTH, DATA_WIDTH, MUX_NUM);
            endcase
          end
          {TYPE1_RA, TYPE2_HD, VTH_R}: begin
            case({DEPTH, DATA_WIDTH, MUX_NUM})
              {32, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 32, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 32, 4, 4)
              end
              {32, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 32, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 32, 8, 4)
              end
              {32, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 32, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 32, 16, 4)
              end
              {32, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 32, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 32, 32, 4)
              end
              {32, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 32, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 32, 64, 4)
              end
              {32, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 32, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 32, 128, 4)
              end
              {32, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 32, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 32, 256, 4)
              end
              {64, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 64, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 64, 4, 4)
              end
              {64, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 64, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 64, 8, 4)
              end
              {64, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 64, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 64, 16, 4)
              end
              {64, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 64, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 64, 32, 4)
              end
              {64, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 64, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 64, 64, 4)
              end
              {64, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 64, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 64, 128, 4)
              end
              {64, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 64, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 64, 256, 4)
              end
              {128, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 128, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 128, 4, 4)
              end
              {128, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 128, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 128, 8, 4)
              end
              {128, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 128, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 128, 16, 4)
              end
              {128, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 128, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 128, 32, 4)
              end
              {128, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 128, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 128, 64, 4)
              end
              {128, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 128, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 128, 128, 4)
              end
              {128, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 128, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 128, 256, 4)
              end
              {256, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 256, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 256, 4, 4)
              end
              {256, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 256, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 256, 8, 4)
              end
              {256, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 256, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 256, 16, 4)
              end
              {256, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 256, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 256, 32, 4)
              end
              {256, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 256, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 256, 64, 4)
              end
              {256, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 256, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 256, 128, 4)
              end
              {256, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 256, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 256, 256, 4)
              end
              {512, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 512, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 512, 4, 4)
              end
              {512, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 512, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 512, 8, 4)
              end
              {512, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 512, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 512, 16, 4)
              end
              {512, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 512, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 512, 32, 4)
              end
              {512, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 512, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 512, 64, 4)
              end
              {512, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 512, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 512, 128, 4)
              end
              {512, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 512, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 512, 256, 4)
              end
              {1024, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 1024, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 1024, 4, 4)
              end
              {1024, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 1024, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 1024, 8, 4)
              end
              {1024, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 1024, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 1024, 16, 4)
              end
              {1024, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 1024, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 1024, 32, 4)
              end
              {1024, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 1024, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 1024, 64, 4)
              end
              {1024, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 1024, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 1024, 128, 4)
              end
              {1024, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 1024, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 1024, 256, 4)
              end
              {2048, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 2048, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 2048, 4, 4)
              end
              {2048, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 2048, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 2048, 8, 4)
              end
              {2048, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 2048, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 2048, 16, 4)
              end
              {2048, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 2048, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 2048, 32, 4)
              end
              {2048, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 2048, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 2048, 64, 4)
              end
              {2048, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 2048, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 2048, 128, 4)
              end
              {2048, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 2048, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 2048, 256, 4)
              end
              {4096, 4, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 4096, 4, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 4096, 4, 8)
              end
              {4096, 8, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 4096, 8, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 4096, 8, 8)
              end
              {4096, 16, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 4096, 16, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 4096, 16, 8)
              end
              {4096, 32, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 4096, 32, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 4096, 32, 8)
              end
              {4096, 64, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 4096, 64, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 4096, 64, 8)
              end
              {4096, 128, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 4096, 128, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 4096, 128, 8)
              end
              {8192, 4, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 8192, 4, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 8192, 4, 16)
              end
              {8192, 8, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 8192, 8, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 8192, 8, 16)
              end
              {8192, 16, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 8192, 16, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 8192, 16, 16)
              end
              {8192, 32, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 8192, 32, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 8192, 32, 16)
              end
              {8192, 64, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 8192, 64, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 8192, 64, 16)
              end
              {16384, 4, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 16384, 4, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 16384, 4, 32)
              end
              {16384, 8, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 16384, 8, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 16384, 8, 32)
              end
              {16384, 16, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 16384, 16, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 16384, 16, 32)
              end
              {16384, 32, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hdr, r, 16384, 32, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hdr, r, 16384, 32, 32)
              end
              default: $error("Unsupported DEPTH/DATA_WIDTH/MUX_NUM combination: %0d/%0d/%0d", DEPTH, DATA_WIDTH, MUX_NUM);
            endcase
          end
          {TYPE1_RA, TYPE2_HS, VTH_L}: begin
            case({DEPTH, DATA_WIDTH, MUX_NUM})
              {32, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 32, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 32, 4, 4)
              end
              {32, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 32, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 32, 8, 4)
              end
              {32, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 32, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 32, 16, 4)
              end
              {32, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 32, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 32, 32, 4)
              end
              {32, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 32, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 32, 64, 4)
              end
              {32, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 32, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 32, 128, 4)
              end
              {32, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 32, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 32, 256, 4)
              end
              {64, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 64, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 64, 4, 4)
              end
              {64, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 64, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 64, 8, 4)
              end
              {64, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 64, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 64, 16, 4)
              end
              {64, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 64, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 64, 32, 4)
              end
              {64, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 64, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 64, 64, 4)
              end
              {64, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 64, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 64, 128, 4)
              end
              {64, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 64, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 64, 256, 4)
              end
              {128, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 128, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 128, 4, 4)
              end
              {128, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 128, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 128, 8, 4)
              end
              {128, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 128, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 128, 16, 4)
              end
              {128, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 128, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 128, 32, 4)
              end
              {128, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 128, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 128, 64, 4)
              end
              {128, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 128, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 128, 128, 4)
              end
              {128, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 128, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 128, 256, 4)
              end
              {256, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 256, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 256, 4, 4)
              end
              {256, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 256, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 256, 8, 4)
              end
              {256, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 256, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 256, 16, 4)
              end
              {256, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 256, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 256, 32, 4)
              end
              {256, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 256, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 256, 64, 4)
              end
              {256, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 256, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 256, 128, 4)
              end
              {256, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 256, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 256, 256, 4)
              end
              {512, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 512, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 512, 4, 4)
              end
              {512, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 512, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 512, 8, 4)
              end
              {512, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 512, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 512, 16, 4)
              end
              {512, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 512, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 512, 32, 4)
              end
              {512, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 512, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 512, 64, 4)
              end
              {512, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 512, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 512, 128, 4)
              end
              {512, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 512, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 512, 256, 4)
              end
              {1024, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 1024, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 1024, 4, 4)
              end
              {1024, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 1024, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 1024, 8, 4)
              end
              {1024, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 1024, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 1024, 16, 4)
              end
              {1024, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 1024, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 1024, 32, 4)
              end
              {1024, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 1024, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 1024, 64, 4)
              end
              {1024, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 1024, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 1024, 128, 4)
              end
              {1024, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 1024, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 1024, 256, 4)
              end
              {2048, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 2048, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 2048, 4, 4)
              end
              {2048, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 2048, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 2048, 8, 4)
              end
              {2048, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 2048, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 2048, 16, 4)
              end
              {2048, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 2048, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 2048, 32, 4)
              end
              {2048, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 2048, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 2048, 64, 4)
              end
              {2048, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 2048, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 2048, 128, 4)
              end
              {2048, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 2048, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 2048, 256, 4)
              end
              {4096, 4, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 4096, 4, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 4096, 4, 8)
              end
              {4096, 8, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 4096, 8, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 4096, 8, 8)
              end
              {4096, 16, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 4096, 16, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 4096, 16, 8)
              end
              {4096, 32, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 4096, 32, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 4096, 32, 8)
              end
              {4096, 64, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 4096, 64, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 4096, 64, 8)
              end
              {4096, 128, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 4096, 128, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 4096, 128, 8)
              end
              {8192, 4, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 8192, 4, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 8192, 4, 16)
              end
              {8192, 8, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 8192, 8, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 8192, 8, 16)
              end
              {8192, 16, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 8192, 16, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 8192, 16, 16)
              end
              {8192, 32, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 8192, 32, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 8192, 32, 16)
              end
              {8192, 64, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 8192, 64, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 8192, 64, 16)
              end
              {16384, 4, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 16384, 4, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 16384, 4, 32)
              end
              {16384, 8, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 16384, 8, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 16384, 8, 32)
              end
              {16384, 16, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 16384, 16, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 16384, 16, 32)
              end
              {16384, 32, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, l, 16384, 32, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, l, 16384, 32, 32)
              end
              default: $error("Unsupported DEPTH/DATA_WIDTH/MUX_NUM combination: %0d/%0d/%0d", DEPTH, DATA_WIDTH, MUX_NUM);
            endcase
          end
          {TYPE1_RA, TYPE2_HS, VTH_R}: begin
            case({DEPTH, DATA_WIDTH, MUX_NUM})
              {32, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 32, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 32, 4, 4)
              end
              {32, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 32, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 32, 8, 4)
              end
              {32, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 32, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 32, 16, 4)
              end
              {32, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 32, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 32, 32, 4)
              end
              {32, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 32, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 32, 64, 4)
              end
              {32, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 32, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 32, 128, 4)
              end
              {32, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 32, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 32, 256, 4)
              end
              {64, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 64, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 64, 4, 4)
              end
              {64, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 64, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 64, 8, 4)
              end
              {64, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 64, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 64, 16, 4)
              end
              {64, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 64, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 64, 32, 4)
              end
              {64, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 64, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 64, 64, 4)
              end
              {64, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 64, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 64, 128, 4)
              end
              {64, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 64, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 64, 256, 4)
              end
              {128, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 128, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 128, 4, 4)
              end
              {128, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 128, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 128, 8, 4)
              end
              {128, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 128, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 128, 16, 4)
              end
              {128, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 128, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 128, 32, 4)
              end
              {128, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 128, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 128, 64, 4)
              end
              {128, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 128, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 128, 128, 4)
              end
              {128, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 128, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 128, 256, 4)
              end
              {256, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 256, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 256, 4, 4)
              end
              {256, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 256, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 256, 8, 4)
              end
              {256, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 256, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 256, 16, 4)
              end
              {256, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 256, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 256, 32, 4)
              end
              {256, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 256, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 256, 64, 4)
              end
              {256, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 256, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 256, 128, 4)
              end
              {256, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 256, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 256, 256, 4)
              end
              {512, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 512, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 512, 4, 4)
              end
              {512, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 512, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 512, 8, 4)
              end
              {512, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 512, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 512, 16, 4)
              end
              {512, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 512, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 512, 32, 4)
              end
              {512, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 512, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 512, 64, 4)
              end
              {512, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 512, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 512, 128, 4)
              end
              {512, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 512, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 512, 256, 4)
              end
              {1024, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 1024, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 1024, 4, 4)
              end
              {1024, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 1024, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 1024, 8, 4)
              end
              {1024, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 1024, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 1024, 16, 4)
              end
              {1024, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 1024, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 1024, 32, 4)
              end
              {1024, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 1024, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 1024, 64, 4)
              end
              {1024, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 1024, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 1024, 128, 4)
              end
              {1024, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 1024, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 1024, 256, 4)
              end
              {2048, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 2048, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 2048, 4, 4)
              end
              {2048, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 2048, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 2048, 8, 4)
              end
              {2048, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 2048, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 2048, 16, 4)
              end
              {2048, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 2048, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 2048, 32, 4)
              end
              {2048, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 2048, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 2048, 64, 4)
              end
              {2048, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 2048, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 2048, 128, 4)
              end
              {2048, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 2048, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 2048, 256, 4)
              end
              {4096, 4, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 4096, 4, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 4096, 4, 8)
              end
              {4096, 8, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 4096, 8, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 4096, 8, 8)
              end
              {4096, 16, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 4096, 16, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 4096, 16, 8)
              end
              {4096, 32, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 4096, 32, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 4096, 32, 8)
              end
              {4096, 64, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 4096, 64, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 4096, 64, 8)
              end
              {4096, 128, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 4096, 128, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 4096, 128, 8)
              end
              {8192, 4, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 8192, 4, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 8192, 4, 16)
              end
              {8192, 8, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 8192, 8, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 8192, 8, 16)
              end
              {8192, 16, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 8192, 16, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 8192, 16, 16)
              end
              {8192, 32, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 8192, 32, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 8192, 32, 16)
              end
              {8192, 64, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 8192, 64, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 8192, 64, 16)
              end
              {16384, 4, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 16384, 4, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 16384, 4, 32)
              end
              {16384, 8, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 16384, 8, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 16384, 8, 32)
              end
              {16384, 16, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 16384, 16, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 16384, 16, 32)
              end
              {16384, 32, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(ra, hs, r, 16384, 32, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(ra, hs, r, 16384, 32, 32)
              end
              default: $error("Unsupported DEPTH/DATA_WIDTH/MUX_NUM combination: %0d/%0d/%0d", DEPTH, DATA_WIDTH, MUX_NUM);
            endcase
          end
          {TYPE1_RS, TYPE2_HD, VTH_L}: begin
            case({DEPTH, DATA_WIDTH, MUX_NUM})
              {32, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 32, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 32, 4, 4)
              end
              {32, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 32, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 32, 8, 4)
              end
              {32, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 32, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 32, 16, 4)
              end
              {32, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 32, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 32, 32, 4)
              end
              {32, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 32, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 32, 64, 4)
              end
              {32, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 32, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 32, 128, 4)
              end
              {32, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 32, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 32, 256, 4)
              end
              {64, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 64, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 64, 4, 4)
              end
              {64, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 64, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 64, 8, 4)
              end
              {64, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 64, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 64, 16, 4)
              end
              {64, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 64, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 64, 32, 4)
              end
              {64, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 64, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 64, 64, 4)
              end
              {64, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 64, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 64, 128, 4)
              end
              {64, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 64, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 64, 256, 4)
              end
              {128, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 128, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 128, 4, 4)
              end
              {128, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 128, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 128, 8, 4)
              end
              {128, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 128, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 128, 16, 4)
              end
              {128, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 128, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 128, 32, 4)
              end
              {128, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 128, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 128, 64, 4)
              end
              {128, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 128, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 128, 128, 4)
              end
              {128, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 128, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 128, 256, 4)
              end
              {256, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 256, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 256, 4, 4)
              end
              {256, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 256, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 256, 8, 4)
              end
              {256, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 256, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 256, 16, 4)
              end
              {256, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 256, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 256, 32, 4)
              end
              {256, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 256, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 256, 64, 4)
              end
              {256, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 256, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 256, 128, 4)
              end
              {256, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 256, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 256, 256, 4)
              end
              {512, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 512, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 512, 4, 4)
              end
              {512, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 512, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 512, 8, 4)
              end
              {512, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 512, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 512, 16, 4)
              end
              {512, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 512, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 512, 32, 4)
              end
              {512, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 512, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 512, 64, 4)
              end
              {512, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 512, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 512, 128, 4)
              end
              {512, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 512, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 512, 256, 4)
              end
              {1024, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 1024, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 1024, 4, 4)
              end
              {1024, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 1024, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 1024, 8, 4)
              end
              {1024, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 1024, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 1024, 16, 4)
              end
              {1024, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 1024, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 1024, 32, 4)
              end
              {1024, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 1024, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 1024, 64, 4)
              end
              {1024, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 1024, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 1024, 128, 4)
              end
              {1024, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 1024, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 1024, 256, 4)
              end
              {2048, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 2048, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 2048, 4, 4)
              end
              {2048, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 2048, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 2048, 8, 4)
              end
              {2048, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 2048, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 2048, 16, 4)
              end
              {2048, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 2048, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 2048, 32, 4)
              end
              {2048, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 2048, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 2048, 64, 4)
              end
              {2048, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 2048, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 2048, 128, 4)
              end
              {2048, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 2048, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 2048, 256, 4)
              end
              {4096, 4, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 4096, 4, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 4096, 4, 8)
              end
              {4096, 8, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 4096, 8, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 4096, 8, 8)
              end
              {4096, 16, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 4096, 16, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 4096, 16, 8)
              end
              {4096, 32, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 4096, 32, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 4096, 32, 8)
              end
              {4096, 64, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 4096, 64, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 4096, 64, 8)
              end
              {4096, 128, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 4096, 128, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 4096, 128, 8)
              end
              {8192, 4, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 8192, 4, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 8192, 4, 16)
              end
              {8192, 8, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 8192, 8, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 8192, 8, 16)
              end
              {8192, 16, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 8192, 16, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 8192, 16, 16)
              end
              {8192, 32, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 8192, 32, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 8192, 32, 16)
              end
              {8192, 64, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 8192, 64, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 8192, 64, 16)
              end
              {16384, 4, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 16384, 4, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 16384, 4, 32)
              end
              {16384, 8, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 16384, 8, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 16384, 8, 32)
              end
              {16384, 16, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 16384, 16, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 16384, 16, 32)
              end
              {16384, 32, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, l, 16384, 32, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, l, 16384, 32, 32)
              end
              default: $error("Unsupported DEPTH/DATA_WIDTH/MUX_NUM combination: %0d/%0d/%0d", DEPTH, DATA_WIDTH, MUX_NUM);
            endcase
          end
          {TYPE1_RS, TYPE2_HD, VTH_R}: begin
            case({DEPTH, DATA_WIDTH, MUX_NUM})
              {32, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 32, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 32, 4, 4)
              end
              {32, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 32, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 32, 8, 4)
              end
              {32, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 32, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 32, 16, 4)
              end
              {32, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 32, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 32, 32, 4)
              end
              {32, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 32, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 32, 64, 4)
              end
              {32, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 32, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 32, 128, 4)
              end
              {32, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 32, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 32, 256, 4)
              end
              {64, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 64, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 64, 4, 4)
              end
              {64, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 64, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 64, 8, 4)
              end
              {64, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 64, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 64, 16, 4)
              end
              {64, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 64, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 64, 32, 4)
              end
              {64, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 64, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 64, 64, 4)
              end
              {64, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 64, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 64, 128, 4)
              end
              {64, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 64, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 64, 256, 4)
              end
              {128, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 128, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 128, 4, 4)
              end
              {128, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 128, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 128, 8, 4)
              end
              {128, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 128, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 128, 16, 4)
              end
              {128, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 128, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 128, 32, 4)
              end
              {128, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 128, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 128, 64, 4)
              end
              {128, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 128, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 128, 128, 4)
              end
              {128, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 128, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 128, 256, 4)
              end
              {256, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 256, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 256, 4, 4)
              end
              {256, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 256, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 256, 8, 4)
              end
              {256, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 256, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 256, 16, 4)
              end
              {256, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 256, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 256, 32, 4)
              end
              {256, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 256, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 256, 64, 4)
              end
              {256, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 256, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 256, 128, 4)
              end
              {256, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 256, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 256, 256, 4)
              end
              {512, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 512, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 512, 4, 4)
              end
              {512, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 512, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 512, 8, 4)
              end
              {512, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 512, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 512, 16, 4)
              end
              {512, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 512, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 512, 32, 4)
              end
              {512, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 512, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 512, 64, 4)
              end
              {512, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 512, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 512, 128, 4)
              end
              {512, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 512, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 512, 256, 4)
              end
              {1024, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 1024, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 1024, 4, 4)
              end
              {1024, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 1024, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 1024, 8, 4)
              end
              {1024, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 1024, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 1024, 16, 4)
              end
              {1024, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 1024, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 1024, 32, 4)
              end
              {1024, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 1024, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 1024, 64, 4)
              end
              {1024, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 1024, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 1024, 128, 4)
              end
              {1024, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 1024, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 1024, 256, 4)
              end
              {2048, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 2048, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 2048, 4, 4)
              end
              {2048, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 2048, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 2048, 8, 4)
              end
              {2048, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 2048, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 2048, 16, 4)
              end
              {2048, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 2048, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 2048, 32, 4)
              end
              {2048, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 2048, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 2048, 64, 4)
              end
              {2048, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 2048, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 2048, 128, 4)
              end
              {2048, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 2048, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 2048, 256, 4)
              end
              {4096, 4, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 4096, 4, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 4096, 4, 8)
              end
              {4096, 8, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 4096, 8, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 4096, 8, 8)
              end
              {4096, 16, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 4096, 16, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 4096, 16, 8)
              end
              {4096, 32, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 4096, 32, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 4096, 32, 8)
              end
              {4096, 64, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 4096, 64, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 4096, 64, 8)
              end
              {4096, 128, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 4096, 128, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 4096, 128, 8)
              end
              {8192, 4, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 8192, 4, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 8192, 4, 16)
              end
              {8192, 8, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 8192, 8, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 8192, 8, 16)
              end
              {8192, 16, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 8192, 16, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 8192, 16, 16)
              end
              {8192, 32, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 8192, 32, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 8192, 32, 16)
              end
              {8192, 64, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 8192, 64, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 8192, 64, 16)
              end
              {16384, 4, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 16384, 4, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 16384, 4, 32)
              end
              {16384, 8, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 16384, 8, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 16384, 8, 32)
              end
              {16384, 16, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 16384, 16, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 16384, 16, 32)
              end
              {16384, 32, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hdr, r, 16384, 32, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hdr, r, 16384, 32, 32)
              end
              default: $error("Unsupported DEPTH/DATA_WIDTH/MUX_NUM combination: %0d/%0d/%0d", DEPTH, DATA_WIDTH, MUX_NUM);
            endcase
          end
          {TYPE1_RS, TYPE2_HS, VTH_L}: begin
            case({DEPTH, DATA_WIDTH, MUX_NUM})
              {32, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 32, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 32, 4, 4)
              end
              {32, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 32, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 32, 8, 4)
              end
              {32, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 32, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 32, 16, 4)
              end
              {32, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 32, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 32, 32, 4)
              end
              {32, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 32, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 32, 64, 4)
              end
              {32, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 32, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 32, 128, 4)
              end
              {32, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 32, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 32, 256, 4)
              end
              {64, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 64, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 64, 4, 4)
              end
              {64, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 64, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 64, 8, 4)
              end
              {64, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 64, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 64, 16, 4)
              end
              {64, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 64, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 64, 32, 4)
              end
              {64, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 64, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 64, 64, 4)
              end
              {64, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 64, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 64, 128, 4)
              end
              {64, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 64, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 64, 256, 4)
              end
              {128, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 128, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 128, 4, 4)
              end
              {128, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 128, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 128, 8, 4)
              end
              {128, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 128, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 128, 16, 4)
              end
              {128, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 128, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 128, 32, 4)
              end
              {128, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 128, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 128, 64, 4)
              end
              {128, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 128, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 128, 128, 4)
              end
              {128, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 128, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 128, 256, 4)
              end
              {256, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 256, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 256, 4, 4)
              end
              {256, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 256, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 256, 8, 4)
              end
              {256, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 256, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 256, 16, 4)
              end
              {256, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 256, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 256, 32, 4)
              end
              {256, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 256, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 256, 64, 4)
              end
              {256, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 256, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 256, 128, 4)
              end
              {256, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 256, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 256, 256, 4)
              end
              {512, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 512, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 512, 4, 4)
              end
              {512, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 512, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 512, 8, 4)
              end
              {512, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 512, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 512, 16, 4)
              end
              {512, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 512, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 512, 32, 4)
              end
              {512, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 512, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 512, 64, 4)
              end
              {512, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 512, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 512, 128, 4)
              end
              {512, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 512, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 512, 256, 4)
              end
              {1024, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 1024, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 1024, 4, 4)
              end
              {1024, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 1024, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 1024, 8, 4)
              end
              {1024, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 1024, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 1024, 16, 4)
              end
              {1024, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 1024, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 1024, 32, 4)
              end
              {1024, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 1024, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 1024, 64, 4)
              end
              {1024, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 1024, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 1024, 128, 4)
              end
              {1024, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 1024, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 1024, 256, 4)
              end
              {2048, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 2048, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 2048, 4, 4)
              end
              {2048, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 2048, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 2048, 8, 4)
              end
              {2048, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 2048, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 2048, 16, 4)
              end
              {2048, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 2048, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 2048, 32, 4)
              end
              {2048, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 2048, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 2048, 64, 4)
              end
              {2048, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 2048, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 2048, 128, 4)
              end
              {2048, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 2048, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 2048, 256, 4)
              end
              {4096, 4, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 4096, 4, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 4096, 4, 8)
              end
              {4096, 8, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 4096, 8, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 4096, 8, 8)
              end
              {4096, 16, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 4096, 16, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 4096, 16, 8)
              end
              {4096, 32, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 4096, 32, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 4096, 32, 8)
              end
              {4096, 64, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 4096, 64, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 4096, 64, 8)
              end
              {4096, 128, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 4096, 128, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 4096, 128, 8)
              end
              {8192, 4, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 8192, 4, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 8192, 4, 16)
              end
              {8192, 8, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 8192, 8, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 8192, 8, 16)
              end
              {8192, 16, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 8192, 16, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 8192, 16, 16)
              end
              {8192, 32, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 8192, 32, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 8192, 32, 16)
              end
              {8192, 64, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 8192, 64, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 8192, 64, 16)
              end
              {16384, 4, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 16384, 4, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 16384, 4, 32)
              end
              {16384, 8, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 16384, 8, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 16384, 8, 32)
              end
              {16384, 16, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 16384, 16, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 16384, 16, 32)
              end
              {16384, 32, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, l, 16384, 32, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, l, 16384, 32, 32)
              end
              default: $error("Unsupported DEPTH/DATA_WIDTH/MUX_NUM combination: %0d/%0d/%0d", DEPTH, DATA_WIDTH, MUX_NUM);
            endcase
          end
          {TYPE1_RS, TYPE2_HS, VTH_R}: begin
            case({DEPTH, DATA_WIDTH, MUX_NUM})
              {32, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 32, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 32, 4, 4)
              end
              {32, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 32, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 32, 8, 4)
              end
              {32, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 32, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 32, 16, 4)
              end
              {32, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 32, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 32, 32, 4)
              end
              {32, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 32, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 32, 64, 4)
              end
              {32, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 32, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 32, 128, 4)
              end
              {32, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 32, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 32, 256, 4)
              end
              {64, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 64, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 64, 4, 4)
              end
              {64, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 64, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 64, 8, 4)
              end
              {64, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 64, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 64, 16, 4)
              end
              {64, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 64, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 64, 32, 4)
              end
              {64, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 64, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 64, 64, 4)
              end
              {64, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 64, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 64, 128, 4)
              end
              {64, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 64, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 64, 256, 4)
              end
              {128, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 128, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 128, 4, 4)
              end
              {128, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 128, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 128, 8, 4)
              end
              {128, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 128, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 128, 16, 4)
              end
              {128, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 128, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 128, 32, 4)
              end
              {128, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 128, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 128, 64, 4)
              end
              {128, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 128, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 128, 128, 4)
              end
              {128, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 128, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 128, 256, 4)
              end
              {256, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 256, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 256, 4, 4)
              end
              {256, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 256, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 256, 8, 4)
              end
              {256, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 256, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 256, 16, 4)
              end
              {256, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 256, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 256, 32, 4)
              end
              {256, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 256, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 256, 64, 4)
              end
              {256, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 256, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 256, 128, 4)
              end
              {256, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 256, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 256, 256, 4)
              end
              {512, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 512, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 512, 4, 4)
              end
              {512, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 512, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 512, 8, 4)
              end
              {512, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 512, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 512, 16, 4)
              end
              {512, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 512, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 512, 32, 4)
              end
              {512, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 512, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 512, 64, 4)
              end
              {512, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 512, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 512, 128, 4)
              end
              {512, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 512, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 512, 256, 4)
              end
              {1024, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 1024, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 1024, 4, 4)
              end
              {1024, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 1024, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 1024, 8, 4)
              end
              {1024, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 1024, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 1024, 16, 4)
              end
              {1024, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 1024, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 1024, 32, 4)
              end
              {1024, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 1024, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 1024, 64, 4)
              end
              {1024, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 1024, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 1024, 128, 4)
              end
              {1024, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 1024, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 1024, 256, 4)
              end
              {2048, 4, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 2048, 4, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 2048, 4, 4)
              end
              {2048, 8, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 2048, 8, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 2048, 8, 4)
              end
              {2048, 16, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 2048, 16, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 2048, 16, 4)
              end
              {2048, 32, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 2048, 32, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 2048, 32, 4)
              end
              {2048, 64, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 2048, 64, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 2048, 64, 4)
              end
              {2048, 128, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 2048, 128, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 2048, 128, 4)
              end
              {2048, 256, 4}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 2048, 256, 4)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 2048, 256, 4)
              end
              {4096, 4, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 4096, 4, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 4096, 4, 8)
              end
              {4096, 8, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 4096, 8, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 4096, 8, 8)
              end
              {4096, 16, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 4096, 16, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 4096, 16, 8)
              end
              {4096, 32, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 4096, 32, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 4096, 32, 8)
              end
              {4096, 64, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 4096, 64, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 4096, 64, 8)
              end
              {4096, 128, 8}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 4096, 128, 8)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 4096, 128, 8)
              end
              {8192, 4, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 8192, 4, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 8192, 4, 16)
              end
              {8192, 8, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 8192, 8, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 8192, 8, 16)
              end
              {8192, 16, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 8192, 16, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 8192, 16, 16)
              end
              {8192, 32, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 8192, 32, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 8192, 32, 16)
              end
              {8192, 64, 16}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 8192, 64, 16)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 8192, 64, 16)
              end
              {16384, 4, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 16384, 4, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 16384, 4, 32)
              end
              {16384, 8, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 16384, 8, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 16384, 8, 32)
              end
              {16384, 16, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 16384, 16, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 16384, 16, 32)
              end
              {16384, 32, 32}: begin
                if(WMASK_EN == WMASK_ENABLE) `FDSOI_SRAM_WMASK_INST(rs, hs, r, 16384, 32, 32)
                else `FDSOI_SRAM_NO_WMASK_INST(rs, hs, r, 16384, 32, 32)
              end
              default: $error("Unsupported DEPTH/DATA_WIDTH/MUX_NUM combination: %0d/%0d/%0d", DEPTH, DATA_WIDTH, MUX_NUM);
            endcase
          end
          default: $error("Unsupported TYPE1/TYPE2/VTH combination");
        endcase
      end else if(TECH == TECH_LPP) begin
        $error("LPP not implemented");
      end else begin
        $error("Unsupported technology type: %0s", TECH.name());
      end
    end
  endgenerate
endmodule