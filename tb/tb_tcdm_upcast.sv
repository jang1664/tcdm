`timescale 1ns/1ps

//-----------------------------------------------------------------------------  
// Testbench for tcdm_upcast with 16-depth wide memory
//-----------------------------------------------------------------------------
module tb_tcdm_upcast;
  // parameters for this test
  localparam int unsigned SLV_WIDTH    = 16;  // narrow data width in bits
  localparam int unsigned MAS_WIDTH    = 64;  // wide data width in bits
  localparam int unsigned ADDR_WIDTH   = 32;
  localparam int unsigned MEM_DEPTH    = 16;  // number of wide words in memory

  // clock & reset
  logic clk_i    = 0;
  logic resetn_i = 0;
  always #5 clk_i = ~clk_i;

  // Instantiate narrow and wide TCDM interfaces
  mem_intf #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(SLV_WIDTH)
  ) slv_if(.clk(clk_i));

  mem_intf #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(MAS_WIDTH)
  ) mst_if(.clk(clk_i));

  // DUT instantiation
  tcdm_upcast #(
    .SLV_WIDTH(SLV_WIDTH),
    .MAS_WIDTH(MAS_WIDTH)
  ) uut (
    .clk_i      (clk_i),
    .resetn_i   (resetn_i),
    .tcdm_master(slv_if),
    .tcdm_slave (mst_if)
  );

  // grant and r_ready backpressure
  always_ff @(posedge clk_i) begin
    // always ready to grant
    slv_if.r_ready <= 1'b1;
  end

  // Memory write and read behavior
  tcdm_mem #(
      .BANK_WIDTH(MAS_WIDTH),
      .BANK_DEPTH(MEM_DEPTH),
      .BANK_NUM(1)
  ) u_tcdm_mem (
      .clk_i(clk_i),
      .resetn_i(resetn_i),
      .port(mst_if)
  );

  // Test stimulus
  int idx;
  int wrd;
  logic [ADDR_WIDTH-1:0] addr; 
  logic [SLV_WIDTH-1:0]  data; 
  logic [SLV_WIDTH/8-1:0] be  ; 
  logic [MAS_WIDTH-1:0] expected; 
  logic [SLV_WIDTH-1:0] read_data;
  logic [MAS_WIDTH-1:0] word; 
  logic err_flag = 0;
  initial begin
    $fsdbDumpfile("./reports/tb_tcdm_upcast.fsdb");
    $fsdbDumpvars(0, "+all", "+parameter", "+functions");

    // reset
    #10;
    resetn_i = 1;
    #10;

    // Test writes across all depth and narrow offsets
    @(posedge clk_i);
    for (wrd = 0; wrd < MEM_DEPTH; wrd++) begin
      for (idx = 0; idx < (MAS_WIDTH/SLV_WIDTH); idx++) begin
        addr = wrd * (MAS_WIDTH/8) + idx * (SLV_WIDTH/8);
        data = wrd*16 + idx;
        be   = {SLV_WIDTH/8{1'b1}};
        expected = (64'h0) | (data << (idx*SLV_WIDTH));

        // drive a write
        slv_if.addr  <= addr;
        slv_if.data  <= data;
        slv_if.be    <= be;
        slv_if.wen   <= 1'b1;
        slv_if.req   <= 1'b1;
        do begin
          @(posedge clk_i);
        end while (!slv_if.gnt);

        // verify memory content
        // if (mem[wrd] !== expected) begin
        //   $error("[%0t] WRITE ERR: wrd=%0d idx=%0d mem=0x%0h expected=0x%0h", $time, wrd, idx, mem[wrd], expected);
        // end
      end
    end
    slv_if.req  <= 1'b0;
    slv_if.wen  <= 1'b0;

    // Test reads across all depth and offsets
    for (wrd = 0; wrd < MEM_DEPTH; wrd++) begin
      for (idx = 0; idx < (MAS_WIDTH/SLV_WIDTH); idx++) begin
        addr = wrd * (MAS_WIDTH/8) + idx * (SLV_WIDTH/8);
        for(int x=0; x<MAS_WIDTH/SLV_WIDTH; x++) begin
          word[x*SLV_WIDTH +: SLV_WIDTH] = wrd*16 + x; // simulate memory content
        end
        expected = ((word >> (idx*SLV_WIDTH)) & {SLV_WIDTH{1'b1}});

        // drive a read
        slv_if.addr <= addr;
        slv_if.wen  <= 1'b0;
        slv_if.req  <= 1'b1;
        do begin
          @(posedge clk_i);
        end while (!(slv_if.gnt));

        do begin
          @(posedge clk_i);
        end while (!(slv_if.r_valid & slv_if.r_ready));
        read_data = slv_if.r_data;

        // expected narrow slice of mem[wrd]
        if (read_data !== expected) begin
          $error("[%0t] READ ERR: wrd=%0d idx=%0d data=0x%0h expected=0x%0h", $time, wrd, idx, read_data, expected);
          err_flag = 1;
        end
      end
    end
    slv_if.req <= 1'b0;

    $display("------------------ TEST RESULTS ------------------");
    if(err_flag) begin
      $display("Test failed: some read data did not match expected values.");
    end else begin
      $display("Test passed: all read data match expected values.");
    end
    $display("--------------------------------------------------");

    $fsdbDumpoff();
    $finish;
  end
endmodule
