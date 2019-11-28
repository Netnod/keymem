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
module tb_nts_keymem();

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

  localparam ADDR_CTRL          = 8'h08;
  localparam CTRL_KEY0_VALID    = 0;
  localparam CTRL_KEY1_VALID    = 1;
  localparam CTRL_KEY2_VALID    = 2;
  localparam CTRL_KEY3_VALID    = 3;
  localparam CTRL_CURR_LOW      = 16;
  localparam CTRL_CURR_HIGH     = 17;

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
  nts_keymem dut(
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
      $display("Inputs and outputs:");
      $display("-------------------");
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
      tb_areset = 1;

      #(2 * CLK_PERIOD);
      tb_areset = 0;
    end
  endtask // reset_dut

  task verify_reset;
    begin: verify_reset
      reg verify_reset_error;
      reg [7 : 0] i;
      verify_reset_error = 0;

      for (i = 8'h0 ; i < 8'h10 && !verify_reset_error ; i = i + 1'h1)
        begin
          read_word((ADDR_KEY0_START + i));
          if (read_data != 32'h0)
          begin
            verify_reset_error = 1;
          end
          read_word((ADDR_KEY1_START + i));
          if (read_data != 32'h0)
          begin
            verify_reset_error = 1;
          end
          read_word((ADDR_KEY2_START + i));
          if (read_data != 32'h0)
          begin
            verify_reset_error = 1;
          end
          read_word((ADDR_KEY3_START + i));
          if (read_data != 32'h0)
          begin
            verify_reset_error = 1;
          end
        end
      tc_ctr = tc_ctr + 1;
      if (verify_reset_error)
      begin
        $display("*** TC01: Error in reset test at iteration  %02d", i);
        error_ctr = error_ctr + 1;
      end
    end
  endtask // verify_reset


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
  // dump_keys()
  //
  // Access the DUT directly to dump the contents of the memory
  //----------------------------------------------------------------
  task dump_keys;
    begin
      $display("Key status:");
      $display("-----------");
      $display("key0:");
      $display("length: 0x%01x, valid: 0x%01x, id: 0x%08x",
               dut.key0_length_reg, dut.key0_valid_reg, dut.key0_id_reg);
      $display("00: 0x%08x, 01: 0x%08x, 02: 0x%08x, 03: 0x%08x",
               dut.key0[0], dut.key0[1], dut.key0[2], dut.key0[3]);
      $display("04: 0x%08x, 05: 0x%08x, 06: 0x%08x, 07: 0x%08x",
               dut.key0[4], dut.key0[5], dut.key0[6], dut.key0[7]);
      $display("08: 0x%08x, 09: 0x%08x, 0a: 0x%08x, 0b: 0x%08x",
               dut.key0[8], dut.key0[9], dut.key0[10], dut.key0[11]);
      $display("0c: 0x%08x, 0d: 0x%08x, 0e: 0x%08x, 0f: 0x%08x",
               dut.key0[12], dut.key0[13], dut.key0[14], dut.key0[15]);
      $display("");

      $display("key1:");
      $display("length: 0x%01x, valid: 0x%01x, id: 0x%08x",
               dut.key1_length_reg, dut.key1_valid_reg, dut.key1_id_reg);
      $display("00: 0x%08x, 01: 0x%08x, 02: 0x%08x, 03: 0x%08x",
               dut.key1[0], dut.key1[1], dut.key1[2], dut.key1[3]);
      $display("04: 0x%08x, 05: 0x%08x, 06: 0x%08x, 07: 0x%08x",
               dut.key1[4], dut.key1[5], dut.key1[6], dut.key1[7]);
      $display("08: 0x%08x, 09: 0x%08x, 0a: 0x%08x, 0b: 0x%08x",
               dut.key1[8], dut.key1[9], dut.key1[10], dut.key1[11]);
      $display("0c: 0x%08x, 0d: 0x%08x, 0e: 0x%08x, 0f: 0x%08x",
               dut.key1[12], dut.key1[13], dut.key1[14], dut.key1[15]);
      $display("");

      $display("key2:");
      $display("length: 0x%01x, valid: 0x%01x, id: 0x%08x",
               dut.key2_length_reg, dut.key2_valid_reg, dut.key2_id_reg);
      $display("00: 0x%08x, 01: 0x%08x, 02: 0x%08x, 03: 0x%08x",
               dut.key2[0], dut.key2[1], dut.key2[2], dut.key2[3]);
      $display("04: 0x%08x, 05: 0x%08x, 06: 0x%08x, 07: 0x%08x",
               dut.key2[4], dut.key2[5], dut.key2[6], dut.key2[7]);
      $display("08: 0x%08x, 09: 0x%08x, 0a: 0x%08x, 0b: 0x%08x",
               dut.key2[8], dut.key2[9], dut.key2[10], dut.key2[11]);
      $display("0c: 0x%08x, 0d: 0x%08x, 0e: 0x%08x, 0f: 0x%08x",
               dut.key2[12], dut.key2[13], dut.key2[14], dut.key2[15]);
      $display("");

      $display("key3:");
      $display("length: 0x%01x, valid: 0x%01x, id: 0x%08x",
               dut.key3_length_reg, dut.key3_valid_reg, dut.key3_id_reg);
      $display("00: 0x%08x, 01: 0x%08x, 02: 0x%08x, 03: 0x%08x",
               dut.key3[0], dut.key3[1], dut.key3[2], dut.key3[3]);
      $display("04: 0x%08x, 05: 0x%08x, 06: 0x%08x, 07: 0x%08x",
               dut.key3[4], dut.key3[5], dut.key3[6], dut.key3[7]);
      $display("08: 0x%08x, 09: 0x%08x, 0a: 0x%08x, 0b: 0x%08x",
               dut.key3[8], dut.key3[9], dut.key3[10], dut.key3[11]);
      $display("0c: 0x%08x, 0d: 0x%08x, 0e: 0x%08x, 0f: 0x%08x",
               dut.key3[12], dut.key3[13], dut.key3[14], dut.key3[15]);
      $display("");
    end
  endtask // read_word


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
      $display("*** init_sim() complete.");
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
      #(1 * CLK_PERIOD);
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

  task write_key(input [11 : 0]  address, input [0 : 511] key);
    begin : write_key
      integer i;
      for (i = 4'h0 ; i <= 4'hf ; i = i + 1'h1)
      begin
        //$display("*** Writing 0x%08x from 0x%02x at iteration %02d.", key[32*i +: 32], (address + i), i);
        write_word((address + i), key[32*i +: 32]);
      end
    end
  endtask



  //----------------------------------------------------------------

  //----------------------------------------------------------------
  task tc1_static_write_keys;
    begin : tc1_static_write_keys
      write_key(ADDR_KEY0_START, {
        {4{8'h0}}, {4{8'h01}}, {4{8'h02}}, {4{8'h03}},
        {4{8'h04}}, {4{8'h05}}, {4{8'h06}}, {4{8'h07}},
        {4{8'h08}}, {4{8'h09}}, {4{8'h0a}}, {4{8'h0b}},
        {4{8'h0c}}, {4{8'h0d}}, {4{8'h0e}}, {4{8'h0f}}});
      write_word(ADDR_KEY0_ID, 32'haa11);
      write_word(ADDR_KEY0_LENGTH, {31'h0, 1'h1});
      write_key(ADDR_KEY1_START, {
        {4{8'h10}}, {4{8'h11}}, {4{8'h12}}, {4{8'h13}},
        {4{8'h14}}, {4{8'h15}}, {4{8'h16}}, {4{8'h17}},
        {4{8'h18}}, {4{8'h19}}, {4{8'h1a}}, {4{8'h1b}},
        {4{8'h1c}}, {4{8'h1d}}, {4{8'h1e}}, {4{8'h1f}}});
      write_word(ADDR_KEY1_ID, 32'hbb22);
      write_word(ADDR_KEY1_LENGTH, {31'h0, 1'h1});
      write_key(ADDR_KEY2_START, {
        {4{8'h20}}, {4{8'h21}}, {4{8'h22}}, {4{8'h23}},
        {4{8'h24}}, {4{8'h25}}, {4{8'h26}}, {4{8'h27}},
        {4{8'h28}}, {4{8'h29}}, {4{8'h2a}}, {4{8'h2b}},
        {4{8'h2c}}, {4{8'h2d}}, {4{8'h2e}}, {4{8'h2f}}});
      write_word(ADDR_KEY2_ID, 32'hcc33);
      write_word(ADDR_KEY2_LENGTH, {31'h0, 1'h1});
      write_key(ADDR_KEY3_START, {
        {4{8'h30}}, {4{8'h31}}, {4{8'h32}}, {4{8'h33}},
        {4{8'h34}}, {4{8'h35}}, {4{8'h36}}, {4{8'h37}},
        {4{8'h38}}, {4{8'h39}}, {4{8'h3a}}, {4{8'h3b}},
        {4{8'h3c}}, {4{8'h3d}}, {4{8'h3e}}, {4{8'h3f}}});
      write_word(ADDR_KEY3_ID, 32'hdd44);
      write_word(ADDR_KEY3_LENGTH, {31'h0, 1'h1});
    end
  endtask

  task tc2_static_verify_keys_reg;
    begin : tc1_write_keys_reg
      reg [7 : 0] i;
      reg verify_static_keys_error;
      verify_static_keys_error = 0;

      for (i = 8'h0 ; i < 8'h10 && !verify_static_keys_error ; i = i + 1'h1)
      begin
        read_word((ADDR_KEY0_START + i));
        if (read_data != {i, i, i, i})
        begin
          verify_static_keys_error = 1;
          $display("*** TC02: Error in verifyin word %02d of KEY0", i);
        end
      end

      for (i = 8'h0 ; i < 8'h10 && !verify_static_keys_error ; i = i + 1'h1)
      begin
        read_word((ADDR_KEY1_START + i));
        if (read_data != {8'h10 + i, 8'h10 + i, 8'h10 + i, 8'h10 + i})
        begin
          verify_static_keys_error = 1;
          $display("*** TC02: Error in verifyin word %02d of KEY1", i);
        end
      end

      for (i = 8'h0 ; i < 8'h10 && !verify_static_keys_error ; i = i + 1'h1)
      begin
        read_word((ADDR_KEY2_START + i));
        if (read_data != {8'h20 + i, 8'h20 + i, 8'h20 + i, 8'h20 + i})
        begin
          verify_static_keys_error = 1;
          $display("*** TC02: Error in verifyin word %02d of KEY2", i);
        end
      end

      for (i = 8'h0 ; i < 8'h10 && !verify_static_keys_error ; i = i + 1'h1)
      begin
        read_word((ADDR_KEY3_START + i));
        if (read_data != {8'h30 + i, 8'h30 + i, 8'h30 + i, 8'h30 + i})
        begin
          verify_static_keys_error = 1;
          $display("*** TC02: Error in verifyin word %02d of KEY3", i);
        end
      end

      tc_ctr = tc_ctr + 1;
      if (verify_static_keys_error)
      begin
        error_ctr = error_ctr + 1;
      end
    end
  endtask

  task tc3_write_current_key;
    begin : tc3_write_current_key
      write_word(ADDR_CTRL,
        {14'h0, 2'h2, 12'h0, 1'h1,
          1'h1, 1'h1, 1'h1});

    end
  endtask

  task tc3_verify_current_key_reg;
    begin : tc3_verify_current_key_reg
      tc_ctr = tc_ctr + 1;
      read_word(ADDR_CTRL);
      if (read_data[CTRL_CURR_HIGH : CTRL_CURR_LOW] != 2'h2)
      begin
        $display("*** TC03: Error verifying current key register");
        error_ctr = error_ctr + 1;
      end
    end
  endtask

  task tc4_verify_current_key_read;
    begin : tc4_verify_current_key_read
      reg [4 : 0] i;
      reg verify_current_key_read_error;
      verify_current_key_read_error = 0;
      for (i = 0 ; i < 16 && !verify_current_key_read_error ; i = i + 1)
      begin
        dut_key_word = i;
        dut_get_current_key = 1'h1;
        #(1 * CLK_PERIOD);
        if (dut_key_length != {31'h0, 1'h1})
        begin
          verify_current_key_read_error = 1;
        end
        if (dut_key_id != 32'hcc33)
        begin
          verify_current_key_read_error = 1;
        end
        if (dut_key_data != {8'h20 + i, 8'h20 + i, 8'h20 + i, 8'h20 + i})
        begin
          verify_current_key_read_error = 1;
        end
        dut_get_current_key = 1'h0;
        #(CLK_PERIOD);
      end
      if (verify_current_key_read_error)
      begin
        $display("*** Error verifying current key read");
        error_ctr = error_ctr + 1;
      end
    end
  endtask

  task tc5_write_current_key_as_invalid;
    begin : tc1_write_keys
      write_word(ADDR_CTRL,
        {14'h0, 2'h1, 12'h0, 1'h0,
          1'h0, 1'h0, 1'h0});
    end
  endtask

  task tc5_verify_current_key_read_as_invalid;
    begin : tc5_verify_current_key_read_as_invalid
      reg [4 : 0] i;
      reg verify_current_key_read_as_invalid_error;
      verify_current_key_read_as_invalid_error = 0;
      for (i = 0 ; i < 16 && !verify_current_key_read_as_invalid_error ; i = i + 1)
      begin
        dut_key_word <= i;
        dut_get_current_key <= 1'h1;
        #(1 * CLK_PERIOD);
        if (dut_key_data != {8'h20 + i, 8'h20 + i, 8'h20 + i, 8'h20 + i})
        begin
          verify_current_key_read_as_invalid_error = 1;
        end
        dut_get_current_key = 1'h0;
        #(CLK_PERIOD);
      end
      tc_ctr = tc_ctr + 1;
      if (!verify_current_key_read_as_invalid_error)
      begin
        $display("*** TC05: Current key read even though it is invalid");
        error_ctr = error_ctr + 1;
      end
    end
  endtask

  task tc6_verify_key_counter(input [31 : 0]  expected);
    begin : write_key
      read_word(ADDR_KEY2_COUNTER);
      if (read_data != expected)
      begin
        $display("*** TC06: FAIL counter was %0d, expected %0d", read_data, expected);
        $display("*** TC06: Direct read counter is %0d", dut.key2_ctr_reg);
        error_ctr = error_ctr + 1;
      end
    end
  endtask

  task tc6_write_to_clear_key_counter;
    begin
      write_word(ADDR_KEY2_COUNTER, 32'h1);
    end
  endtask

  task tc7_write_key_2_as_valid;
    begin : tc3_write_current_key
      read_word(ADDR_CTRL);
      write_word(ADDR_CTRL, read_data | {28'h0, 1'h0, 1'h1, 1'h0, 1'h0});
    end
  endtask

  task tc7_verify_key_by_id;
    begin : tc7_verify_key_by_id
      reg [4 : 0] i;
      reg verify_key_by_id_error;
      verify_key_by_id_error = 0;
      for (i = 0 ; i < 16 && !verify_key_by_id_error ; i = i + 1)
      begin
        dut_key_word = i;
        dut_get_key_with_id = 32'h1;
        dut_server_key_id = 32'hcc33;
        #(1 * CLK_PERIOD);
        if (dut_key_length != {31'h0, 1'h1})
        begin
          verify_key_by_id_error = 1;
          $display("*** Error verifying key by id length");
        end
        if (dut_key_id != 32'hcc33)
        begin
          verify_key_by_id_error = 1;
          $display("*** Error verifying key by id id, id was %h", dut_key_id);
        end
        if (dut_key_data != {8'h20 + i, 8'h20 + i, 8'h20 + i, 8'h20 + i})
        begin
          verify_key_by_id_error = 1;
        end
        dut_get_current_key = 1'h0;
        #(CLK_PERIOD);
      end
      if (verify_key_by_id_error)
      begin
        $display("*** Error verifying key by id read");
        error_ctr = error_ctr + 1;
      end
    end
  endtask

  //----------------------------------------------------------------
  // main
  //
  // The main test functionality.
  //----------------------------------------------------------------
  initial
    begin : main
      $dumpfile("dump.vcd");
      $dumpvars(0, tb_nts_keymem);
      $display("   -= Testbench for NTS keymem started =-");
      $display("    =====================================");
      $display("");

      init_sim();
      /* TC01 */
      $display("*** TC01: Writing keys");
      tc1_static_write_keys();
      $display("*** TC01: Resetting DUT");
      reset_dut();
      $display("*** TC01: Verifying reset");
      verify_reset();
      /* TC02 */
      $display("*** TC02: Writing keys");
      tc1_static_write_keys();
      $display("*** TC02: Verifying keys");
      tc2_static_verify_keys_reg();
      reset_dut();
      /* TC03 */
      $display("*** TC03: Writing current key");
      tc3_write_current_key();
      $display("*** TC03: Verifying current key");
      tc3_verify_current_key_reg();
      reset_dut();
      /* TC04 */
      $display("*** TC04: Writing keys");
      tc1_static_write_keys();
      $display("*** TC04: Writing current key");
      tc3_write_current_key();
      $display("*** TC04: Reading current key");
      tc4_verify_current_key_read();
      tc_ctr = tc_ctr + 1;
      /* TC05 */
      reset_dut();
      $display("*** TC05: Writing keys");
      tc1_static_write_keys();
      $display("*** TC05: Writing current key as Invalid");
      tc5_write_current_key_as_invalid();
      $display("*** TC05: Reading current key");
      tc5_verify_current_key_read_as_invalid();
      reset_dut();
      /* TC06 */
      $display("*** TC06: Writing keys");
      tc1_static_write_keys();
      $display("*** TC06: Writing current key");
      tc3_write_current_key();
      $display("*** TC06: Verifying counter is 0");
      tc6_verify_key_counter(32'd0);
      $display("*** TC06: Reading current key");
      tc4_verify_current_key_read();
      $display("*** TC06: Verifying counter is 1");
      tc6_verify_key_counter(32'd16);
      $display("*** TC06: Writing to clear counter");
      tc6_write_to_clear_key_counter();
      $display("*** TC06: Verifying counter is 0");
      tc6_verify_key_counter(32'd0);
      tc_ctr = tc_ctr + 1;
      reset_dut();
      /* TC07 */
      $display("*** TC07: Writing keys");
      tc1_static_write_keys();
      $display("*** TC07: Setting key 2 as valid");
      tc7_write_key_2_as_valid();
      $display("*** TC07: Reading key by ID");
      tc7_verify_key_by_id();
      tc_ctr = tc_ctr + 1;
      reset_dut();

      display_test_results();

      $display("");
      $display("*** NTS keymem simulation done. ***");
      $finish;
    end // main
endmodule // tb_keymem

//======================================================================
// EOF tb_keymem.v
//======================================================================
