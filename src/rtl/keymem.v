//======================================================================
//
// keymem.v
// --------
// key memory for the NTS engine. Supports four separate keys,
// with key usage counters.
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

module keymem(
              input wire           clk,
              input wire           areset,

              // API access
              input wire           cs,
              input wire           we,
              input wire  [7 : 0]  address,
              input wire  [31 : 0] write_data,
              output wire [31 : 0] read_data,

              // Client access
              input wire           get_current_key,
              input wire           get_key_with_id,
              input wire  [31 : 0] server_key_id,
              input wire  [3 : 0]  key_word,
              output wire          key_valid,
              output wire          key_length,
              output wire [31 : 0] key_id,
              output wire [31 : 0] key_data,
              output wire          ready
             );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
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

  localparam CORE_NAME0         = 32'h6b65795f; // "key_"
  localparam CORE_NAME1         = 32'h6d656d20; // "mem "
  localparam CORE_VERSION       = 32'h302e3130; // "0.10"

  localparam CTRL_IDLE          = 1'h0;
  localparam CTRL_DONE          = 1'h1;

  localparam KW0 = ADDR_KEY0_END - ADDR_KEY0_START;
  localparam KW1 = ADDR_KEY1_END - ADDR_KEY1_START;
  localparam KW2 = ADDR_KEY2_END - ADDR_KEY2_START;
  localparam KW3 = ADDR_KEY3_END - ADDR_KEY3_START;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [31 : 0] key0 [0 : 15];
  reg          key0_we;

  reg [31 : 0] key0_id_reg;
  reg          key0_id_we;

  reg          key0_valid_reg;

  reg          key0_length_reg;
  reg          key0_length_we;

  reg [31 : 0] key0_ctr_reg;
  reg [31 : 0] key0_ctr_new;
  reg          key0_ctr_rst;
  reg          key0_ctr_inc;
  reg          key0_ctr_we;


  reg [31 : 0] key1 [0 : 15];
  reg          key1_we;

  reg [31 : 0] key1_id_reg;
  reg          key1_id_we;

  reg          key1_valid_reg;

  reg          key1_length_reg;
  reg          key1_length_we;

  reg [31 : 0] key1_ctr_reg;
  reg [31 : 0] key1_ctr_new;
  reg          key1_ctr_rst;
  reg          key1_ctr_inc;
  reg          key1_ctr_we;


  reg [31 : 0] key2 [0 : 15];
  reg          key2_we;

  reg [31 : 0] key2_id_reg;
  reg          key2_id_we;

  reg          key2_valid_reg;

  reg          key2_length_reg;
  reg          key2_length_we;

  reg [31 : 0] key2_ctr_reg;
  reg [31 : 0] key2_ctr_new;
  reg          key2_ctr_rst;
  reg          key2_ctr_inc;
  reg          key2_ctr_we;


  reg [31 : 0] key3 [0 : 15];
  reg          key3_we;

  reg [31 : 0] key3_id_reg;
  reg          key3_id_we;

  reg          key3_valid_reg;

  reg          key3_length_reg;
  reg          key3_length_we;

  reg [31 : 0] key3_ctr_reg;
  reg [31 : 0] key3_ctr_new;
  reg          key3_ctr_rst;
  reg          key3_ctr_inc;
  reg          key3_ctr_we;

  reg [31 : 0] error_ctr_reg;
  reg [31 : 0] error_ctr_new;
  reg          error_ctr_rst;
  reg          error_ctr_inc;
  reg          error_ctr_we;

  reg          key_valid_reg;
  reg          key_valid_new;
  reg          key_valid_we;

  reg [1 : 0]  mux_ctrl_reg;
  reg [1 : 0]  mux_ctrl_new;
  reg          mux_ctrl_we;

  reg [1 : 0]  current_key_reg;
  reg          current_key_we;

  reg          ready_reg;
  reg          ready_new;
  reg          ready_we;

  reg          keymem_ctrl_reg;
  reg          keymem_ctrl_new;
  reg          keymem_ctrl_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [31 : 0] tmp_read_data;

  reg          muxed_key_length;
  reg [31 : 0] muxed_key_id;
  reg [31 : 0] muxed_key_data;

  reg          set_current_key;
  reg          set_key_with_id;

  reg          valid_keys_we;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign read_data  = tmp_read_data;
  assign key_valid  = key_valid_reg;
  assign key_length = muxed_key_length;
  assign key_id     = muxed_key_id;
  assign key_data   = muxed_key_data;
  assign ready      = ready_reg;


  //----------------------------------------------------------------
  // reg_update
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset.
  //----------------------------------------------------------------
  always @ (posedge clk or posedge areset)
    begin : reg_update
      integer i;

      if (areset)
        begin
          for (i = 0 ; i < 4 ; i = i + 1)
            begin
              key0[i] <= 32'h0;
              key1[i] <= 32'h0;
              key2[i] <= 32'h0;
              key3[i] <= 32'h0;
            end

          key0_id_reg     <= 32'h0;
          key1_id_reg     <= 32'h0;
          key2_id_reg     <= 32'h0;
          key3_id_reg     <= 32'h0;

          key0_valid_reg  <= 1'h0;
          key1_valid_reg  <= 1'h0;
          key2_valid_reg  <= 1'h0;
          key3_valid_reg  <= 1'h0;

          key0_length_reg <= 1'h0;
          key1_length_reg <= 1'h0;
          key2_length_reg <= 1'h0;
          key2_length_reg <= 1'h0;

          key0_ctr_reg    <= 32'h0;
          key1_ctr_reg    <= 32'h0;
          key2_ctr_reg    <= 32'h0;
          key3_ctr_reg    <= 32'h0;

          error_ctr_reg   <= 32'h0;
          key_valid_reg   <= 1'h0;
          current_key_reg <= 2'h0;
          mux_ctrl_reg    <= 2'h0;
          ready_reg       <= 1'h0;
          keymem_ctrl_reg <= CTRL_IDLE;
        end
      else
        begin
          if (key0_we)
            key0[address[3 : 0]] <= write_data;

          if (key0_id_we)
            key0_id_reg <= write_data;

          if (key0_length_we)
            key0_length_reg <= write_data[0];

          if (key0_ctr_we)
            key0_ctr_reg <= key0_ctr_new;


          if (key1_we)
            key1[address[3 : 0]] <= write_data;

          if (key1_id_we)
            key1_id_reg <= write_data;

          if (key1_length_we)
            key1_length_reg <= write_data[0];

          if (key1_ctr_we)
            key1_ctr_reg <= key1_ctr_new;


          if (key2_we)
            key2[address[3 : 0]] <= write_data;

          if (key2_id_we)
            key2_id_reg <= write_data;

          if (key2_length_we)
            key2_length_reg <= write_data[0];

          if (key2_ctr_we)
            key2_ctr_reg <= key2_ctr_new;


          if (key3_we)
            key3[address[3 : 0]] <= write_data;

          if (key3_id_we)
            key3_id_reg <= write_data;

          if (key3_length_we)
            key3_length_reg <= write_data[0];

          if (key3_ctr_we)
            key3_ctr_reg <= key3_ctr_new;


          if (error_ctr_we)
            error_ctr_reg <= error_ctr_new;

          if (valid_keys_we)
            begin
              key0_valid_reg <= write_data[0];
              key1_valid_reg <= write_data[1];
              key2_valid_reg <= write_data[2];
              key3_valid_reg <= write_data[3];
            end

          if (key_valid_we)
            key_valid_reg <= key_valid_new;

          if (current_key_we)
            current_key_reg <= write_data[1 : 0];

          if (mux_ctrl_we)
            mux_ctrl_reg <= mux_ctrl_new;

          if (ready_we)
            ready_reg <= ready_new;

          if (keymem_ctrl_we)
            keymem_ctrl_reg <= keymem_ctrl_new;
        end
    end // reg_update


  //----------------------------------------------------------------
  // client_access;
  //----------------------------------------------------------------
  always @*
    begin : client_access
      key0_ctr_inc  = 1'h0;
      key1_ctr_inc  = 1'h0;
      key2_ctr_inc  = 1'h0;
      key3_ctr_inc  = 1'h0;
      error_ctr_inc = 1'h0;
      mux_ctrl_new  = 2'h0;
      mux_ctrl_we   = 1'h0;
      key_valid_new = 1'h0;
      key_valid_we  = 1'h0;

      if (set_current_key)
        begin
          case(current_key_reg)
            0:
              begin
                if (key0_valid_reg)
                  begin
                    mux_ctrl_new  = 2'h0;
                    mux_ctrl_we   = 1'h1;
                    key0_ctr_inc  = 1'h1;
                    key_valid_new = 1'h1;
                    key_valid_we  = 1'h1;
                  end
                else
                  begin
                    error_ctr_inc = 1'h1;
                    key_valid_new = 1'h0;
                    key_valid_we  = 1'h1;
                  end
              end

            1:
              begin
                if (key1_valid_reg)
                  begin
                    mux_ctrl_new  = 2'h1;
                    mux_ctrl_we   = 1'h1;
                    key1_ctr_inc  = 1'h1;
                    key_valid_new = 1'h1;
                    key_valid_we  = 1'h1;
                  end
                else
                  begin
                    error_ctr_inc = 1'h1;
                    key_valid_new = 1'h0;
                    key_valid_we  = 1'h1;
                  end
              end

            2:
              begin
                if (key2_valid_reg)
                  begin
                    mux_ctrl_new  = 2'h2;
                    mux_ctrl_we   = 1'h1;
                    key2_ctr_inc  = 1'h1;
                    key_valid_new = 1'h1;
                    key_valid_we  = 1'h1;
                  end
                else
                  begin
                    error_ctr_inc = 1'h1;
                    key_valid_new = 1'h0;
                    key_valid_we  = 1'h1;
                  end
              end

            3:
              begin
                if (key3_valid_reg)
                  begin
                    mux_ctrl_new  = 2'h3;
                    mux_ctrl_we   = 1'h1;
                    key3_ctr_inc  = 1'h1;
                    key_valid_new = 1'h1;
                    key_valid_we  = 1'h1;
                  end
                else
                  begin
                    error_ctr_inc = 1'h1;
                    key_valid_new = 1'h0;
                    key_valid_we  = 1'h1;
                  end
              end
          endcase // case (current_key_reg)
        end // if (set_current_key)


      if (set_key_with_id)
        begin
          if (server_key_id == key0_id_reg)
            begin
              if (key0_valid_reg)
                begin
                  mux_ctrl_new  = 2'h0;
                  mux_ctrl_we   = 1'h1;
                  key0_ctr_inc  = 1'h1;
                  key_valid_new = 1'h1;
                  key_valid_we  = 1'h1;
                end
              else
                begin
                  error_ctr_inc = 1'h1;
                  key_valid_new = 1'h0;
                  key_valid_we  = 1'h1;
                end
            end

          else if (server_key_id == key1_id_reg)
            begin
              if (key1_valid_reg)
                begin
                  mux_ctrl_new  = 2'h1;
                  mux_ctrl_we   = 1'h1;
                  key1_ctr_inc  = 1'h1;
                  key_valid_new = 1'h1;
                  key_valid_we  = 1'h1;
                end
              else
                begin
                  error_ctr_inc = 1'h1;
                  key_valid_new = 1'h0;
                  key_valid_we  = 1'h1;
                end
            end

          else if (server_key_id == key2_id_reg)
            begin
              if (key2_valid_reg)
                begin
                  mux_ctrl_new  = 2'h2;
                  mux_ctrl_we   = 1'h1;
                  key2_ctr_inc  = 1'h1;
                  key_valid_new = 1'h1;
                  key_valid_we  = 1'h1;
                end
              else
                begin
                  error_ctr_inc = 1'h1;
                  key_valid_new = 1'h0;
                  key_valid_we  = 1'h1;
                end
            end

          else if (server_key_id == key3_id_reg)
            begin
              if (key3_valid_reg)
                begin
                  mux_ctrl_new  = 2'h3;
                  mux_ctrl_we   = 1'h1;
                  key3_ctr_inc  = 1'h1;
                  key_valid_new = 1'h1;
                  key_valid_we  = 1'h1;
                end
              else
                begin
                  error_ctr_inc = 1'h1;
                  key_valid_new = 1'h0;
                  key_valid_we  = 1'h1;
                end
            end

          else
            begin
              error_ctr_inc = 1'h1;
              key_valid_new = 1'h0;
              key_valid_we  = 1'h1;
            end
        end // if (set_key_with_id)


      case (mux_ctrl_reg)
        0:
          begin
            muxed_key_data   = key0[key_word];
            muxed_key_id     = key0_id_reg;
            muxed_key_length = key0_length_reg;
          end

        1:
          begin
            muxed_key_data   = key1[key_word];
            muxed_key_id     = key1_id_reg;
            muxed_key_length = key1_length_reg;
          end

        2:
          begin
            muxed_key_data   = key2[key_word];
            muxed_key_id     = key2_id_reg;
            muxed_key_length = key2_length_reg;
          end

        3:
          begin
            muxed_key_data   = key3[key_word];
            muxed_key_id     = key3_id_reg;
            muxed_key_length = key3_length_reg;
          end
      endcase // case (mux_ctrl_reg)
    end


  //----------------------------------------------------------------
  // counters
  //----------------------------------------------------------------
  always @*
    begin : counters
      key0_ctr_new  = 32'h0;
      key0_ctr_we   = 1'h0;
      key1_ctr_new  = 32'h0;
      key1_ctr_we   = 1'h0;
      key2_ctr_new  = 32'h0;
      key2_ctr_we   = 1'h0;
      key3_ctr_new  = 32'h0;
      key3_ctr_we   = 1'h0;
      error_ctr_new = 32'h0;
      error_ctr_we  = 1'h0;


      if (key0_ctr_rst)
        begin
          key0_ctr_new = 32'h0;
          key0_ctr_we  = 1'h1;
        end

      if (key0_ctr_inc)
        begin
          key0_ctr_new = key0_ctr_reg + 1'h1;
          key0_ctr_we  = 1'h1;
        end

      if (key1_ctr_rst)
        begin
          key1_ctr_new = 32'h0;
          key1_ctr_we  = 1'h1;
        end

      if (key1_ctr_inc)
        begin
          key1_ctr_new = key1_ctr_reg + 1'h1;
          key1_ctr_we  = 1'h1;
        end

      if (key2_ctr_rst)
        begin
          key2_ctr_new = 32'h0;
          key2_ctr_we  = 1'h1;
        end

      if (key2_ctr_inc)
        begin
          key2_ctr_new = key2_ctr_reg + 1'h1;
          key2_ctr_we  = 1'h1;
        end

      if (key3_ctr_rst)
        begin
          key3_ctr_new = 32'h0;
          key3_ctr_we  = 1'h1;
        end

      if (key3_ctr_inc)
        begin
          key3_ctr_new = key3_ctr_reg + 1'h1;
          key3_ctr_we  = 1'h1;
        end

      if (error_ctr_rst)
        begin
          error_ctr_new = 32'h0;
          error_ctr_we  = 1'h1;
        end

      if (error_ctr_inc)
        begin
          error_ctr_new = error_ctr_reg + 1'h1;
          error_ctr_we  = 1'h1;
        end
    end


  //----------------------------------------------------------------
  // api
  //----------------------------------------------------------------
  always @*
    begin : api
      valid_keys_we  = 1'h0;
      current_key_we = 1'h0;
      key0_we        = 1'h0;
      key0_id_we     = 1'h0;
      key0_length_we = 1'h0;
      key0_ctr_rst   = 1'h0;
      key1_we        = 1'h0;
      key1_id_we     = 1'h0;
      key1_length_we = 1'h0;
      key1_ctr_rst   = 1'h0;
      key2_we        = 1'h0;
      key2_id_we     = 1'h0;
      key2_length_we = 1'h0;
      key2_ctr_rst   = 1'h0;
      key3_we        = 1'h0;
      key3_id_we     = 1'h0;
      key3_length_we = 1'h0;
      key3_ctr_rst   = 1'h0;
      error_ctr_rst  = 1'h0;
      tmp_read_data  = 32'h0;

      if (cs)
        begin
          if (we)
            begin
              case (address)
                ADDR_CURRENT_KEY:   current_key_we  = 1'h1;
                ADDR_VALID_KEYS:    valid_keys_we   = 1'h1;
                ADDR_KEY0_ID:       key0_id_we      = 1'h1;
                ADDR_KEY0_LENGTH:   key0_length_we  = 1'h1;
                ADDR_KEY1_ID:       key1_id_we      = 1'h1;
                ADDR_KEY1_LENGTH:   key1_length_we  = 1'h1;
                ADDR_KEY2_ID:       key2_id_we      = 1'h1;
                ADDR_KEY2_LENGTH:   key2_length_we  = 1'h1;
                ADDR_KEY3_ID:       key3_id_we      = 1'h1;
                ADDR_KEY3_LENGTH:   key3_length_we  = 1'h1;
                ADDR_KEY0_COUNTER:  key0_ctr_rst    = 1'h1;
                ADDR_KEY1_COUNTER:  key1_ctr_rst    = 1'h1;
                ADDR_KEY2_COUNTER:  key2_ctr_rst    = 1'h1;
                ADDR_KEY3_COUNTER:  key3_ctr_rst    = 1'h1;
                ADDR_ERROR_COUNTER: error_ctr_rst   = 1'h1;
                default:
                  begin
                  end
              endcase // case (address)

              if ((address >= ADDR_KEY0_START) && (address <= ADDR_KEY0_END))
                key0_we = 1'h1;

              if ((address >= ADDR_KEY1_START) && (address <= ADDR_KEY1_END))
                key1_we = 1'h1;

              if ((address >= ADDR_KEY2_START) && (address <= ADDR_KEY2_END))
                key2_we = 1'h1;

              if ((address >= ADDR_KEY3_START) && (address <= ADDR_KEY3_END))
                key3_we = 1'h1;
            end // if (we)

          else
            begin
              case (address)
                ADDR_NAME0:         tmp_read_data = CORE_NAME0;
                ADDR_NAME1:         tmp_read_data = CORE_NAME1;
                ADDR_VERSION:       tmp_read_data = CORE_VERSION;

                ADDR_CURRENT_KEY:   tmp_read_data = {30'h0, current_key_reg};
                ADDR_VALID_KEYS:    tmp_read_data = {28'h0, key3_valid_reg,
                                                     key2_valid_reg,
                                                     key1_valid_reg,
                                                     key0_valid_reg};

                ADDR_KEY0_ID:       tmp_read_data = key0_id_reg;
                ADDR_KEY0_LENGTH:   tmp_read_data = {31'h0, key0_length_reg};
                ADDR_KEY1_ID:       tmp_read_data = key1_id_reg;
                ADDR_KEY1_LENGTH:   tmp_read_data = {31'h0, key1_length_reg};
                ADDR_KEY2_ID:       tmp_read_data = key2_id_reg;
                ADDR_KEY2_LENGTH:   tmp_read_data = {31'h0, key2_length_reg};
                ADDR_KEY3_ID:       tmp_read_data = key3_id_reg;
                ADDR_KEY3_LENGTH:   tmp_read_data = {31'h0, key3_length_reg};

                ADDR_KEY0_COUNTER:  tmp_read_data = key0_ctr_reg;
                ADDR_KEY1_COUNTER:  tmp_read_data = key1_ctr_reg;
                ADDR_KEY2_COUNTER:  tmp_read_data = key2_ctr_reg;
                ADDR_KEY3_COUNTER:  tmp_read_data = key3_ctr_reg;
                ADDR_ERROR_COUNTER: tmp_read_data = error_ctr_reg;

                default:
                  begin
                  end
              endcase // case (address)

              if ((address >= ADDR_KEY0_START) && (address <= ADDR_KEY0_END))
                tmp_read_data = key0[address[3 : 0]];

              if ((address >= ADDR_KEY1_START) && (address <= ADDR_KEY1_END))
                tmp_read_data = key1[address[3 : 0]];

              if ((address >= ADDR_KEY2_START) && (address <= ADDR_KEY2_END))
                tmp_read_data = key2[address[3 : 0]];

              if ((address >= ADDR_KEY3_START) && (address <= ADDR_KEY3_END))
                tmp_read_data = key3[address[3 : 0]];

            end // else: !if(we)
        end
    end // api


  //----------------------------------------------------------------
  // keymem_ctrl
  //----------------------------------------------------------------
  always @*
    begin : keymem_ctrl
      set_current_key = 1'h0;
      set_key_with_id = 1'h0;
      ready_new       = 1'h0;
      ready_we        = 1'h0;
      keymem_ctrl_new = CTRL_IDLE;
      keymem_ctrl_we  = 1'h0;


      case (keymem_ctrl_reg)
        CTRL_IDLE:
          begin
            if (get_current_key)
              begin
                ready_new       = 1'h0;
                ready_we        = 1'h1;
                set_current_key = 1'h1;
                keymem_ctrl_new = CTRL_DONE;
                keymem_ctrl_we  = 1'h1;
              end

            if (get_key_with_id)
              begin
                ready_new       = 1'h0;
                ready_we        = 1'h1;
                set_key_with_id = 1'h1;
                keymem_ctrl_new = CTRL_DONE;
                keymem_ctrl_we  = 1'h1;
              end
          end

        CTRL_DONE:
          begin
            ready_new       = 1'h1;
            ready_we        = 1'h1;
            set_current_key = 1'h1;
            keymem_ctrl_new = CTRL_IDLE;
            keymem_ctrl_we  = 1'h1;
          end
      endcase // case (keymem_ctrl_reg)
    end // block: keymem_ctrl

endmodule // keymem

//======================================================================
// EOF keymem.v
//======================================================================
