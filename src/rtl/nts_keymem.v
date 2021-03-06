//======================================================================
//
// nts_keymem.v
// ------------
// key memory for the NTS engine. Supports four separate keys,
// with key usage counters.
//
//
// Author: Joachim Strombergson
//
//
// Copyright 2019 Netnod Internet Exchange i Sverige AB
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
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived
//    from this software without specific prior written permission.
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

module nts_keymem(
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
              input wire  [2 : 0]  key_word,
              output wire          key_valid,
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

  localparam ADDR_CTRL          = 8'h08;
  localparam CTRL_KEY0_VALID    = 0;
  localparam CTRL_KEY1_VALID    = 1;
  localparam CTRL_KEY2_VALID    = 2;
  localparam CTRL_KEY3_VALID    = 3;
  localparam CTRL_CURR_LOW      = 16;
  localparam CTRL_CURR_HIGH     = 17;

  localparam ADDR_KEY0_ID       = 8'h10;

  localparam ADDR_KEY1_ID       = 8'h12;

  localparam ADDR_KEY2_ID       = 8'h14;

  localparam ADDR_KEY3_ID       = 8'h16;

  localparam ADDR_KEY0_COUNTER_MSB  = 8'h30;
  localparam ADDR_KEY0_COUNTER_LSB  = 8'h31;
  localparam ADDR_KEY1_COUNTER_MSB  = 8'h32;
  localparam ADDR_KEY1_COUNTER_LSB  = 8'h33;
  localparam ADDR_KEY2_COUNTER_MSB  = 8'h34;
  localparam ADDR_KEY2_COUNTER_LSB  = 8'h35;
  localparam ADDR_KEY3_COUNTER_MSB  = 8'h36;
  localparam ADDR_KEY3_COUNTER_LSB  = 8'h37;
  localparam ADDR_ERROR_COUNTER_MSB = 8'h38;
  localparam ADDR_ERROR_COUNTER_LSB = 8'h39;

  localparam ADDR_KEY0_START    = 8'h40;
  localparam ADDR_KEY0_END      = 8'h47;

  localparam ADDR_KEY1_START    = 8'h50;
  localparam ADDR_KEY1_END      = 8'h57;

  localparam ADDR_KEY2_START    = 8'h60;
  localparam ADDR_KEY2_END      = 8'h67;

  localparam ADDR_KEY3_START    = 8'h70;
  localparam ADDR_KEY3_END      = 8'h77;

  localparam CORE_NAME0   = 32'h6b65795f; // "key_"
  localparam CORE_NAME1   = 32'h6d656d20; // "mem "
  localparam CORE_VERSION = 32'h302e3131; // "0.11"

  localparam CTRL_IDLE = 1'h0;
  localparam CTRL_DONE = 1'h1;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [31 : 0] key0 [0 : 7];
  reg          key0_we;

  reg [31 : 0] key0_id_reg;
  reg          key0_id_we;

  reg          key0_valid_reg;

  reg [63 : 0] key0_ctr_reg;
  reg [63 : 0] key0_ctr_new;
  reg          key0_ctr_rst;
  reg          key0_ctr_inc;
  reg          key0_ctr_we;

  reg [31 : 0] key0_ctr_lsb_reg;
  reg          key0_ctr_lsb_we;

  reg [31 : 0] key1 [0 : 7];
  reg          key1_we;

  reg [31 : 0] key1_id_reg;
  reg          key1_id_we;

  reg          key1_valid_reg;

  reg [63 : 0] key1_ctr_reg;
  reg [63 : 0] key1_ctr_new;
  reg          key1_ctr_rst;
  reg          key1_ctr_inc;
  reg          key1_ctr_we;

  reg [31 : 0] key1_ctr_lsb_reg;
  reg          key1_ctr_lsb_we;

  reg [31 : 0] key2 [0 : 7];
  reg          key2_we;

  reg [31 : 0] key2_id_reg;
  reg          key2_id_we;

  reg          key2_valid_reg;

  reg [63 : 0] key2_ctr_reg;
  reg [63 : 0] key2_ctr_new;
  reg          key2_ctr_rst;
  reg          key2_ctr_inc;
  reg          key2_ctr_we;

  reg [31 : 0] key2_ctr_lsb_reg;
  reg          key2_ctr_lsb_we;

  reg [31 : 0] key3 [0 : 7];
  reg          key3_we;

  reg [31 : 0] key3_id_reg;
  reg          key3_id_we;

  reg          key3_valid_reg;

  reg [63 : 0] key3_ctr_reg;
  reg [63 : 0] key3_ctr_new;
  reg          key3_ctr_rst;
  reg          key3_ctr_inc;
  reg          key3_ctr_we;

  reg [31 : 0] key3_ctr_lsb_reg;
  reg          key3_ctr_lsb_we;

  reg [63 : 0] error_ctr_reg;
  reg [63 : 0] error_ctr_new;
  reg          error_ctr_rst;
  reg          error_ctr_inc;
  reg          error_ctr_we;

  reg [31 : 0] error_ctr_lsb_reg;
  reg          error_ctr_lsb_we;

  reg          key_valid_reg;
  reg          key_valid_new;
  reg          key_valid_we;

  reg [1 : 0]  mux_ctrl_reg;
  reg [1 : 0]  mux_ctrl_new;
  reg          mux_ctrl_we;

  reg [1 : 0]  current_key_reg;

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

  reg [31 : 0] muxed_key_id;
  reg [31 : 0] muxed_key_data;

  reg          set_current_key;
  reg          set_key_with_id;

  reg          key_ctrl_we;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign read_data  = tmp_read_data;
  assign key_valid  = key_valid_reg;
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
          for (i = 0 ; i < 8 ; i = i + 1)
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

          key0_ctr_reg      <= 64'h0;
          key0_ctr_lsb_reg  <= 32'h0;
          key1_ctr_reg      <= 64'h0;
          key1_ctr_lsb_reg  <= 32'h0;
          key2_ctr_reg      <= 64'h0;
          key2_ctr_lsb_reg  <= 32'h0;
          key3_ctr_reg      <= 64'h0;
          key3_ctr_lsb_reg  <= 32'h0;
          error_ctr_reg     <= 64'h0;
          error_ctr_lsb_reg <= 32'h0;

          key_valid_reg   <= 1'h0;
          current_key_reg <= 2'h0;
          mux_ctrl_reg    <= 2'h0;
          ready_reg       <= 1'h1;
          keymem_ctrl_reg <= CTRL_IDLE;
        end
      else
        begin
          if (key0_we)
            key0[address[2 : 0]] <= write_data;

          if (key0_id_we)
            key0_id_reg <= write_data;

          if (key0_ctr_we)
            key0_ctr_reg <= key0_ctr_new;

          if (key0_ctr_lsb_we)
            key0_ctr_lsb_reg <= key0_ctr_reg[31:0];


          if (key1_we)
            key1[address[2 : 0]] <= write_data;

          if (key1_id_we)
            key1_id_reg <= write_data;

          if (key1_ctr_we)
            key1_ctr_reg <= key1_ctr_new;

          if (key1_ctr_lsb_we)
            key1_ctr_lsb_reg <= key1_ctr_reg[31:0];


          if (key2_we)
            key2[address[2 : 0]] <= write_data;

          if (key2_id_we)
            key2_id_reg <= write_data;

          if (key2_ctr_we)
            key2_ctr_reg <= key2_ctr_new;

          if (key2_ctr_lsb_we)
            key2_ctr_lsb_reg <= key2_ctr_reg[31:0];


          if (key3_we)
            key3[address[2 : 0]] <= write_data;

          if (key3_id_we)
            key3_id_reg <= write_data;

          if (key3_ctr_we)
            key3_ctr_reg <= key3_ctr_new;

          if (key3_ctr_lsb_we)
            key3_ctr_lsb_reg <= key3_ctr_reg[31:0];


          if (error_ctr_we)
            error_ctr_reg <= error_ctr_new;

          if (error_ctr_lsb_we)
            error_ctr_lsb_reg <= error_ctr_reg[31:0];

          if (key_ctrl_we)
            begin
              key0_valid_reg  <= write_data[CTRL_KEY0_VALID];
              key1_valid_reg  <= write_data[CTRL_KEY1_VALID];
              key2_valid_reg  <= write_data[CTRL_KEY2_VALID];
              key3_valid_reg  <= write_data[CTRL_KEY3_VALID];
              current_key_reg <= write_data[CTRL_CURR_HIGH : CTRL_CURR_LOW];
            end

          if (key_valid_we)
            key_valid_reg <= key_valid_new;

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
          end

        1:
          begin
            muxed_key_data   = key1[key_word];
            muxed_key_id     = key1_id_reg;
          end

        2:
          begin
            muxed_key_data   = key2[key_word];
            muxed_key_id     = key2_id_reg;
          end

        3:
          begin
            muxed_key_data   = key3[key_word];
            muxed_key_id     = key3_id_reg;
          end
      endcase // case (mux_ctrl_reg)
    end


  //----------------------------------------------------------------
  // counters
  //----------------------------------------------------------------

  task counter (
    input         rst,
    input         inc,
    input  [63:0] counter_reg,
    output        counter_we,
    output [63:0] counter_new
  );
  begin
    counter_we  =  1'b0;
    counter_new = 64'h0;

    if (rst)
      begin
        counter_we  = 1'h1;
        counter_new = 64'h0;
      end

    if (inc)
      begin
        if (counter_reg[31:0] == 32'hffff_ffff) begin
          counter_we         = 1'h1;
          counter_new[31:0]  = counter_reg[31:0] + 1;
          counter_new[63:32] = counter_reg[63:32] + 1; //inc msb
        end else begin
          counter_we         = 1'h1;
          counter_new[31:0]  = counter_reg[31:0] + 1;
          counter_new[63:32] = counter_reg[63:32]; //dont inc msb
        end
      end
  end
  endtask

  always @*
    begin : counters
      counter( key0_ctr_rst, key0_ctr_inc, key0_ctr_reg, key0_ctr_we, key0_ctr_new );
      counter( key1_ctr_rst, key1_ctr_inc, key1_ctr_reg, key1_ctr_we, key1_ctr_new );
      counter( key2_ctr_rst, key2_ctr_inc, key2_ctr_reg, key2_ctr_we, key2_ctr_new );
      counter( key3_ctr_rst, key3_ctr_inc, key3_ctr_reg, key3_ctr_we, key3_ctr_new );
      counter( error_ctr_rst, error_ctr_inc, error_ctr_reg, error_ctr_we, error_ctr_new) ;
    end


  //----------------------------------------------------------------
  // api
  //----------------------------------------------------------------
  always @*
    begin : api
      key_ctrl_we      = 1'h0;
      key0_we          = 1'h0;
      key0_ctr_lsb_we  = 1'h0;
      key0_ctr_rst     = 1'h0;
      key0_id_we       = 1'h0;
      key1_we          = 1'h0;
      key1_ctr_lsb_we  = 1'h0;
      key1_ctr_rst     = 1'h0;
      key1_id_we       = 1'h0;
      key2_we          = 1'h0;
      key2_ctr_lsb_we  = 1'h0;
      key2_ctr_rst     = 1'h0;
      key2_id_we       = 1'h0;
      key3_we          = 1'h0;
      key3_ctr_lsb_we  = 1'h0;
      key3_ctr_rst     = 1'h0;
      key3_id_we       = 1'h0;
      error_ctr_lsb_we = 1'h0;
      error_ctr_rst    = 1'h0;
      tmp_read_data    = 32'h0;

      if (cs)
        begin
          if (we)
            begin
              case (address)
                ADDR_CTRL:              key_ctrl_we    = 1'h1;
                ADDR_KEY0_ID:           key0_id_we     = 1'h1;
                ADDR_KEY1_ID:           key1_id_we     = 1'h1;
                ADDR_KEY2_ID:           key2_id_we     = 1'h1;
                ADDR_KEY3_ID:           key3_id_we     = 1'h1;
                ADDR_KEY0_COUNTER_MSB:  key0_ctr_rst   = 1'h1;
                ADDR_KEY1_COUNTER_MSB:  key1_ctr_rst   = 1'h1;
                ADDR_KEY2_COUNTER_MSB:  key2_ctr_rst   = 1'h1;
                ADDR_KEY3_COUNTER_MSB:  key3_ctr_rst   = 1'h1;
                ADDR_ERROR_COUNTER_MSB: error_ctr_rst  = 1'h1;
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

                ADDR_CTRL:          tmp_read_data = {14'h0, current_key_reg,
                                                     12'h0, key3_valid_reg,
                                                     key2_valid_reg,
                                                     key1_valid_reg,
                                                     key0_valid_reg};

                ADDR_KEY0_ID:       tmp_read_data = key0_id_reg;
                ADDR_KEY1_ID:       tmp_read_data = key1_id_reg;
                ADDR_KEY2_ID:       tmp_read_data = key2_id_reg;
                ADDR_KEY3_ID:       tmp_read_data = key3_id_reg;

                ADDR_KEY0_COUNTER_MSB:
                  begin
                    tmp_read_data = key0_ctr_reg[63:32];
                    key0_ctr_lsb_we = 1'b1;
                  end
                ADDR_KEY0_COUNTER_LSB: tmp_read_data = key0_ctr_lsb_reg;

                ADDR_KEY1_COUNTER_MSB:
                  begin
                    tmp_read_data = key1_ctr_reg[63:32];
                    key1_ctr_lsb_we = 1'b1;
                  end
                ADDR_KEY1_COUNTER_LSB: tmp_read_data = key1_ctr_lsb_reg;

                ADDR_KEY2_COUNTER_MSB:
                  begin
                    tmp_read_data = key2_ctr_reg[63:32];
                    key2_ctr_lsb_we = 1'b1;
                  end
                ADDR_KEY2_COUNTER_LSB: tmp_read_data = key2_ctr_lsb_reg;

                ADDR_KEY3_COUNTER_MSB:
                  begin
                    tmp_read_data = key3_ctr_reg[63:32];
                    key3_ctr_lsb_we = 1'b1;
                  end
                ADDR_KEY3_COUNTER_LSB: tmp_read_data = key3_ctr_lsb_reg;

                ADDR_ERROR_COUNTER_MSB:
                  begin
                    tmp_read_data = error_ctr_reg[63:32];
                    error_ctr_lsb_we = 1'b1;
                  end
                ADDR_ERROR_COUNTER_LSB: tmp_read_data = error_ctr_lsb_reg;

                default:
                  begin
                  end
              endcase // case (address)

              if ((address >= ADDR_KEY0_START) && (address <= ADDR_KEY0_END))
                tmp_read_data = key0[address[2 : 0]];

              if ((address >= ADDR_KEY1_START) && (address <= ADDR_KEY1_END))
                tmp_read_data = key1[address[2 : 0]];

              if ((address >= ADDR_KEY2_START) && (address <= ADDR_KEY2_END))
                tmp_read_data = key2[address[2 : 0]];

              if ((address >= ADDR_KEY3_START) && (address <= ADDR_KEY3_END))
                tmp_read_data = key3[address[2 : 0]];

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

            if (!get_current_key & !get_key_with_id)
              begin
                keymem_ctrl_new = CTRL_IDLE;
                keymem_ctrl_we  = 1'h1;
              end
          end
      endcase // case (keymem_ctrl_reg)
    end // block: keymem_ctrl

endmodule // nts_keymem

//======================================================================
// EOF nts_keymem.v
//======================================================================
