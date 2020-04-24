//======================================================================
//
// tb_ntp_auth_keymem.v
// ------------
// key memory for the NTP Authentication (SHA1, MD5).
// Supports many separate keys, with key usage counters.
//
//
// Author: Peter Magnusson
//
// Copyright (c) 2020, The Swedish Post and Telecom Authority (PTS)
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

module tb_ntp_auth_keymem;
  //----------------------------------------------------------------
  // Constants: System clock model
  //----------------------------------------------------------------

  localparam HALF_CLOCK_PERIOD = 5;
  localparam CLOCK_PERIOD = 2 * HALF_CLOCK_PERIOD;

  //----------------------------------------------------------------
  // Constants: Register file address layout
  //----------------------------------------------------------------

  localparam ADDR_NAME0         = 8'h00;
  localparam ADDR_NAME1         = 8'h01;
  localparam ADDR_VERSION       = 8'h02;
  localparam ADDR_SLOTS         = 8'h03;
  localparam ADDR_ACTIVE_SLOT   = 8'h10;
  localparam ADDR_LOAD          = 8'h11;
  localparam ADDR_BUSY          = 8'h12;
  localparam ADDR_MD5_SHA1      = 8'h13;
  localparam ADDR_KEYID         = 8'h20;
  localparam ADDR_COUNTER_MSB   = 8'h21;
  localparam ADDR_COUNTER_LSB   = 8'h22;
  localparam ADDR_KEY0          = 8'h23;
  localparam ADDR_KEY1          = 8'h24;
  localparam ADDR_KEY2          = 8'h25;
  localparam ADDR_KEY3          = 8'h26;
  localparam ADDR_KEY4          = 8'h27;

  //----------------------------------------------------------------
  // Test variables, counters, configuration etc.
  //----------------------------------------------------------------

  reg [63:0] test_counter_fail;
  reg [63:0] test_counter_success;
  reg        test_output_on_success;
  reg        test_output_read;
  reg        test_inspect_fsm_client;
  reg        test_inspect_fsm_host;
  reg        test_inspect_ram_client;

  //----------------------------------------------------------------
  // Wires to DUT, Design Under Test. Clock, reset.
  //----------------------------------------------------------------

  reg           i_clk;
  reg           i_areset;

  //----------------------------------------------------------------
  // Wires to DUT, Design Under Test. Host API.
  //----------------------------------------------------------------

  reg           i_cs;
  reg           i_we;
  reg   [7 : 0] i_address;
  reg  [31 : 0] i_write_data;
  wire [31 : 0] o_read_data;

  //----------------------------------------------------------------
  // Wires to DUT, Design Under Test. Client Side.
  //----------------------------------------------------------------

  reg           i_get_key_md5; 
  reg           i_get_key_sha1;
  reg  [31 : 0] i_keyid;
  wire  [2 : 0] o_key_word;
  wire          o_key_valid;
  wire [31 : 0] o_key_data;
  wire          o_ready;

  //----------------------------------------------------------------
  // DUT, Design Under Test.
  //----------------------------------------------------------------

  ntp_auth_keymem dut (
    .i_clk       ( i_clk        ),
    .i_areset    ( i_areset     ),

    .i_cs        ( i_cs         ),
    .i_we        ( i_we         ),
    .i_address   ( i_address    ),
    .i_write_data( i_write_data ),
    .o_read_data ( o_read_data  ),

    .i_get_key_md5  ( i_get_key_md5  ),
    .i_get_key_sha1 ( i_get_key_sha1 ),
    .i_keyid        ( i_keyid        ),
    .o_key_word     ( o_key_word     ),
    .o_key_valid    ( o_key_valid    ),
    .o_key_data     ( o_key_data     ),
    .o_ready        ( o_ready        )
  );

  //----------------------------------------------------------------
  // Test Macros
  //----------------------------------------------------------------

  `define test(testname, condition) \
    begin \
      if (!(condition)) \
        begin \
          test_counter_fail = test_counter_fail + 1; \
          $display("%s:%0d %s test failed: %s", `__FILE__, `__LINE__, testname, `"condition`"); \
        end \
      else \
        begin \
          test_counter_success = test_counter_success + 1; \
          if (test_output_on_success) $display("%s:%0d %s test success", `__FILE__, `__LINE__, testname); \
        end \
    end

  `define test_read32( testname, expected, addr ) \
    begin \
      read32( tmp, addr ); \
      if (test_output_read) $display("%s:%0d %s read32[%h] = %h", `__FILE__, `__LINE__, testname, addr, tmp); \
      `test( testname, (tmp === expected) ); \
    end

  //----------------------------------------------------------------
  // Tasks. Client side task for looking up a key
  //----------------------------------------------------------------

  task client( input md5, input sha1, input [31:0] keyid );
  begin
    while ( o_ready == 1'b0 ) #(CLOCK_PERIOD);
    i_get_key_md5 = md5;
    i_get_key_sha1 = sha1;
    i_keyid = keyid;
    #(CLOCK_PERIOD);
    i_get_key_md5 = 0;
    i_get_key_sha1 = 0;
    i_keyid = 0;
    while ( o_ready == 1'b0 ) #(CLOCK_PERIOD);
  end
  endtask

  //----------------------------------------------------------------
  // Tasks. Client side task for looking up a key.
  //        More advanced version that emits the key
  //----------------------------------------------------------------

  task client_keyout( input md5, input sha1, input [31:0] keyid, output [5*32-1:0] key );
  begin : client_keyout
    reg done;
    key = 0;
    while ( o_ready == 1'b0 ) #(CLOCK_PERIOD);
    i_get_key_md5 = md5;
    i_get_key_sha1 = sha1;
    i_keyid = keyid;
    #(CLOCK_PERIOD);
    i_get_key_md5 = 0;
    i_get_key_sha1 = 0;
    i_keyid = 0;
    done = 0;
    while ( done == 1'b0 ) begin
      if ( o_key_valid ) begin
        key[ o_key_word*32+:32 ] = o_key_data;
      end
      done = o_ready;
      #(CLOCK_PERIOD);
    end
  end
  endtask

  //----------------------------------------------------------------
  // Tasks, basic I/O.
  //----------------------------------------------------------------

  task api_set;
    input         i_cs;
    input         i_we;
    input  [11:0] i_addr;
    input  [31:0] i_data;
    output        o_cs;
    output        o_we;
    output [11:0] o_addr;
    output [31:0] o_data;
  begin
    o_cs   = i_cs;
    o_we   = i_we;
    o_addr = i_addr;
    o_data = i_data;
  end
  endtask

  task read32( output [31:0] out, input [11:0] addr );
  begin : read32_
    reg [31:0] result;
    result = 0;
    api_set(1, 0, addr, 0, i_cs, i_we, i_address, i_write_data);
    #(CLOCK_PERIOD);
    result = o_read_data;
    api_set(0, 0, 0, 0, i_cs, i_we, i_address, i_write_data);
    out = result;
  end
  endtask

  task write32( input [31:0] data, input [11:0] addr);
  begin
    api_set(1, 1, addr, data, i_cs, i_we, i_address, i_write_data);
    #(CLOCK_PERIOD);
    api_set(0, 0, 0, 0, i_cs, i_we, i_address, i_write_data);
  end
  endtask

  //----------------------------------------------------------------
  // Task. Host side busy wait.
  //----------------------------------------------------------------

  task host_busy_wait;
  begin : host_busy_wait_
    reg [31:0] tmp;
    tmp = 32'h1;
    while (tmp !== 32'h0) begin
      read32( tmp,  ADDR_BUSY );
    end
  end
  endtask

  task host_load_slot( input[31:0] slot );
  begin : load_
    reg [31:0] tmp;

    write32( slot, ADDR_ACTIVE_SLOT );
    write32( 1, ADDR_LOAD );

    host_busy_wait();
  end
  endtask

  //----------------------------------------------------------------
  // Tasks. Tests.
  //----------------------------------------------------------------

  task test_core_name;
  begin : test_core_name_
    reg [63:0] name;
    reg [63:0] expected;
    expected =  "key_auth";
    read32(name[63:32], ADDR_NAME0);
    read32(name[31:0], ADDR_NAME1);
    test_output_on_success = 1;
    `test( "test_core_name", name === expected );
  end
  endtask

  task test_register_md5_sha1;
  begin : test_register_md5_sha1_
    reg [31:0] expected;
    reg [31:0] expected_a [0:7];
    reg [31:0] i;
    reg [31:0] slots;
    reg [31:0] tmp;
    expected_a[0] = 32'h3;
    expected_a[1] = 32'h0;
    expected_a[2] = 32'h2;
    expected_a[3] = 32'h1;
    expected_a[4] = 32'h3;
    expected_a[5] = 32'h2;
    expected_a[6] = 32'h1;
    expected_a[7] = 32'h0;

    test_output_on_success = 0;

    read32(slots, ADDR_SLOTS);
    `test( "test_register_md5_sha1", slots > 0 );
    `test( "test_register_md5_sha1", slots < 32'hffff_ffff );

    for ( i = 0; i < slots; i = i + 1) begin
      write32(i, ADDR_ACTIVE_SLOT);
      `test_read32( "test_register_md5_sha1", i, ADDR_ACTIVE_SLOT);

      expected = expected_a[ i[2:0] ];
      write32(expected, ADDR_MD5_SHA1);
      `test_read32( "test_register_md5_sha1", expected, ADDR_MD5_SHA1 );
    end

    for ( i = 0; i < slots; i = i + 1) begin
      expected = expected_a[ i[2:0] ];
      write32(expected, ADDR_MD5_SHA1);
      `test_read32( "test_register_md5_sha1", expected, ADDR_MD5_SHA1 );
    end
  end
  endtask

  task test_register_file;
  begin : test_register_file_
    reg [31:0] expected_keyid;
    reg [31:0] expected_counter_msb;
    reg [31:0] expected_counter_lsb;
    reg [31:0] expected_key0;
    reg [31:0] expected_key1;
    reg [31:0] expected_key2;
    reg [31:0] expected_key3;
    reg [31:0] expected_key4;
    reg [31:0] i;
    reg [31:0] slots;
    reg [31:0] tmp;

    test_output_on_success = 0;

    read32(slots, ADDR_SLOTS);
    `test( "test_register_file", slots > 0 );
    `test( "test_register_file", slots < 32'hffff_ffff );

    for ( i = 0; i < slots; i = i + 1) begin
      write32(i, ADDR_ACTIVE_SLOT);
      `test_read32( "test_register_file", i, ADDR_ACTIVE_SLOT);

      expected_keyid =       { 8'hF0, i[23:0] };
      expected_counter_msb = { 8'hF1, i[23:0] };
      expected_counter_lsb = { 8'hF2, i[23:0] };
      expected_key0 =        { 8'hF3, i[23:0] };
      expected_key1 =        { 8'hF4, i[23:0] };
      expected_key2 =        { 8'hF5, i[23:0] };
      expected_key3 =        { 8'hF6, i[23:0] };
      expected_key4 =        { 8'hF7, i[23:0] };

      write32( expected_keyid, ADDR_KEYID );
      write32( expected_counter_msb, ADDR_COUNTER_MSB );
      write32( expected_counter_lsb, ADDR_COUNTER_LSB );
      write32( expected_key0, ADDR_KEY0 );
      write32( expected_key1, ADDR_KEY1 );
      write32( expected_key2, ADDR_KEY2 );
      write32( expected_key3, ADDR_KEY3 );
      write32( expected_key4, ADDR_KEY4 );

      `test_read32( "test_register_file", expected_keyid, ADDR_KEYID);
      `test_read32( "test_register_file", expected_counter_msb, ADDR_COUNTER_MSB );
      `test_read32( "test_register_file", expected_counter_lsb, ADDR_COUNTER_LSB );
      `test_read32( "test_register_file", expected_key0, ADDR_KEY0 );
      `test_read32( "test_register_file", expected_key1, ADDR_KEY1 );
      `test_read32( "test_register_file", expected_key2, ADDR_KEY2 );
      `test_read32( "test_register_file", expected_key3, ADDR_KEY3 );
      `test_read32( "test_register_file", expected_key4, ADDR_KEY4 );
    end

    for ( i = 0; i < slots; i = i + 1) begin
      write32(i, ADDR_ACTIVE_SLOT);
      `test_read32( "test_register_file", i, ADDR_ACTIVE_SLOT);
      write32(32'h1, ADDR_LOAD);

      host_busy_wait();

      expected_keyid =       { 8'hF0, i[23:0] };
      expected_counter_msb = { 8'hF1, i[23:0] };
      expected_counter_lsb = { 8'hF2, i[23:0] };
      expected_key0 =        { 8'hF3, i[23:0] };
      expected_key1 =        { 8'hF4, i[23:0] };
      expected_key2 =        { 8'hF5, i[23:0] };
      expected_key3 =        { 8'hF6, i[23:0] };
      expected_key4 =        { 8'hF7, i[23:0] };

      `test_read32( "test_register_file", expected_keyid, ADDR_KEYID);
      `test_read32( "test_register_file", expected_counter_msb, ADDR_COUNTER_MSB );
      `test_read32( "test_register_file", expected_counter_lsb, ADDR_COUNTER_LSB );
      `test_read32( "test_register_file", expected_key0, ADDR_KEY0 );
      `test_read32( "test_register_file", expected_key1, ADDR_KEY1 );
      `test_read32( "test_register_file", expected_key2, ADDR_KEY2 );
      `test_read32( "test_register_file", expected_key3, ADDR_KEY3 );
      `test_read32( "test_register_file", expected_key4, ADDR_KEY4 );
    end

  end
  endtask

  task test_counters;
  begin : test_counters_
    reg [31:0] i;
    reg [31:0] slots;
    reg [31:0] tmp;

    read32(slots, ADDR_SLOTS);

    for ( i = 0; i < slots; i = i + 1) begin
      write32( i, ADDR_ACTIVE_SLOT);
      write32( 0, ADDR_KEYID );
      write32( 0, ADDR_COUNTER_MSB );
      write32( 0, ADDR_COUNTER_LSB );
      write32( 0, ADDR_MD5_SHA1 );
    end

    write32( 0, ADDR_ACTIVE_SLOT ); write32( 32'hc01df337, ADDR_KEYID ); write32( 1, ADDR_MD5_SHA1 );
    write32( 1, ADDR_ACTIVE_SLOT ); write32( 32'hc01df337, ADDR_KEYID ); write32( 2, ADDR_MD5_SHA1 );
    write32( 2, ADDR_ACTIVE_SLOT ); write32( 32'hf00d1007, ADDR_KEYID ); write32( 1, ADDR_MD5_SHA1 );
    write32( 3, ADDR_ACTIVE_SLOT ); write32( 32'hf00d1007, ADDR_KEYID ); write32( 2, ADDR_MD5_SHA1 );

    client( 1, 0, 32'hc01df337 );
    client( 1, 0, 32'hc01df337 );
    client( 1, 0, 32'hc01df337 );

    client( 0, 1, 32'hc01df337 );
    client( 0, 1, 32'hc01df337 );
    client( 0, 1, 32'hc01df337 );
    client( 0, 1, 32'hc01df337 );
    client( 0, 1, 32'hc01df337 );
    client( 0, 1, 32'hc01df337 );

    client( 1, 0, 32'hf00d1007 );

    client( 0, 1, 32'hf00d1007 );
    client( 0, 1, 32'hf00d1007 );

    host_load_slot( 0 );
    `test_read32( "test_counters", 0, ADDR_COUNTER_MSB );
    `test_read32( "test_counters", 3, ADDR_COUNTER_LSB );

    host_load_slot( 1 );
    `test_read32( "test_counters", 0, ADDR_COUNTER_MSB );
    `test_read32( "test_counters", 6, ADDR_COUNTER_LSB );

    host_load_slot( 2 );
    `test_read32( "test_counters", 0, ADDR_COUNTER_MSB );
    `test_read32( "test_counters", 1, ADDR_COUNTER_LSB );

    host_load_slot( 3 );
    `test_read32( "test_counters", 0, ADDR_COUNTER_MSB );
    `test_read32( "test_counters", 2, ADDR_COUNTER_LSB );

  end
  endtask

  task test_keys;
  begin : test_keys_
    reg [31:0] i;
    reg [31:0] slots;
    reg [5*32-1:0] key;
    reg [5*32-1:0] expected;

    read32(slots, ADDR_SLOTS);

    for ( i = 0; i < slots; i = i + 1) begin
      write32( i, ADDR_ACTIVE_SLOT);
      write32( 32'hee_00_00_00 + i, ADDR_KEYID );
      write32( 0, ADDR_COUNTER_MSB );
      write32( 0, ADDR_COUNTER_LSB );
      write32( 32'he0_00_00_00 + i, ADDR_KEY0 );
      write32( 32'he1_00_00_00 + i, ADDR_KEY1 );
      write32( 32'he2_00_00_00 + i, ADDR_KEY2 );
      write32( 32'he3_00_00_00 + i, ADDR_KEY3 );
      write32( 32'he4_00_00_00 + i, ADDR_KEY4 );
      case (i)
        1: write32( 32'h1, ADDR_MD5_SHA1 );
        2: write32( 32'h2, ADDR_MD5_SHA1 );
        5: write32( 32'h1, ADDR_MD5_SHA1 );
        7: write32( 32'h2, ADDR_MD5_SHA1 );
        default: write32( 32'h0, ADDR_MD5_SHA1 );
      endcase
    end

    for ( i = 0; i < slots; i = i + 1) begin
      case (i)
        2: expected = { 32'he4_00_00_00 + i, 32'he3_00_00_00 + i, 32'he2_00_00_00 + i, 32'he1_00_00_00 + i, 32'he0_00_00_00 + i };
        7: expected = { 32'he4_00_00_00 + i, 32'he3_00_00_00 + i, 32'he2_00_00_00 + i, 32'he1_00_00_00 + i, 32'he0_00_00_00 + i };
        default: expected = 0;
      endcase;
      client_keyout( 0, 1, 32'hee_00_00_00 + i, key );
      `test( "test_keys(sha1)", key === expected );
    end

    for ( i = 0; i < slots; i = i + 1) begin
      case (i)
        1: expected = { 32'he4_00_00_00 + i, 32'he3_00_00_00 + i, 32'he2_00_00_00 + i, 32'he1_00_00_00 + i, 32'he0_00_00_00 + i };
        5: expected = { 32'he4_00_00_00 + i, 32'he3_00_00_00 + i, 32'he2_00_00_00 + i, 32'he1_00_00_00 + i, 32'he0_00_00_00 + i };
        default: expected = 0;
      endcase;
      client_keyout( 1, 0, 32'hee_00_00_00 + i, key );
      `test( "test_keys(md5)", key === expected );
    end
  end
    
  endtask

  //----------------------------------------------------------------
  // test_main {
  //   init
  //   run_tests
  //   print_summary
  //   exit
  // }
  //----------------------------------------------------------------

  initial begin
    $display("Test start: %s:%0d", `__FILE__, `__LINE__);
    i_clk = 0;
    i_areset = 0;
    i_cs = 0;
    i_we = 0;
    i_address = 0;
    i_write_data = 0;
    i_get_key_md5 = 0;
    i_get_key_sha1 = 0;
    i_keyid = 0;
    test_counter_fail = 0;
    test_counter_success = 0;
    test_inspect_fsm_client = 0;
    test_inspect_fsm_host = 0;
    test_inspect_ram_client = 0;
    test_output_on_success = 1;
    test_output_read = 0;

    #(CLOCK_PERIOD);
    i_areset = 1;

    #(CLOCK_PERIOD);
    i_areset = 0;

    #(CLOCK_PERIOD);

    host_busy_wait();

    test_core_name();
    test_register_md5_sha1();
    test_register_file();
    test_counters();
    test_keys();

    $display("Test stop: %s:%0d SUCCESS: %0d FAILURES: %0d", `__FILE__, `__LINE__, test_counter_success, test_counter_fail);
    $finish;
  end

  //----------------------------------------------------------------
  // Testbench model: System Clock
  //----------------------------------------------------------------

  always begin
    #(HALF_CLOCK_PERIOD) i_clk = ~i_clk;
  end

  //----------------------------------------------------------------
  // Testbench debug prints
  //----------------------------------------------------------------

  `define inspect( x ) $display("%s:%0d: %s = %h", `__FILE__, `__LINE__, `"x`", x)

  always @*
  if (test_inspect_fsm_client)
    `inspect( dut.fsm_client_reg );

  always @*
    if (test_inspect_fsm_client)
      `inspect( dut.client_counter_msb_reg );

  always @*
    if (test_inspect_fsm_client)
      `inspect( dut.client_counter_lsb_reg );

  always @*
    if (test_inspect_ram_client)
      begin
       `inspect( dut.ram_client_en );
       `inspect( dut.ram_client_we );
       `inspect( dut.ram_client_addr );
       `inspect( dut.ram_client_di );
      end

  always @*
    if (test_inspect_ram_client)
      `inspect( dut.ram_client_do );

  always @*
    if (test_inspect_ram_client)
      `inspect( dut.ram_client_do_reg );

  always @*
    if (test_inspect_fsm_host )
      `inspect( dut.fsm_host_reg );

endmodule
