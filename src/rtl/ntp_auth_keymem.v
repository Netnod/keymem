//======================================================================
//
// ntp_auth_keymem.v
// ------------
// key memory for the NTP Authentication (SHA1, MD5).
// Supports many separate keys, with key usage counters.
//
//
// Author: Peter Magnusson
//
// Copyright (c) 2020, Netnod Internet Exchange i Sverige AB (Netnod).
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

module ntp_auth_keymem(

  input wire           i_clk,
  input wire           i_areset,

  // API access
  input wire           i_cs,
  input wire           i_we,
  input wire   [7 : 0] i_address,
  input wire  [31 : 0] i_write_data,
  output wire [31 : 0] o_read_data,

  // Client access

  input wire           i_get_key_md5,
  input wire           i_get_key_sha1,
  input wire  [31 : 0] i_keyid,
  output wire  [2 : 0] o_key_word,
  output wire          o_key_valid,
  output wire [31 : 0] o_key_data,
  output wire          o_ready
);

  // Implementation notes
  //
  // RAM
  //   * Implemented as a dual port RAM.
  //   * Host side I/O on port a side of RAM.
  //   * Client siide I/O on port b side of RAM.
  //   * Each entry consumes 8x32bit entries: [ key_id, counter_msb, counter_lsb, key0, key1, key2, key3, key4 ]
  //
  // A quick access register indicates all entries that are MD5
  // A quick access register indicates all entries that are SHA1
  // A quick access register file includes all key ids in use.

  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
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

  localparam CORE_NAME0   = 32'h6b_65_79_5f; // "key_"
  localparam CORE_NAME1   = 32'h61_75_74_68; // "auth"
  localparam CORE_VERSION = 32'h30_2e_30_31; // "0.01"

  localparam SLOT_ADDR_BITS  = 5;
  localparam SLOT_ENTRIES    = 1<<SLOT_ADDR_BITS;

  localparam BRAM_ADDR_WIDTH = SLOT_ADDR_BITS + 3;
  localparam BRAM_ENTRIES    = 1<<BRAM_ADDR_WIDTH;

  localparam FSM_HOST_BITS = 4;
  localparam [FSM_HOST_BITS-1:0] FSM_HOST_IDLE             = 0;
  localparam [FSM_HOST_BITS-1:0] FSM_HOST_LOAD_KEY_ID      = 1;
  localparam [FSM_HOST_BITS-1:0] FSM_HOST_LOAD_COUNTER_MSB = 2;
  localparam [FSM_HOST_BITS-1:0] FSM_HOST_LOAD_COUNTER_LSB = 3;
  localparam [FSM_HOST_BITS-1:0] FSM_HOST_LOAD_KEY0        = 4;
  localparam [FSM_HOST_BITS-1:0] FSM_HOST_LOAD_KEY1        = 5;
  localparam [FSM_HOST_BITS-1:0] FSM_HOST_LOAD_KEY2        = 6;
  localparam [FSM_HOST_BITS-1:0] FSM_HOST_LOAD_KEY3        = 7;
  localparam [FSM_HOST_BITS-1:0] FSM_HOST_LOAD_KEY4        = 8;
  localparam [FSM_HOST_BITS-1:0] FSM_HOST_WAIT0            = 9;
  localparam [FSM_HOST_BITS-1:0] FSM_HOST_WAIT1            = 10;
  localparam [FSM_HOST_BITS-1:0] FSM_HOST_RESET            = 11;

  localparam FSM_CLIENT_BITS = 4;
  localparam [FSM_CLIENT_BITS-1:0] FSM_CLIENT_IDLE              = 0;
  localparam [FSM_CLIENT_BITS-1:0] FSM_CLIENT_SEARCH_0          = 1;
  localparam [FSM_CLIENT_BITS-1:0] FSM_CLIENT_SEARCH_1          = 2;
  localparam [FSM_CLIENT_BITS-1:0] FSM_CLIENT_SEARCH_2          = 3;
  localparam [FSM_CLIENT_BITS-1:0] FSM_CLIENT_LOAD_COUNTER_MSB  = 4;
  localparam [FSM_CLIENT_BITS-1:0] FSM_CLIENT_LOAD_COUNTER_LSB  = 5;
  localparam [FSM_CLIENT_BITS-1:0] FSM_CLIENT_LOAD_KEY0         = 6;
  localparam [FSM_CLIENT_BITS-1:0] FSM_CLIENT_LOAD_KEY1         = 7;
  localparam [FSM_CLIENT_BITS-1:0] FSM_CLIENT_LOAD_KEY2         = 8;
  localparam [FSM_CLIENT_BITS-1:0] FSM_CLIENT_LOAD_KEY3         = 9;
  localparam [FSM_CLIENT_BITS-1:0] FSM_CLIENT_LOAD_KEY4         = 10;
  localparam [FSM_CLIENT_BITS-1:0] FSM_CLIENT_WRITE_COUNTER_MSB = 11;
  localparam [FSM_CLIENT_BITS-1:0] FSM_CLIENT_WRITE_COUNTER_LSB = 12;
  localparam [FSM_CLIENT_BITS-1:0] FSM_CLIENT_NOT_FOUND         = 13;
  localparam [FSM_CLIENT_BITS-1:0] FSM_CLIENT_RESET             = 14;

  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------

  reg                       client_counter_lsb_we;
  reg                [31:0] client_counter_lsb_new;
  reg                [31:0] client_counter_lsb_reg;

  reg                       client_counter_msb_we;
  reg                [31:0] client_counter_msb_new;
  reg                [31:0] client_counter_msb_reg;

  reg                       client_keyid_we;
  reg                [31:0] client_keyid_new;
  reg                [31:0] client_keyid_reg;

  reg                       client_out_we;
  reg                [31:0] client_out_data_new;
  reg                [31:0] client_out_data_reg;
  reg                 [2:0] client_out_word_new;
  reg                 [2:0] client_out_word_reg;

                            //Client word/data out valid
  reg                       client_out_valid_new;
  reg                       client_out_valid_reg;

                            //Client interface ready signal
  reg                       client_ready_we;
  reg                       client_ready_new;
  reg                       client_ready_reg;

  reg                       client_search_match_we;
  reg    [SLOT_ENTRIES-1:0] client_search_match_new;
  reg    [SLOT_ENTRIES-1:0] client_search_match_reg;

  reg                       client_slot_we;
  reg                       client_slot_valid_new;
  reg                       client_slot_valid_reg;
  reg  [SLOT_ADDR_BITS-1:0] client_slot_new;
  reg  [SLOT_ADDR_BITS-1:0] client_slot_reg;

  reg                       client_valid_we;
  reg    [SLOT_ENTRIES-1:0] client_valid_new;
  reg    [SLOT_ENTRIES-1:0] client_valid_reg;

  reg                       fsm_client_we;
  reg [FSM_CLIENT_BITS-1:0] fsm_client_new;
  reg [FSM_CLIENT_BITS-1:0] fsm_client_reg;

  reg                       fsm_host_we;
  reg   [FSM_HOST_BITS-1:0] fsm_host_new;
  reg   [FSM_HOST_BITS-1:0] fsm_host_reg;

  reg                       host_busy_we;
  reg                       host_busy_new;
  reg                       host_busy_reg;

  reg                       host_counter_lsb_we;
  reg                [31:0] host_counter_lsb_new;
  reg                [31:0] host_counter_lsb_reg;

  reg                       host_counter_msb_we;
  reg                [31:0] host_counter_msb_new;
  reg                [31:0] host_counter_msb_reg;

  reg                       host_keyid_we;
  reg                [31:0] host_keyid_new;
  reg                [31:0] host_keyid_reg;

  reg                       host_key0_we;
  reg                [31:0] host_key0_new;
  reg                [31:0] host_key0_reg;

  reg                       host_key1_we;
  reg                [31:0] host_key1_new;
  reg                [31:0] host_key1_reg;

  reg                       host_key2_we;
  reg                [31:0] host_key2_new;
  reg                [31:0] host_key2_reg;

  reg                       host_key3_we;
  reg                [31:0] host_key3_new;
  reg                [31:0] host_key3_reg;

  reg                       host_key4_we;
  reg                [31:0] host_key4_new;
  reg                [31:0] host_key4_reg;

  reg                       host_slot_we;
  reg  [SLOT_ADDR_BITS-1:0] host_slot_new;
  reg  [SLOT_ADDR_BITS-1:0] host_slot_reg;

  reg                       reset_counter_we;
  reg [BRAM_ADDR_WIDTH-1:0] reset_counter_new;
  reg [BRAM_ADDR_WIDTH-1:0] reset_counter_reg;

  reg                       search_keyid_we;
  reg  [SLOT_ADDR_BITS-1:0] search_keyid_addr;
  reg                [31:0] search_keyid_new;
  reg [32*SLOT_ENTRIES-1:0] search_keyid_reg;

  reg                       valid_md5_we;
  reg                       valid_md5_new;
  reg    [SLOT_ENTRIES-1:0] valid_md5_reg;

  reg                       valid_sha1_we;
  reg                       valid_sha1_new;
  reg    [SLOT_ENTRIES-1:0] valid_sha1_reg;


  //----------------------------------------------------------------
  // RAM memory
  //----------------------------------------------------------------

  (* ram_style = "block" *)
  reg [31:0] ram [BRAM_ENTRIES-1:0];

  reg                       ram_host_en;
  reg                       ram_host_we;
  reg [BRAM_ADDR_WIDTH-1:0] ram_host_addr;
  reg                [31:0] ram_host_di;
  reg                [31:0] ram_host_do;
  reg                [31:0] ram_host_do_reg;

  reg                       ram_client_en;
  reg                       ram_client_we;
  reg [BRAM_ADDR_WIDTH-1:0] ram_client_addr;
  reg                [31:0] ram_client_di;
  reg                [31:0] ram_client_do;
  reg                [31:0] ram_client_do_reg;

  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------

  reg [31:0] api_read_data;
  reg        load_init;
  reg        load_rst;

  reg host_write_key_id;
  reg host_write_counter_msb;
  reg host_write_counter_lsb;
  reg host_write_key0;
  reg host_write_key1;
  reg host_write_key2;
  reg host_write_key3;
  reg host_write_key4;

  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------

  assign o_read_data = api_read_data;
  assign o_key_word = client_out_word_reg;
  assign o_key_valid = client_out_valid_reg;
  assign o_key_data = client_out_data_reg;
  assign o_ready = client_ready_reg;

  //----------------------------------------------------------------
  // Register Update
  //----------------------------------------------------------------

  always @(posedge i_clk or posedge i_areset)
  begin : reg_update
    if (i_areset) begin
      client_counter_lsb_reg <= 0;
      client_counter_msb_reg <= 0;
      client_keyid_reg <= 0;
      client_out_data_reg <= 0;
      client_out_valid_reg <= 0;
      client_out_word_reg <= 0;
      client_slot_reg <= 0;
      client_slot_valid_reg <= 0;
      client_ready_reg <= 0;
      client_valid_reg <= 0;
      client_search_match_reg <= 0;
      fsm_client_reg <= FSM_CLIENT_RESET;
      fsm_host_reg <= FSM_HOST_RESET;
      host_busy_reg <= 1;
      host_counter_lsb_reg <= 0;
      host_counter_msb_reg <= 0;
      host_keyid_reg <= 0;
      host_key0_reg <= 0;
      host_key1_reg <= 0;
      host_key2_reg <= 0;
      host_key3_reg <= 0;
      host_key4_reg <= 0;
      host_slot_reg <= 0;
      reset_counter_reg <= 0;
      search_keyid_reg <= 0;
      valid_md5_reg <= 0;
      valid_sha1_reg <= 0;
    end else begin
      if (client_counter_lsb_we)
        client_counter_lsb_reg <= client_counter_lsb_new;

      if (client_counter_msb_we)
        client_counter_msb_reg <= client_counter_msb_new;

      if (client_keyid_we)
        client_keyid_reg <= client_keyid_new;

      if (client_out_we)
        client_out_data_reg <= client_out_data_new;

      client_out_valid_reg <= client_out_valid_new;

      if (client_out_we)
        client_out_word_reg <= client_out_word_new;

      if (client_ready_we)
        client_ready_reg <= client_ready_new;

      if (client_search_match_we)
        client_search_match_reg <= client_search_match_new;

      if (client_slot_we) begin
        client_slot_reg <= client_slot_new;
        client_slot_valid_reg <= client_slot_valid_new;
      end

      if (client_valid_we)
        client_valid_reg <= client_valid_new;

      if (fsm_client_we)
        fsm_client_reg <= fsm_client_new;

      if (fsm_host_we)
        fsm_host_reg <= fsm_host_new;

      if (host_busy_we)
        host_busy_reg <= host_busy_new;

      if (host_counter_lsb_we)
        host_counter_lsb_reg <= host_counter_lsb_new;

      if (host_counter_msb_we)
        host_counter_msb_reg <= host_counter_msb_new;

      if (host_keyid_we)
        host_keyid_reg <= host_keyid_new;

      if (host_key0_we)
        host_key0_reg <= host_key0_new;

      if (host_key1_we)
        host_key1_reg <= host_key1_new;

      if (host_key2_we)
        host_key2_reg <= host_key2_new;

      if (host_key3_we)
        host_key3_reg <= host_key3_new;

      if (host_key4_we)
        host_key4_reg <= host_key4_new;

      if (host_slot_we)
        host_slot_reg <= host_slot_new;

      if (reset_counter_we)
        reset_counter_reg <= reset_counter_new;

      if (search_keyid_we)
        search_keyid_reg[32*search_keyid_addr+:32] <= search_keyid_new;

      if (valid_md5_we)
        valid_md5_reg[ host_slot_reg ] <= valid_md5_new;

      if (valid_sha1_we)
        valid_sha1_reg[ host_slot_reg ] <= valid_sha1_new;
    end
  end

  //----------------------------------------------------------------
  // API. Interface for communication with host
  //----------------------------------------------------------------

 always @*
 begin : api
   host_slot_we = 0;
   host_slot_new = 0;
   api_read_data = 32'h0;
   load_init = 0;
   load_rst = 0;
   host_write_key_id = 0;
   host_write_counter_msb = 0;
   host_write_counter_lsb = 0;
   host_write_key0 = 0;
   host_write_key1 = 0;
   host_write_key2 = 0;
   host_write_key3 = 0;
   host_write_key4 = 0;
   valid_md5_we = 0;
   valid_md5_new = 0;
   valid_sha1_we = 0;
   valid_sha1_new = 0;

   if (i_cs) begin
     if (i_we) begin
       case (i_address)
         ADDR_ACTIVE_SLOT:
           begin
             host_slot_we = 1;
             host_slot_new = i_write_data[SLOT_ADDR_BITS-1:0];
             load_rst = 1;
           end
         ADDR_LOAD: load_init = i_write_data[0];
         ADDR_MD5_SHA1:
           begin
             valid_md5_we = 1;
             valid_sha1_we = 1;
             { valid_sha1_new, valid_md5_new } = i_write_data[1:0];
           end
         ADDR_KEYID:       host_write_key_id = 1;
         ADDR_COUNTER_MSB: host_write_counter_msb = 1;
         ADDR_COUNTER_LSB: host_write_counter_lsb = 1;
         ADDR_KEY0:        host_write_key0 = 1;
         ADDR_KEY1:        host_write_key1 = 1;
         ADDR_KEY2:        host_write_key2 = 1;
         ADDR_KEY3:        host_write_key3 = 1;
         ADDR_KEY4:        host_write_key4 = 1;
         default: ;
       endcase
     end else begin
       case (i_address)
         ADDR_NAME0:       api_read_data = CORE_NAME0;
         ADDR_NAME1:       api_read_data = CORE_NAME1;
         ADDR_VERSION:     api_read_data = CORE_VERSION;
         ADDR_ACTIVE_SLOT: api_read_data[SLOT_ADDR_BITS-1:0] = host_slot_reg;
         ADDR_SLOTS:       api_read_data = SLOT_ENTRIES;
         ADDR_BUSY:        api_read_data[0]   = host_busy_reg;
         ADDR_MD5_SHA1:    api_read_data[1:0] = { valid_sha1_reg[ host_slot_reg ],  valid_md5_reg[ host_slot_reg ] };
         ADDR_KEYID:       api_read_data = host_keyid_reg;
         ADDR_COUNTER_MSB: api_read_data = host_counter_msb_reg;
         ADDR_COUNTER_LSB: api_read_data = host_counter_lsb_reg;
         ADDR_KEY0:        api_read_data = host_key0_reg;
         ADDR_KEY1:        api_read_data = host_key1_reg;
         ADDR_KEY2:        api_read_data = host_key2_reg;
         ADDR_KEY3:        api_read_data = host_key3_reg;
         ADDR_KEY4:        api_read_data = host_key4_reg;
         default: ;
       endcase
     end
   end
 end

  //----------------------------------------------------------------
  // Register file.
  //  A registered mirror of the information in the RAM.
  //----------------------------------------------------------------

 always @*
 begin : register_file
   host_keyid_we = 0;
   host_keyid_new = 0;
   host_counter_msb_we = 0;
   host_counter_msb_new = 0;
   host_counter_lsb_we = 0;
   host_counter_lsb_new = 0;
   host_key0_we = 0;
   host_key0_new = 0;
   host_key1_we = 0;
   host_key1_new = 0;
   host_key2_we = 0;
   host_key2_new = 0;
   host_key3_we = 0;
   host_key3_new = 0;
   host_key4_we = 0;
   host_key4_new = 0;
   search_keyid_we = 0;
   search_keyid_addr = 0;
   search_keyid_new = 0;

   case (fsm_host_reg)
     FSM_HOST_LOAD_KEY_ID + 2:      { host_keyid_we,       host_keyid_new       } = { 1'b1, ram_host_do_reg };
     FSM_HOST_LOAD_COUNTER_MSB + 2: { host_counter_msb_we, host_counter_msb_new } = { 1'b1, ram_host_do_reg };
     FSM_HOST_LOAD_COUNTER_LSB + 2: { host_counter_lsb_we, host_counter_lsb_new } = { 1'b1, ram_host_do_reg };
     FSM_HOST_LOAD_KEY0 + 2:        { host_key0_we,        host_key0_new        } = { 1'b1, ram_host_do_reg };
     FSM_HOST_LOAD_KEY1 + 2:        { host_key1_we,        host_key1_new        } = { 1'b1, ram_host_do_reg };
     FSM_HOST_LOAD_KEY2 + 2:        { host_key2_we,        host_key2_new        } = { 1'b1, ram_host_do_reg };
     FSM_HOST_LOAD_KEY3 + 2:        { host_key3_we,        host_key3_new        } = { 1'b1, ram_host_do_reg };
     FSM_HOST_LOAD_KEY4 + 2:        { host_key4_we,        host_key4_new        } = { 1'b1, ram_host_do_reg };
     default: ;
   endcase

   case (fsm_host_reg)
     FSM_HOST_RESET:
       begin
         search_keyid_we = 1;
         search_keyid_addr = reset_counter_reg[3+:SLOT_ADDR_BITS];
         search_keyid_new = 0;
       end
     default: ;
   endcase


   if (host_write_counter_lsb)
     begin
       host_counter_lsb_we = 1;
       host_counter_lsb_new = i_write_data;
     end

   if (host_write_counter_msb)
     begin
       host_counter_msb_we = 1;
       host_counter_msb_new = i_write_data;
     end

   if (host_write_key_id)
     begin
       host_keyid_we = 1;
       host_keyid_new = i_write_data;
       search_keyid_we = 1;
       search_keyid_addr = host_slot_reg;
       search_keyid_new = i_write_data;
     end

   if (host_write_key0)
     begin
       host_key0_we = 1;
       host_key0_new = i_write_data;
     end

   if (host_write_key1)
     begin
       host_key1_we = 1;
       host_key1_new = i_write_data;
     end

   if (host_write_key2)
     begin
       host_key2_we = 1;
       host_key2_new = i_write_data;
     end

   if (host_write_key3)
     begin
       host_key3_we = 1;
       host_key3_new = i_write_data;
     end

   if (host_write_key4)
     begin
       host_key4_we = 1;
       host_key4_new = i_write_data;
    end

   if (load_rst)
    begin
       host_keyid_we = 1;
       host_keyid_new = 0;
       host_counter_msb_we = 1;
       host_counter_msb_new = 0;
       host_counter_lsb_we = 1;
       host_counter_lsb_new = 0;
       host_key0_we = 1;
       host_key0_new = 0;
       host_key1_we = 1;
       host_key1_new = 0;
       host_key2_we = 1;
       host_key2_new = 0;
       host_key3_we = 1;
       host_key3_new = 0;
       host_key4_we = 1;
       host_key4_new = 0;
    end
  end

  //----------------------------------------------------------------
  // RAM host control
  //----------------------------------------------------------------

  always @*
  begin
    ram_host_en = 0;
    ram_host_we = 0;
    ram_host_addr = 0;
    ram_host_di = 0;
    case (fsm_host_reg)
      FSM_HOST_IDLE:
        begin
          if (host_write_key_id)
            begin
              ram_host_en = 1;
              ram_host_we = 1;
              ram_host_addr = { host_slot_reg, 3'h0 };
              ram_host_di = i_write_data;
            end

          if (host_write_counter_msb)
            begin
              ram_host_en = 1;
              ram_host_we = 1;
              ram_host_addr = { host_slot_reg, 3'h1 };
              ram_host_di = i_write_data;
            end

          if (host_write_counter_lsb)
            begin
              ram_host_en = 1;
              ram_host_we = 1;
              ram_host_addr = { host_slot_reg, 3'h2 };
              ram_host_di = i_write_data;
            end

         if (host_write_key0)
           begin
              ram_host_en = 1;
              ram_host_we = 1;
              ram_host_addr = { host_slot_reg, 3'h3 };
              ram_host_di = i_write_data;
           end

         if (host_write_key1)
           begin
              ram_host_en = 1;
              ram_host_we = 1;
              ram_host_addr = { host_slot_reg, 3'h4 };
              ram_host_di = i_write_data;
           end

         if (host_write_key2)
           begin
              ram_host_en = 1;
              ram_host_we = 1;
              ram_host_addr = { host_slot_reg, 3'h5 };
              ram_host_di = i_write_data;
           end

         if (host_write_key3)
           begin
              ram_host_en = 1;
              ram_host_we = 1;
              ram_host_addr = { host_slot_reg, 3'h6 };
              ram_host_di = i_write_data;
           end

         if (host_write_key4)
           begin
              ram_host_en = 1;
              ram_host_we = 1;
              ram_host_addr = { host_slot_reg, 3'h7 };
              ram_host_di = i_write_data;
           end
        end
      FSM_HOST_LOAD_KEY_ID:
        begin
          ram_host_en = 1;
          ram_host_addr = { host_slot_reg, 3'h0 };
        end
      FSM_HOST_LOAD_COUNTER_MSB:
        begin
          ram_host_en = 1;
          ram_host_addr = { host_slot_reg, 3'h1 };
        end
      FSM_HOST_LOAD_COUNTER_LSB:
        begin
          ram_host_en = 1;
          ram_host_addr = { host_slot_reg, 3'h2 };
        end
      FSM_HOST_LOAD_KEY0:
        begin
          ram_host_en = 1;
          ram_host_addr = { host_slot_reg, 3'h3 };
        end
      FSM_HOST_LOAD_KEY1:
        begin
          ram_host_en = 1;
          ram_host_addr = { host_slot_reg, 3'h4 };
        end
      FSM_HOST_LOAD_KEY2:
        begin
          ram_host_en = 1;
          ram_host_addr = { host_slot_reg, 3'h5 };
        end
      FSM_HOST_LOAD_KEY3:
        begin
          ram_host_en = 1;
          ram_host_addr = { host_slot_reg, 3'h6 };
        end
      FSM_HOST_LOAD_KEY4:
        begin
          ram_host_en = 1;
          ram_host_addr = { host_slot_reg, 3'h7 };
        end
      FSM_HOST_RESET:
        begin
          ram_host_en = 1;
          ram_host_we = 1;
          ram_host_addr = reset_counter_reg;
          ram_host_di = 0;
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // RAM client control
  //----------------------------------------------------------------

  always @*
  begin : client_ram
    ram_client_en = 0;
    ram_client_we = 0;
    ram_client_addr = 0;
    ram_client_di = 0;

    case (fsm_client_reg)
      FSM_CLIENT_LOAD_COUNTER_MSB:
        begin
          ram_client_en = 1;
          ram_client_addr = { client_slot_reg, 3'h1 };
        end
      FSM_CLIENT_LOAD_COUNTER_LSB:
        begin
          ram_client_en = 1;
          ram_client_addr = { client_slot_reg, 3'h2 };
        end
      FSM_CLIENT_LOAD_KEY0:
        begin
          ram_client_en = 1;
          ram_client_addr = { client_slot_reg, 3'h3 };
        end
      FSM_CLIENT_LOAD_KEY1:
        begin
          ram_client_en = 1;
          ram_client_addr = { client_slot_reg, 3'h4 };
        end
      FSM_CLIENT_LOAD_KEY2:
        begin
          ram_client_en = 1;
          ram_client_addr = { client_slot_reg, 3'h5 };
        end
      FSM_CLIENT_LOAD_KEY3:
        begin
          ram_client_en = 1;
          ram_client_addr = { client_slot_reg, 3'h6 };
        end
      FSM_CLIENT_LOAD_KEY4:
        begin
          ram_client_en = 1;
          ram_client_addr = { client_slot_reg, 3'h7 };
        end
      FSM_CLIENT_WRITE_COUNTER_MSB:
        begin
          ram_client_en = 1;
          ram_client_we = 1;
          ram_client_addr = { client_slot_reg, 3'h1 };
          ram_client_di = client_counter_msb_reg;
        end
      FSM_CLIENT_WRITE_COUNTER_LSB:
        begin
          ram_client_en = 1;
          ram_client_we = 1;
          ram_client_addr = { client_slot_reg, 3'h2 };
          ram_client_di = client_counter_lsb_reg;
        end
      default: ;
    endcase

  end

  //----------------------------------------------------------------
  // Host FSM
  //----------------------------------------------------------------

  always @*
  begin
    fsm_host_we = 0;
    fsm_host_new = 0;
    host_busy_we = 0;
    host_busy_new = 0;
    reset_counter_we = 0;
    reset_counter_new = 0;

    case (fsm_host_reg)
      FSM_HOST_IDLE:
        if (load_init) begin
          fsm_host_we = 1;
          fsm_host_new = FSM_HOST_LOAD_KEY_ID;
          host_busy_we = 1;
          host_busy_new = 1;
        end
      FSM_HOST_LOAD_KEY_ID:      { fsm_host_we, fsm_host_new } = { 1'b1, FSM_HOST_LOAD_COUNTER_MSB };
      FSM_HOST_LOAD_COUNTER_MSB: { fsm_host_we, fsm_host_new } = { 1'b1, FSM_HOST_LOAD_COUNTER_LSB };
      FSM_HOST_LOAD_COUNTER_LSB: { fsm_host_we, fsm_host_new } = { 1'b1, FSM_HOST_LOAD_KEY0 };
      FSM_HOST_LOAD_KEY0:        { fsm_host_we, fsm_host_new } = { 1'b1, FSM_HOST_LOAD_KEY1 };
      FSM_HOST_LOAD_KEY1:        { fsm_host_we, fsm_host_new } = { 1'b1, FSM_HOST_LOAD_KEY2 };
      FSM_HOST_LOAD_KEY2:        { fsm_host_we, fsm_host_new } = { 1'b1, FSM_HOST_LOAD_KEY3 };
      FSM_HOST_LOAD_KEY3:        { fsm_host_we, fsm_host_new } = { 1'b1, FSM_HOST_LOAD_KEY4 };
      FSM_HOST_LOAD_KEY4:        { fsm_host_we, fsm_host_new } = { 1'b1, FSM_HOST_WAIT0 };
      FSM_HOST_WAIT0:            { fsm_host_we, fsm_host_new } = { 1'b1, FSM_HOST_WAIT1 };
      FSM_HOST_RESET:
        begin
          reset_counter_we = 1;
          reset_counter_new = reset_counter_reg + 1;
          if (reset_counter_reg == { BRAM_ADDR_WIDTH{ 1'b1 } }) begin
            fsm_host_we = 1;
            fsm_host_new = FSM_HOST_IDLE;
            host_busy_we = 1;
            host_busy_new = 0;
          end
        end
      default:
        begin
          fsm_host_we = 1;
          fsm_host_new = FSM_HOST_IDLE;
          host_busy_we = 1;
          host_busy_new = 0;
        end
    endcase
  end

  //----------------------------------------------------------------
  // Client out
  //----------------------------------------------------------------

  always @*
  begin : client_out
    reg [32 + 5 - 1 : 0] tmp;

    case (fsm_client_reg)
      FSM_CLIENT_LOAD_KEY0 + 2: tmp = { 2'b11, 3'b000, ram_client_do_reg };
      FSM_CLIENT_LOAD_KEY1 + 2: tmp = { 2'b11, 3'b001, ram_client_do_reg };
      FSM_CLIENT_LOAD_KEY2 + 2: tmp = { 2'b11, 3'b010, ram_client_do_reg };
      FSM_CLIENT_LOAD_KEY3 + 2: tmp = { 2'b11, 3'b011, ram_client_do_reg };
      FSM_CLIENT_LOAD_KEY4 + 2: tmp = { 2'b11, 3'b100, ram_client_do_reg };
      default: tmp = 0;
    endcase

    client_out_valid_new = tmp[36];
    client_out_we        = tmp[35];
    client_out_data_new  = tmp[31:0];
    client_out_word_new  = tmp[34:32];

  end

  //----------------------------------------------------------------
  // Client counters
  //----------------------------------------------------------------

  always @*
  begin
    client_counter_lsb_we = 0;
    client_counter_lsb_new = 0;
    client_counter_msb_we = 0;
    client_counter_msb_new = 0;
    case (fsm_client_reg)
      FSM_CLIENT_LOAD_COUNTER_MSB + 2:
        begin
          client_counter_msb_we = 1;
          client_counter_msb_new = ram_client_do_reg;
        end
      FSM_CLIENT_LOAD_COUNTER_LSB + 2:
        begin
          client_counter_lsb_we = 1;
          client_counter_lsb_new = ram_client_do_reg;
        end
      FSM_CLIENT_LOAD_COUNTER_LSB + 3:
        begin
          client_counter_lsb_we = 1;
          client_counter_lsb_new = client_counter_lsb_reg + 1;
          if (client_counter_lsb_reg == 32'hffff_ffff) begin
            client_counter_msb_we = 1;
            client_counter_msb_new = client_counter_msb_reg + 1;
          end
        end
      default: ;
    endcase
  end

  //----------------------------------------------------------------
  // Client FSM - Search helper
  //----------------------------------------------------------------

  task search0 ( output [SLOT_ENTRIES-1:0] value );
  begin : search0_
    reg [SLOT_ADDR_BITS:0] i;
    reg [SLOT_ADDR_BITS-1:0] j;

    for (i = 0; i < SLOT_ENTRIES; i = i + 1) begin
      j = i[SLOT_ADDR_BITS-1:0];
      if (search_keyid_reg[32*j+:32] == client_keyid_reg) begin
        value[j] = client_valid_reg[j];
      end else begin
        value[j] = 0;
      end
    end
  end
  endtask

  //----------------------------------------------------------------
  // Client FSM - Search helper
  //----------------------------------------------------------------

  task search1 (output valid, output [SLOT_ADDR_BITS-1:0] value );
  begin : search1_
    reg [SLOT_ADDR_BITS:0] i;
    reg [SLOT_ADDR_BITS-1:0] j;

    valid = 0;
    value = 0;
    for (i = 0; i < SLOT_ENTRIES; i = i + 1) begin
      j = i[SLOT_ADDR_BITS-1:0];
      if (client_search_match_reg[j]) begin
        valid = 1;
        value = j;
      end
    end
  end
  endtask

  //----------------------------------------------------------------
  // Client FSM
  //----------------------------------------------------------------

  always @*
  begin : client_fsm

    client_ready_we = 0;
    client_ready_new = 0;
    client_keyid_we = 0;
    client_keyid_new = 0;
    client_valid_we = 0;
    client_valid_new = 0;
    client_search_match_we = 0;
    client_search_match_new = 0;
    client_slot_we = 0;
    client_slot_valid_new = 0;
    client_slot_new = 0;
    fsm_client_we = 0;
    fsm_client_we = 0;
    fsm_client_new = 0;

    case (fsm_client_reg)
      FSM_CLIENT_IDLE:
        if (i_get_key_md5 || i_get_key_sha1) begin
          client_keyid_we = 1;
          client_keyid_new = i_keyid;
          client_ready_we = 1;
          client_ready_new = 0;
          fsm_client_we = 1;
          fsm_client_new = FSM_CLIENT_SEARCH_0;

          if (i_get_key_md5) begin
            client_valid_we = 1;
            client_valid_new = valid_md5_reg;
          end else if (i_get_key_sha1) begin
            client_valid_we = 1;
            client_valid_new = valid_sha1_reg;
          end
        end
      FSM_CLIENT_SEARCH_0:
        begin
          fsm_client_we = 1;
          fsm_client_new = FSM_CLIENT_SEARCH_1;
          client_search_match_we = 1;
          search0 ( client_search_match_new );
        end
      FSM_CLIENT_SEARCH_1:
        begin
          fsm_client_we = 1;
          fsm_client_new = FSM_CLIENT_SEARCH_2;
          client_slot_we = 1;
          search1( client_slot_valid_new, client_slot_new );
        end
      FSM_CLIENT_SEARCH_2:
        if (client_slot_valid_reg) begin
          fsm_client_we = 1;
          fsm_client_new = FSM_CLIENT_LOAD_COUNTER_MSB;
        end else begin
          fsm_client_we = 1;
          fsm_client_new = FSM_CLIENT_NOT_FOUND;
        end
      FSM_CLIENT_LOAD_COUNTER_MSB:
        begin
          fsm_client_we = 1;
          fsm_client_new = FSM_CLIENT_LOAD_COUNTER_LSB;
        end
      FSM_CLIENT_LOAD_COUNTER_LSB:
        begin
          fsm_client_we = 1;
          fsm_client_new = FSM_CLIENT_LOAD_KEY0;
        end
      FSM_CLIENT_LOAD_KEY0:
        begin
          fsm_client_we = 1;
          fsm_client_new = FSM_CLIENT_LOAD_KEY1;
        end
      FSM_CLIENT_LOAD_KEY1:
        begin
          fsm_client_we = 1;
          fsm_client_new = FSM_CLIENT_LOAD_KEY2;
        end
      FSM_CLIENT_LOAD_KEY2:
        begin
          fsm_client_we = 1;
          fsm_client_new = FSM_CLIENT_LOAD_KEY3;
        end
      FSM_CLIENT_LOAD_KEY3:
        begin
          fsm_client_we = 1;
          fsm_client_new = FSM_CLIENT_LOAD_KEY4;
        end
      FSM_CLIENT_LOAD_KEY4:
        begin
          fsm_client_we = 1;
          fsm_client_new = FSM_CLIENT_WRITE_COUNTER_MSB;
        end
      FSM_CLIENT_WRITE_COUNTER_MSB:
        begin
          fsm_client_we = 1;
          fsm_client_new = FSM_CLIENT_WRITE_COUNTER_LSB;
        end
      FSM_CLIENT_WRITE_COUNTER_LSB:
        begin
          client_ready_we = 1;
          client_ready_new = 1;
          fsm_client_we = 1;
          fsm_client_new = FSM_CLIENT_IDLE;
        end
      FSM_CLIENT_RESET:
        if (fsm_host_reg != FSM_HOST_RESET) begin
          client_ready_we = 1;
          client_ready_new = 1;
          fsm_client_we = 1;
          fsm_client_new = FSM_CLIENT_IDLE;
        end
      default:
        begin
          client_ready_we = 1;
          client_ready_new = 1;
          fsm_client_we = 1;
          fsm_client_new = FSM_CLIENT_IDLE;
        end
    endcase

  end

  //----------------------------------------------------------------
  // RAM
  //----------------------------------------------------------------

  always @(posedge i_clk)
  begin
    ram_host_do_reg <= ram_host_do;
    if (ram_host_en)
      begin
        if (ram_host_we)
          ram[ram_host_addr] <= ram_host_di;
        ram_host_do <= ram[ram_host_addr];
      end
  end

  always @(posedge i_clk)
  begin
    ram_client_do_reg <= ram_client_do;
    if (ram_client_en)
      begin
        if (ram_client_we)
          ram[ram_client_addr] <= ram_client_di;
        ram_client_do <= ram[ram_client_addr];
      end
  end


endmodule
