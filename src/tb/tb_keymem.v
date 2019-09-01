//======================================================================
//
// tb_keymem.v
// -----------
// Testbench for NTS keymem.
//
//
// Author: Joachim Strombergson
//
// Copyright (c) 2019, The Swedish Post and Telecom Authority (PTS)
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
// ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================


//------------------------------------------------------------------
// Test module.
//------------------------------------------------------------------
module tb_keymem();

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter DEBUG     = 0;

  parameter CLK_HALF_PERIOD = 1;
  parameter CLK_PERIOD      = 2 * CLK_HALF_PERIOD;

  // API
  localparam ADDR_NAME0         = 8'h00;
  localparam ADDR_NAME1         = 8'h01;
  localparam ADDR_VERSION       = 8'h02;

  localparam ADDR_CURRENT_KEY   = 8'h08;
  localparam ADDR_VALID_KEYS    = 8'h09;

  localparam ADDR_KEY0_ID       = 8'h10;
  localparam ADDR_KEY0_LENGTH   = 8'h11;

  localparam ADDR_KEY1_ID       = 8'h12;
  localparam ADDR_KEY1_LENGTH   = 8'h13;

  localparam ADDR_KEY2_ID       = 8'h14;
  localparam ADDR_KEY2_LENGTH   = 8'h15;

  localparam ADDR_KEY3_ID       = 8'h16;
  localparam ADDR_KEY3_LENGTH   = 8'h17;

  localparam ADDR_KEY0_COUNTER  = 8'h30;
  localparam ADDR_KEY1_COUNTER  = 8'h31;
  localparam ADDR_KEY2_COUNTER  = 8'h32;
  localparam ADDR_KEY3_COUNTER  = 8'h33;
  localparam ADDR_ERROR_COUNTER = 8'h34;

  localparam ADDR_KEY0_START    = 8'h40;
  localparam ADDR_KEY0_END      = 8'h4f;

  localparam ADDR_KEY1_START    = 8'h50;
  localparam ADDR_KEY1_END      = 8'h5f;

  localparam ADDR_KEY2_START    = 8'h60;
  localparam ADDR_KEY2_END      = 8'h6f;

  localparam ADDR_KEY3_START    = 8'h70;
  localparam ADDR_KEY3_END      = 8'h7f;


  //----------------------------------------------------------------
  // Register and Wire declarations.
  //----------------------------------------------------------------
  reg [31 : 0]  cycle_ctr;
  reg [31 : 0]  error_ctr;
  reg [31 : 0]  tc_ctr;

  reg [31 : 0]  read_data;
  reg [127 : 0] result_data;

  reg           tb_clk;
  reg           tb_areset;
  reg           dut_cs;
  reg           dut_we;
  reg [7  : 0]  dut_address;
  reg [31 : 0]  dut_write_data;
  wire [31 : 0] dut_read_data;

  reg           dut_get_current_key;
  reg           dut_get_key_with_id;
  reg  [31 : 0] dut_server_key_id;
  reg  [3 : 0]  dut_key_word;
  wire          dut_key_valid;
  wire          dut_key_length;
  wire [31 : 0] dut_key_id;
  wire [31 : 0] dut_key_data;
  wire          dut_ready;


  //----------------------------------------------------------------
  // Device Under Test.
  //----------------------------------------------------------------
  keymem dut(
             .clk(tb_clk),
             .areset(tb_areset),
             .cs(dut_cs),
             .we(dut_we),
             .address(dut_address),
             .write_data(dut_write_data),
             .read_data(dut_read_data),
             .get_current_key(dut_get_current_key),
             .get_key_with_id(dut_get_key_with_id),
             .server_key_id(dut_server_key_id),
             .key_word(dut_key_word),
             .key_valid(dut_key_valid),
             .key_length(dut_key_length),
             .key_id(dut_key_id),
             .key_data(dut_key_data),
             .ready(dut_ready)
            );


  //----------------------------------------------------------------
  // clk_gen
  //
  // Always running clock generator process.
  //----------------------------------------------------------------
  always
    begin : clk_gen
      #CLK_HALF_PERIOD;
      tb_clk = !tb_clk;
    end // clk_gen


  //----------------------------------------------------------------
  // sys_monitor()
  //
  // An always running process that creates a cycle counter and
  // conditionally displays information about the DUT.
  //----------------------------------------------------------------
  always
    begin : sys_monitor
      cycle_ctr = cycle_ctr + 1;

      #(CLK_PERIOD);

      if (DEBUG)
        begin
          dump_dut_state();
        end
    end


  //----------------------------------------------------------------
  // dump_dut_state()
  //
  // Dump the state of the dump when needed.
  //----------------------------------------------------------------
  task dump_dut_state;
    begin
      $display("cycle: 0x%016x", cycle_ctr);
      $display("State of DUT");
      $display("------------");


      $display("\n");
    end
  endtask // dump_dut_state


  //----------------------------------------------------------------
  // reset_dut()
  //
  // Toggle reset to put the DUT into a well known state.
  //----------------------------------------------------------------
  task reset_dut;
    begin
      $display("*** Toggling reset.");
      tb_areset = 1;

      #(2 * CLK_PERIOD);
      tb_areset = 0;
      $display("");
    end
  endtask // reset_dut


  //----------------------------------------------------------------
  // display_test_results()
  //
  // Display the accumulated test results.
  //----------------------------------------------------------------
  task display_test_results;
    begin
      if (error_ctr == 0)
        begin
          $display("*** All %02d test cases completed successfully", tc_ctr);
        end
      else
        begin
          $display("*** %02d tests completed - %02d test cases did not complete successfully.",
                   tc_ctr, error_ctr);
        end
    end
  endtask // display_test_results


  //----------------------------------------------------------------
  // init_sim()
  //
  // Initialize all counters and testbed functionality as well
  // as setting the DUT inputs to defined values.
  //----------------------------------------------------------------
  task init_sim;
    begin
      cycle_ctr           = 0;
      error_ctr           = 0;
      tc_ctr              = 0;

      tb_clk              = 0;
      tb_areset           = 0;

      dut_cs              = 1'h0;
      dut_we              = 1'h0;
      dut_address         = 8'h0;;
      dut_write_data      = 32'h0;
      dut_get_current_key = 1'h0;
      dut_get_key_with_id = 1'h0;
      dut_server_key_id   = 32'h0;
      dut_key_word        = 4'h0;
    end
  endtask // init_sim


  //----------------------------------------------------------------
  // write_word()
  //
  // Write the given word to the DUT using the DUT interface.
  //----------------------------------------------------------------
  task write_word(input [11 : 0] address,
                  input [31 : 0] word);
    begin
      if (DEBUG)
        begin
          $display("*** Writing 0x%08x to 0x%02x.", word, address);
          $display("");
        end

      dut_address = address;
      dut_write_data = word;
      dut_cs = 1;
      dut_we = 1;
      #(2 * CLK_PERIOD);
      dut_cs = 0;
      dut_we = 0;
    end
  endtask // write_word


  //----------------------------------------------------------------
  // read_word()
  //
  // Read a data word from the given address in the DUT.
  // the word read will be available in the global variable
  // read_data.
  //----------------------------------------------------------------
  task read_word(input [11 : 0]  address);
    begin
      dut_address = address;
      dut_cs = 1;
      dut_we = 0;
      #(CLK_PERIOD);
      read_data = dut_read_data;
      dut_cs = 0;

      if (DEBUG)
        begin
          $display("*** Reading 0x%08x from 0x%02x.", read_data, address);
          $display("");
        end
    end
  endtask // read_word


  //----------------------------------------------------------------
  // main
  //
  // The main test functionality.
  //----------------------------------------------------------------
  initial
    begin : main
      $display("   -= Testbench for NTS keymem started =-");
      $display("    =====================================");
      $display("");

      init_sim();
      dump_dut_state();
      reset_dut();
      dump_dut_state();

      $display("");
      $display("*** NTS keymem simulation done. ***");
      $finish;
    end // main
endmodule // tb_keymem

//======================================================================
// EOF tb_keymem.v
//======================================================================
