static bit lsbfe = 0;

static bit cpol = 0;
static bit cpha = 0;

int txn_count = 3;
`timescale 1ns / 10ps

import uvm_pkg::*;
`include "uvm_macros.svh"


`define APB_DATA_WIDTH 8
`define SPI_REG_WIDTH 8
`define APB_ADDR_WIDTH 3



`define APB_DATA_WIDTH 8
`define SPI_REG_WIDTH 8
`define APB_ADDR_WIDTH 3

module apb_slave (
    input PCLK,
    input PRESETn,
    input [`APB_ADDR_WIDTH-1:0] PADDR,
    input PWRITE,
    input PSEL,
    input PENABLE,
    input [`APB_DATA_WIDTH-1:0] PWDATA,
    output [`APB_DATA_WIDTH-1:0] PRDATA,
    output PREADY,
    output PSLVERR,
    input ss,
    input [`APB_DATA_WIDTH-1:0] miso_data,
    output reg send_data,
    input receive_data,
    input tip,
    output reg [`APB_DATA_WIDTH-1:0] mosi_data,
    output reg [1:0] spi_mode,
    output mstr,
    output cpol,
    output cpha,
    output lsbfe,
    output spiswai,
    output [2:0] sppr,
    output [2:0] spr,
    output spi_interrupt_request
);

  localparam IDLE = 2'b00;
  localparam SETUP = 2'b01;
  localparam ENABLE = 2'b10;

  localparam spi_run = 2'b00;
  localparam spi_wait = 2'b01;
  localparam spi_stop = 2'b10;

  // Masks to update the Contol Register and Baud Rate Register
  localparam cr2_mask = 8'b0001_1011;
  localparam br_mask = 8'b0111_0111;

  reg [1:0] STATE, next_state;
  reg [1:0] next_mode;

  wire spie;
  wire sptie;
  wire spe;

  wire modf;
  wire ssoe;
  wire modfen;

  reg sptef;
  reg spif;

  wire wr_enb;
  wire rd_enb;

  //--REGISTERS--
  reg [7:0] SPI_CR_1;
  reg [7:0] SPI_CR_2;
  reg [7:0] SPI_BR;
  reg [7:0] SPI_SR;
  reg [7:0] SPI_DR;

  //logic for APB States 
  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) STATE <= IDLE;
    else STATE <= next_state;
  end

  //logic for APB States 
  always @(*) begin
    case (STATE)
      IDLE: begin
        if (PSEL && !PENABLE) next_state <= SETUP;
        else next_state <= IDLE;
      end

      SETUP: begin
        if (PSEL && PENABLE) next_state <= ENABLE;
        else if (PSEL && !PENABLE) next_state <= SETUP;
        else next_state <= IDLE;
      end

      ENABLE: begin
        if (PSEL) next_state <= SETUP;
        else next_state <= IDLE;
      end

      default: next_state <= IDLE;
    endcase
  end

  // Logic to up date the PREADY and PSLVERR   
  assign PREADY  = (STATE == ENABLE) ? 1'b1 : 1'b0;
  assign PSLVERR = (STATE == ENABLE) ? tip : 1'b0;

  // Logic to generate the Write Enable and Read Enable
  assign wr_enb  = PWRITE && (STATE == ENABLE);
  assign rd_enb  = !PWRITE && (STATE == ENABLE);

  // Logic to update the CSR and the send the data to shift register
  // Data Register updated with miso data when receive_data is asserted
  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      SPI_CR_1 <= 8'b0000_0100;
      SPI_CR_2 <= 8'b0000_0000;
      SPI_BR <= 8'b0000_0000;
      SPI_DR <= 8'b0000_0000;
      send_data <= 1'b0;
    end else if (wr_enb) begin
      case (PADDR)
        3'b000:  SPI_CR_1 <= PWDATA;
        3'b001:  SPI_CR_2 <= (PWDATA & cr2_mask);
        3'b010:  SPI_BR <= (PWDATA & br_mask);
        3'b101:  SPI_DR <= PWDATA;
        default: SPI_DR <= PWDATA;
      endcase
    end 
      else if (((SPI_DR == PWDATA) && (SPI_DR != miso_data)) && (spi_mode == spi_run || spi_mode == spi_wait)) 
    	begin
      send_data <= 1'b1;
      mosi_data <= SPI_DR;
      SPI_DR <= 8'b0;
    end else if ((receive_data) && (spi_mode == spi_run || spi_mode == spi_wait)) begin
      SPI_DR <= miso_data;
      send_data <= 1'b0;
    end else begin
      send_data <= 1'b0;
    end
  end


  //logic to send PRDATA
  assign PRDATA = rd_enb ? 
                (PADDR == 3'b000 ? SPI_CR_1 : 
                (PADDR == 3'b001 ? SPI_CR_2 : 
                (PADDR == 3'b010 ? SPI_BR : 
                (PADDR == 3'b011 ? SPI_SR : SPI_DR)))) 
                : 8'b0;

  // Logic to update the Register Fields or Flags
  assign mstr = SPI_CR_1[4];
  assign cpol = SPI_CR_1[3];
  assign cpha = SPI_CR_1[2];
  assign ssoe = SPI_CR_1[1];
  assign lsbfe = SPI_CR_1[0];
  assign spie = SPI_CR_1[7];
  assign spe = SPI_CR_1[6];
  assign sptie = SPI_CR_1[5];

  assign modfen = SPI_CR_2[4];
  assign spiswai = SPI_CR_2[1];

  // logic to update the SPPR and SPR
  assign sppr = SPI_BR[6:4];
  assign spr = SPI_BR[2:0];

  // Logic update the flags  modf of status register
  assign modf = ((~ss) && mstr && modfen && (~ssoe));

  //logic to update the SPI Interrupt Request
  assign spi_interrupt_request = ( !spie && !sptie )?0:
	  			 ( spie && !sptie )? (spif || modf ):
				 ( !spie && sptie )? sptef :
				 (spif || sptef || modf );

  // logic to update the SPI Mode {Low Power Mode Options(run_mode, wait_mode,
  // stop_mode)}
  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) spi_mode <= spi_run;
    else spi_mode <= next_mode;
  end

  // logic to update the SPI Mode {Low Power Mode Options(run_mode, wait_mode,
  // stop_mode)}
  always @(*) begin
    case (spi_mode)
      spi_run: begin
        if (!spe) next_mode <= spi_wait;
        else next_mode <= spi_run;
      end

      spi_wait: begin
        if (spe) next_mode <= spi_run;
        else if (spiswai) next_mode <= spi_stop;
        else next_mode <= spi_wait;
      end

      spi_stop: begin
        if (spe) next_mode <= spi_run;
        else if (!spiswai) next_mode <= spi_wait;
        else next_mode <= spi_stop;
      end
      default: next_mode <= spi_run;
    endcase
  end

  // Logic to set the  Flags in the status registers
  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) SPI_SR <= 8'b0010_0000;
    else begin
      if (SPI_DR == 8'b0000_0000) sptef <= 1'b1;
      else sptef <= 1'b0;

      if ((SPI_DR == PWDATA) || ((SPI_DR == miso_data) && (SPI_DR != 8'b0000_0000))) spif <= 1'b1;
      else spif <= 1'b0;

      SPI_SR <= {spif, 1'b0, sptef, modf, 4'b0};
    end
  end

endmodule

module baud_generator (
    input PCLK,
    input PRESETn,
    input [1:0] spi_mode,  // indicates run_mode, wait_mode and stop_mode
    input spiswai,
    input [2:0] sppr,  // SPI Baud Rate Preselection Bits
    input [2:0] spr,  // SPI Baud Rate Selection Bits
    input cpol,  // 0 - Idle Low, 1- Idle High
    input ss,  // Slave Selection 
    output reg sclk,
    output [11:0] BaudRateDivisor
);

  wire pre_sclk;
  reg [11:0] count;

  // Baud Rate Divisor
  assign BaudRateDivisor = ((sppr + 1) * (2 ** (spr + 1)));


  // Logic to generate pre_sclk based on the cpol
  assign pre_sclk = cpol ? 1'b1 : 1'b0;

  // Logic to generate the Sclk
  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      count <= 12'b0;
      sclk  <= pre_sclk;
    end else if ((~ss) && (spi_mode == 2'b00 || (spi_mode == 2'b01 && (~spiswai)))) begin
      if (count == (BaudRateDivisor - 1'b1)) begin
        count <= 12'b0;
        sclk  <= ~sclk;
      end else count <= count + 1'b1;
    end else begin
      sclk  <= pre_sclk;
      count <= 12'b0;
    end
  end

endmodule








`define APB_DATA_WIDTH 8
`define SPI_REG_WIDTH 8
`define APB_ADDR_WIDTH 3

module shifter (
    input PCLK,
    input sclk,
    input PRESETn,
    input ss,
    input send_data,
    input lsbfe,
    input cpha,
    input cpol,
    input [`APB_DATA_WIDTH-1:0] data_mosi,
    input miso,
    input receive_data,
    output [`APB_DATA_WIDTH-1:0] data_miso,
    output mosi
);

  reg [`APB_DATA_WIDTH-1:0] shift_register;

  reg [`APB_DATA_WIDTH-1:0] temp_reg1;
  reg [`APB_DATA_WIDTH-1:0] temp_reg2;

  reg [3:0] count;
  reg [3:0] count1;
  reg [3:0] count2;
  reg [3:0] count3;
  reg [3:0] count4;
  reg [3:0] count5;
  reg [3:0] count6;
  reg [3:0] count7;
  reg [3:0] count8;
  reg [3:0] count9;
  reg [3:0] count10;
  reg [3:0] count11;

  reg mosi1;
  reg mosi2;
  reg mosi3;
  reg mosi4;



  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      shift_register <= 8'b0;
    end else if (send_data) shift_register <= data_mosi;
  end


  assign mosi = cpha ? (cpol ? mosi4 : mosi3) : (cpol ? mosi2 : mosi1);
  assign data_miso=receive_data?(((cpha&&cpol)||( !cpha && !cpol))?temp_reg1:temp_reg2):8'b0000_0000;


  // Sending the MOSI Data - (CPHA 0 & CPOL 0) 
  //
  always @(negedge sclk or negedge ss or negedge PRESETn or posedge receive_data) begin
    if (!PRESETn) begin
      count  <= 4'd0;
      count1 <= 4'd7;
    end else if (receive_data) begin
      count  <= 4'd0;
      count1 <= 4'd7;
    end else begin
      if (!ss) begin
        if ((!cpha) && (!cpol)) begin
          if (lsbfe) begin
            if (count <= 4'd7) begin
              mosi1 <= shift_register[count];
              count <= count + 1'b1;
            end else begin
              mosi1 <= 1'b0;
              count <= 4'd8;
            end
          end else begin
            if (count1 >= 4'd0) begin
              mosi1  <= shift_register[count1];
              count1 <= count1 - 1'b1;
            end else begin
              mosi1  <= 1'b0;
              count1 <= 4'd15;
            end
          end
        end else begin
          mosi1  <= 1'b0;
          count  <= 4'd8;
          count1 <= 4'd15;
        end
      end else begin
        mosi1  <= 1'b0;
        count  <= 4'd8;
        count1 <= 4'd15;
      end
    end
  end


  // Sending the MOSI Data - (CPHA 0 & CPOL 1) 
  //
  always @(posedge sclk or negedge ss or negedge PRESETn or posedge receive_data) begin
    if (!PRESETn) begin
      count2 <= 4'd0;
      count3 <= 4'd7;
    end else if (receive_data) begin
      count2 <= 4'd0;
      count3 <= 4'd7;
    end else begin
      if (!ss) begin
        if ((!cpha) && (cpol)) begin
          if (lsbfe) begin
            if (count2 <= 4'd7) begin
              mosi2  <= shift_register[count2];
              count2 <= count2 + 1'b1;
            end else begin
              mosi2  <= 1'b0;
              count2 <= 4'd8;
            end
          end else begin
            if (count3 >= 4'd0) begin
              mosi2  <= shift_register[count3];
              count3 <= count3 - 1'b1;
            end else begin
              mosi2  <= 1'b0;
              count3 <= 4'd15;
            end
          end
        end else begin
          mosi2  <= 1'b0;
          count2 <= 4'd8;
          count3 <= 4'd15;
        end
      end else begin
        mosi2  <= 1'b0;
        count2 <= 4'd8;
        count3 <= 4'd15;
      end
    end
  end



  // Sending the MOSI Data -(CPHA 1 or CPOL 0)
  always @(posedge sclk or negedge PRESETn or posedge receive_data) begin
    if (!PRESETn) begin
      count4 <= 4'd0;
      count5 <= 4'd7;
    end else if (receive_data) begin
      count4 <= 4'd0;
      count5 <= 4'd7;
    end else begin
      if (!ss) begin
        if (cpha && (!cpol)) begin
          if (lsbfe) begin
            if (count4 <= 4'd7) begin
              mosi3  <= shift_register[count4];
              count4 <= count4 + 1'b1;
            end else begin
              mosi3  <= 1'b0;
              count4 <= 4'd8;
            end
          end else begin
            if (count5 >= 4'd0) begin
              mosi3  <= shift_register[count5];
              count5 <= count5 - 1'b1;
            end else begin
              mosi3  <= 1'b0;
              count5 <= 4'd15;
            end
          end
        end else begin
          mosi3  <= 1'b0;
          count4 <= 4'd8;
          count5 <= 4'd15;
        end
      end else begin
        mosi3  <= 1'b0;
        count4 <= 4'd8;
        count5 <= 4'd15;
      end
    end
  end

  // Sending the MOSI Data -(CPHA 1 or CPOL 1)
  always @(negedge sclk or negedge PRESETn or posedge receive_data) begin
    if (!PRESETn) begin
      count6 <= 4'd0;
      count7 <= 4'd7;
    end else if (receive_data) begin
      count6 <= 4'd0;
      count7 <= 4'd7;
    end else begin
      if (!ss) begin
        if (cpha && cpol) begin
          if (lsbfe) begin
            if (count6 <= 4'd7) begin
              mosi4  <= shift_register[count6];
              count6 <= count6 + 1'b1;
            end else begin
              mosi4  <= 1'b0;
              count6 <= 4'd8;
            end
          end else begin
            if (count7 >= 4'd0) begin
              mosi4  <= shift_register[count7];
              count7 <= count7 - 1'b1;
            end else begin
              mosi4  <= 1'b0;
              count7 <= 4'd15;
            end
          end
        end else begin
          mosi4  <= 1'b0;
          count6 <= 4'd8;
          count7 <= 4'd15;
        end
      end else begin
        mosi4  <= 1'b0;
        count6 <= 4'd8;
        count7 <= 4'd15;
      end
    end
  end


  // Logic for Receiving the MISO Data 
  // for (CPHA 0 & CPOL 0) or (CPHA1 & CPOL 1)
  always @(posedge sclk or negedge PRESETn or posedge receive_data) begin
    if (!PRESETn) begin
      count8 <= 4'd0;
      count9 <= 4'd7;
    end else if (receive_data) begin
      count8 <= 4'd0;
      count9 <= 4'd7;
    end else begin
      if (!ss) begin
        if (((!cpha) && (!cpol)) || (cpha && cpol)) begin
          if (lsbfe) begin
            if (count8 <= 4'd7) begin
              temp_reg1[count8] <= miso;
              count8 <= count8 + 1'b1;
            end
          end else begin
            if (count9 >= 4'd0) begin
              temp_reg1[count9] <= miso;
              count9 <= count9 - 1'b1;
            end
          end
        end
      end
    end
  end

  // for (CPHA 1 & CPOL 0) or (CPHA0 & CPOL 1)
  always @(negedge sclk or negedge PRESETn or posedge receive_data) begin
    if (!PRESETn) begin
      count10 <= 4'd0;
      count11 <= 4'd7;
    end else if (receive_data) begin
      count10 <= 4'd0;
      count11 <= 4'd7;
    end else begin
      if (!ss) begin
        if ((cpha && (!cpol)) || ((!cpha) && cpol)) begin
          if (lsbfe) begin
            if (count10 <= 4'd7) begin
              temp_reg2[count10] <= miso;
              count10 <= count10 + 1'b1;
            end
          end else begin
            if (count11 >= 4'd0) begin
              temp_reg2[count11] <= miso;
              count11 <= count11 - 1'b1;
            end
          end
        end
      end

    end
  end

endmodule












`define APB_DATA_WIDTH 8
`define SPI_REG_WIDTH 8
`define APB_ADDR_WIDTH 3

module spi_core (
    input PCLK,
    input PRESETn,
    input [`APB_ADDR_WIDTH-1:0] PADDR,
    input PWRITE,
    input PSEL,
    input PENABLE,
    input [`APB_DATA_WIDTH-1:0] PWDATA,
    output [`APB_DATA_WIDTH-1:0] PRDATA,
    output PREADY,
    output PSLVERR,
    input miso,
    output ss,
    output sclk,
    output spi_interrupt_request,
    output mosi
);

  wire [`APB_DATA_WIDTH-1:0] miso_data;
  wire [`APB_DATA_WIDTH-1:0] mosi_data;

  wire send_data;
  wire receive_data;
  wire tip;
  wire [1:0] spi_mode;

  wire mstr;
  wire cpol;
  wire cpha;
  wire lsbfe;
  wire spiswai;
  wire [2:0] sppr;
  wire [2:0] spr;
  wire [11:0] BaudRateDivisor;

  apb_slave APB_INTERFACE (
      .PCLK(PCLK),
      .PRESETn(PRESETn),
      .PADDR(PADDR),
      .PWRITE(PWRITE),
      .PSEL(PSEL),
      .PENABLE(PENABLE),
      .PWDATA(PWDATA),
      .PRDATA(PRDATA),
      .PREADY(PREADY),
      .PSLVERR(PSLVERR),
      .ss(ss),
      .miso_data(miso_data),
      .send_data(send_data),
      .receive_data(receive_data),
      .tip(tip),
      .mosi_data(mosi_data),
      .spi_mode(spi_mode),
      .mstr(mstr),
      .cpol(cpol),
      .cpha(cpha),
      .lsbfe(lsbfe),
      .spiswai(spiswai),
      .sppr(sppr),
      .spr(spr),
      .spi_interrupt_request(spi_interrupt_request)
  );


  baud_generator BAUD_GEN (
      .PCLK(PCLK),
      .PRESETn(PRESETn),
      .spi_mode(spi_mode),
      .spiswai(spiswai),
      .sppr(sppr),
      .spr(spr),
      .ss(ss),
      .cpol(cpol),
      .sclk(sclk),
      .BaudRateDivisor(BaudRateDivisor)
  );


  spi_slave_select SLAVE_SELECT (
      .PCLK(PCLK),
      .PRESETn(PRESETn),
      .spi_mode(spi_mode),
      .mstr(mstr),
      .spiswai(spiswai),
      .send_data(send_data),
      .BaudRateDivisor(BaudRateDivisor),
      .ss(ss),
      .receive_data(receive_data),
      .tip(tip)
  );


  shifter SHIFTER (
      .PCLK(PCLK),
      .sclk(sclk),
      .PRESETn(PRESETn),
      .ss(ss),
      .send_data(send_data),
      .lsbfe(lsbfe),
      .cpha(cpha),
      .cpol(cpol),
      .data_mosi(mosi_data),
      .miso(miso),
      .receive_data(receive_data),
      .data_miso(miso_data),
      .mosi(mosi)
  );

endmodule

module spi_slave_select (
    input PRESETn,
    input [1:0] spi_mode,
    input mstr,
    input spiswai,
    input PCLK,
    input send_data,
    input [11:0] BaudRateDivisor,
    output reg ss,
    output reg receive_data,
    output tip
);

  reg [15:0] count;  //
  wire [15:0] target;  //
  reg rcv;  //

  assign target = BaudRateDivisor * 5'd16;  //doubt
  assign tip = (~ss);

  // Logic to generate the ss as low when new data is received to Data
  // Register through PWDATA Bus(send_data signal will become high)
  always @(negedge PRESETn or posedge PCLK) begin
    if (!PRESETn) begin
      count <= 16'hffff;
      ss <= 1'b1;
      rcv <= 1'b0;
    end
      else if(mstr && (spi_mode == 2'b00 || (spi_mode == 2'b01 && (~spiswai)))) //Checking whether spi is in run mode or wait mode
	begin
      if (send_data) begin
        ss <= 1'b0;
        count <= 16'h0;
      end else if (count <= (target - 1'b1)) begin
        ss <= 1'b0;
        count <= count + 1'b1;
        if (count == (target - 1'b1)) rcv <= 1'b1;
      end else begin
        ss <= 1'b1;
        rcv <= 1'b0;
        count <= 16'hffff;
      end
    end else begin
      ss <= 1'b1;
      rcv <= 1'b0;
      count <= 16'hffff;
    end
  end


  // generate receive_data after one clock cycle so all it will to make sure
  // MISO is collected proprly. 
  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) receive_data <= 1'b0;
    else receive_data <= rcv;
  end

endmodule


class spi_cr1_reg extends uvm_reg;

  `uvm_object_utils(spi_cr1_reg)

  function new(string name = "spi_cr1_reg");

    super.new(name, 8, UVM_CVR_ALL);

  endfunction

  // CR 1 => SPIE             SPE     SPTIE   MSTR    CPOL    CPHA    SSOE    LSBFE         Reset Value = 8’b0000_0100
  //         7                6                5              4               3                2               1               0

  rand uvm_reg_field lsbfe;
  rand uvm_reg_field ssoe;
  rand uvm_reg_field cpha;
  rand uvm_reg_field cpol;
  rand uvm_reg_field mstr;
  rand uvm_reg_field sptie;
  rand uvm_reg_field spe;
  rand uvm_reg_field spie;

  function void build();

    lsbfe = uvm_reg_field::type_id::create("lsbfe");
    ssoe  = uvm_reg_field::type_id::create("ssoe");
    cpha  = uvm_reg_field::type_id::create("cpha");
    cpol  = uvm_reg_field::type_id::create("cpol");
    mstr  = uvm_reg_field::type_id::create("mstr");
    sptie = uvm_reg_field::type_id::create("sptie");
    spe   = uvm_reg_field::type_id::create("spe");
    spie  = uvm_reg_field::type_id::create("spie");

    //(parent,size,lsb_pos,access,volatile,reset_value,has_reset,has_rand,has_cover)
    //(0     ,1   ,2      ,3     ,4       ,5          ,6        ,7       ,8)

    lsbfe.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 1);
    ssoe.configure(this, 1, 1, "RW", 0, 1'b0, 1, 1, 1);
    cpha.configure(this, 1, 2, "RW", 0, 1'b1, 1, 1, 1);
    cpol.configure(this, 1, 3, "RW", 0, 1'b0, 1, 1, 1);
    mstr.configure(this, 1, 4, "RW", 0, 1'b0, 1, 1, 1);
    sptie.configure(this, 1, 5, "RW", 0, 1'b0, 1, 1, 1);
    spe.configure(this, 1, 6, "RW", 0, 1'b0, 1, 1, 1);
    spie.configure(this, 1, 7, "RW", 0, 1'b0, 1, 1, 1);

  endfunction

endclass

class spi_cr2_reg extends uvm_reg;

  `uvm_object_utils(spi_cr2_reg)

  function new(string name = "spi_cr2_reg");

    super.new(name, 8, UVM_CVR_ALL);

  endfunction

  // CR 2 => 0                0               0               MODFEN  BIDIROE 0                SPISWAI SPC0         Reset Value = 8’b0000_0000
  //         7                6                5              4               3                2               1               0


  rand uvm_reg_field spc0;
  rand uvm_reg_field spiswai;
  rand uvm_reg_field bidiroe;
  rand uvm_reg_field modfen;

  uvm_reg_field reserved1;
  uvm_reg_field reserved2;


  function void build();

    spc0 = uvm_reg_field::type_id::create("spc0");
    spiswai = uvm_reg_field::type_id::create("spiswai");
    bidiroe = uvm_reg_field::type_id::create("bidiroe");
    modfen = uvm_reg_field::type_id::create("modfen");

    reserved1 = uvm_reg_field::type_id::create("reserved1");
    reserved2 = uvm_reg_field::type_id::create("reserved2");

    //(parent,size,lsb_pos,access,volatile,reset_value,has_reset,has_rand,has_cover)
    //(0     ,1   ,2      ,3     ,4       ,5          ,6        ,7       ,8)
    spc0.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 1);
    spiswai.configure(this, 1, 1, "RW", 0, 1'b0, 1, 1, 1);
    reserved1.configure(this, 1, 2, "RO", 0, 1'b0, 0, 0, 0);
    bidiroe.configure(this, 1, 3, "RW", 0, 1'b0, 1, 1, 1);
    modfen.configure(this, 1, 4, "RW", 0, 1'b0, 1, 1, 1);
    reserved2.configure(this, 3, 5, "RO", 0, 1'b0, 0, 0, 0);

  endfunction

endclass
class spi_br_reg extends uvm_reg;

  `uvm_object_utils(spi_br_reg)

  function new(string name = "spi_br_reg");

    super.new(name, 8, UVM_CVR_ALL);

  endfunction

  // BR   => 0                SPPR2   SPPR1   SPPR0   0               SPR2    SPR1     SPR0         Reset Value = 8’b0000_0000
  //         7               6                5              4               3                2               1               0

  rand uvm_reg_field spr0;
  rand uvm_reg_field spr1;
  rand uvm_reg_field spr2;
  uvm_reg_field reserved1;
  rand uvm_reg_field sppr0;
  rand uvm_reg_field sppr1;
  rand uvm_reg_field sppr2;
  uvm_reg_field reserved2;

  function void build();

    spr0 = uvm_reg_field::type_id::create("spr0");
    spr1 = uvm_reg_field::type_id::create("spr1");
    spr2 = uvm_reg_field::type_id::create("spr2");
    reserved1 = uvm_reg_field::type_id::create("reserved1");
    sppr0 = uvm_reg_field::type_id::create("sppr0");
    sppr1 = uvm_reg_field::type_id::create("sppr1");
    sppr2 = uvm_reg_field::type_id::create("sppr2");
    reserved2 = uvm_reg_field::type_id::create("reserved2");

    //(parent,size,lsb_pos,access,volatile,reset_value,has_reset,has_rand,has_cover)
    //(0     ,1   ,2      ,3     ,4       ,5          ,6        ,7       ,8)
    spr0.configure(this, 1, 0, "RW", 0, 1'b0, 1, 1, 1);
    spr1.configure(this, 1, 1, "RW", 0, 1'b0, 1, 1, 1);
    spr2.configure(this, 1, 2, "RW", 0, 1'b0, 1, 1, 1);
    reserved1.configure(this, 1, 3, "RO", 0, 1'b0, 0, 0, 0);
    sppr0.configure(this, 1, 4, "RW", 0, 1'b0, 1, 1, 1);
    sppr1.configure(this, 1, 5, "RW", 0, 1'b0, 1, 1, 1);
    sppr2.configure(this, 1, 6, "RW", 0, 1'b0, 1, 1, 1);
    reserved2.configure(this, 1, 7, "RO", 0, 1'b0, 0, 0, 0);

  endfunction

endclass
class spi_sr_reg extends uvm_reg;

  `uvm_object_utils(spi_sr_reg)

  function new(string name = "spi_sr_reg");

    super.new(name, 8, UVM_CVR_ALL);

  endfunction

  // SR   => SPIF     0               SPTEF   MODF    0               0       0       0            Reset Value = 8’b0010_0000
  //         7                6                5              4               3                2               1               0

  uvm_reg_field reserved1;
  rand uvm_reg_field modf;
  rand uvm_reg_field sptef;
  uvm_reg_field reserved2;
  rand uvm_reg_field spif;

  function void build();

    reserved1 = uvm_reg_field::type_id::create("reserved1");
    modf = uvm_reg_field::type_id::create("modf");
    sptef = uvm_reg_field::type_id::create("sptef");
    reserved2 = uvm_reg_field::type_id::create("reserved2");
    spif = uvm_reg_field::type_id::create("spif");

    //(parent,size,lsb_pos,access,volatile,reset_value,has_reset,has_rand,has_cover)
    //(0     ,1   ,2      ,3     ,4       ,5          ,6        ,7       ,8)
    reserved1.configure(this, 4, 0, "RO", 0, 1'b0, 0, 0, 0);
    modf.configure(this, 1, 4, "RO", 0, 1'b0, 1, 1, 1);
    sptef.configure(this, 1, 5, "RO", 0, 1'b1, 1, 1, 1);
    reserved2.configure(this, 1, 6, "RO", 0, 1'b0, 0, 0, 0);
    spif.configure(this, 1, 7, "RO", 0, 1'b0, 1, 1, 1);

  endfunction

endclass
class spi_dr_reg extends uvm_reg;

  `uvm_object_utils(spi_dr_reg)

  function new(string name = "spi_dr_reg");

    super.new(name, 8, UVM_CVR_ALL);

  endfunction

  // DR   =>  7               6                5              4               3                2               1               0            Reset Value = 8’b0000_0000

  rand uvm_reg_field reserved1;

  function void build();

    reserved1 = uvm_reg_field::type_id::create("reserved1");

    //(parent,size,lsb_pos,access,volatile,reset_value,has_reset,has_rand,has_cover)
    //(0     ,1   ,2      ,3     ,4       ,5          ,6        ,7       ,8)

    reserved1.configure(this, 8, 0, "RW", 0, 1'b0, 1, 1, 1);

  endfunction

endclass




class spi_reg_block extends uvm_reg_block;

  `uvm_object_utils(spi_reg_block)

  function new(string name = "spi_reg_block");

    super.new(name, UVM_NO_COVERAGE);

  endfunction

  rand spi_cr1_reg cntrl_reg1;
  rand spi_cr2_reg cntrl_reg2;
  rand spi_br_reg baud_reg;
  spi_sr_reg status_reg;
  rand spi_dr_reg data_reg;

  uvm_reg_map spi_reg_map;

  function void build();

    cntrl_reg1 = spi_cr1_reg::type_id::create("cntrl_reg1");
    cntrl_reg2 = spi_cr2_reg::type_id::create("cntrl_reg2");
    baud_reg   = spi_br_reg::type_id::create("baud_reg");
    status_reg = spi_sr_reg::type_id::create("status_reg");
    data_reg   = spi_dr_reg::type_id::create("data_reg");

    cntrl_reg1.configure(this, null, "");
    cntrl_reg2.configure(this, null, "");
    baud_reg.configure(this, null, "");
    status_reg.configure(this, null, "");
    data_reg.configure(this, null, "");

    cntrl_reg1.build();
    cntrl_reg2.build();
    baud_reg.build();
    status_reg.build();
    data_reg.build();

    add_hdl_path("top.spi_core_h", "RTL");

    cntrl_reg1.add_hdl_path_slice("APB_INTERFACE.SPI_CR_1", 0, 8);
    cntrl_reg2.add_hdl_path_slice("APB_INTERFACE.SPI_CR_2", 0, 8);
    baud_reg.add_hdl_path_slice("APB_INTERFACE.SPI_BR", 0, 8);
    status_reg.add_hdl_path_slice("APB_INTERFACE.SPI_SR", 0, 8);
    data_reg.add_hdl_path_slice("APB_INTERFACE.SPI_DR", 0, 8);

    spi_reg_map = create_map("spi_reg_map", 'h0, 1, UVM_LITTLE_ENDIAN, 0);

    spi_reg_map.add_reg(cntrl_reg1, 8'h0, "RW");
    spi_reg_map.add_reg(cntrl_reg2, 8'h1, "RW");
    spi_reg_map.add_reg(baud_reg, 8'h2, "RW");
    spi_reg_map.add_reg(status_reg, 8'h3, "RO");
    spi_reg_map.add_reg(data_reg, 8'h5, "RW");

  endfunction

endclass


class spi_agt_cfg extends uvm_object;
  `uvm_object_utils(spi_agt_cfg)
  function new(string name = "spi_agt_cfg");
    super.new(name);
  endfunction
  uvm_active_passive_enum is_active;
  virtual core2spi core2spi_h;
  bit [7:0] ctrl;
endclass

class apb_agt_cfg extends uvm_object;
  `uvm_object_utils(apb_agt_cfg)
  function new(string name = "apb_agt_cfg");
    super.new(name);
  endfunction
  uvm_active_passive_enum is_active;
  virtual apb2core apb2core_h;
endclass

class env_cfg extends uvm_object;
  `uvm_object_utils(env_cfg)
  function new(string name = "env_cfg");
    super.new(name);
  endfunction
  bit has_functional_coverage;
  bit has_virtual_sequencer;
  bit has_scoreboard;
  bit has_apb_agent;
  bit has_spi_agent;
  int spi_agent_count;
  int apb_agent_count;
  int seq_count;

  apb_agt_cfg apb_agt_cfg_h[];
  spi_agt_cfg spi_agt_cfg_h[];
endclass

class apb_txn extends uvm_sequence_item;
  `uvm_object_utils(apb_txn)
  function new(string name = "apb_txn");
    super.new(name);
  endfunction
  rand bit PRESETn;
  rand bit PWRITE;
  bit PSEL;
  bit PENABLE;
  rand bit [2:0] PADDR;
  rand bit [7:0] PWDATA;
  bit [7:0] PRDATA;
  bit PREADY;
  bit PSLVERR;
  constraint valid_addr {
    if (!PWRITE)
    PADDR inside {[0 : 3], 5};
    else
    PADDR inside {[0 : 2], 5};
  }
  constraint valid_rst {
    PRESETn dist {
      0 := 1,
      1 := 99
    };
  }
  // function void post_randomize();
  //   bit [7:0] CR1_MASK = 8'hFF;
  //   bit [7:0] CR2_MASK = 8'h1B;
  //   bit [7:0] BDR_MASK = 8'h77;
  //   bit [7:0] STATUS_MASK = 8'h00;
  //   bit [7:0] DATA_MASK = 8'hFF;
  //   if (PWRITE) begin
  //     case (PADDR)
  //       'b000:   PWDATA = CR1_MASK & PWDATA;
  //       'b001:   PWDATA = CR2_MASK & PWDATA;
  //       'b010:   PWDATA = BDR_MASK & PWDATA;
  //       // 'b011: PWDATA = STATUS_MASK & PWDATA;
  //       'b101:   PWDATA = DATA_MASK & PWDATA;
  //       default: PWDATA = DATA_MASK & PWDATA;
  //     endcase
  //   end
  // endfunction

  function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field("PRESETn", this.PRESETn, 1, UVM_BIN);
    printer.print_field("PWRITE", this.PWRITE, 1, UVM_BIN);
    printer.print_field("PSEL", this.PSEL, 1, UVM_BIN);
    printer.print_field("PENABLE", this.PENABLE, 1, UVM_BIN);
    printer.print_field("PADDR", this.PADDR, 3, UVM_DEC);
    // printer.print_field("PWDATA", this.PWDATA, 8, UVM_DEC);
    // printer.print_field("PRDATA", this.PRDATA, 8, UVM_DEC);
    printer.print_field("PWDATA", this.PWDATA, 8, UVM_BIN);
    printer.print_field("PRDATA", this.PRDATA, 8, UVM_BIN);
    printer.print_field("PREADY", this.PREADY, 1, UVM_BIN);
    printer.print_field("PSLVERR", this.PSLVERR, 1, UVM_BIN);
  endfunction

endclass

class apb_driver extends uvm_driver #(apb_txn);
  `uvm_component_utils(apb_driver)
  function new(string name = "apb_driver", uvm_component parent);
    super.new(name, parent);
  endfunction
  apb_agt_cfg apb_agt_cfg_h;
  virtual apb2core apb2core_h;
  function void connect_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual apb2core)::get(this, "", "apb2core", apb2core_h))
      `uvm_fatal(get_full_name, "Config fetch failed")
    //    apb2core_h = apb_agt_cfg_h.apb2core_h;
  endfunction
  task run_phase(uvm_phase phase);


    apb2core_h.drv_cb.PRESETn <= 1'b0;
    repeat (2) @(apb2core_h.drv_cb);

    apb2core_h.drv_cb.PRESETn <= 1'b1;
    forever begin
      seq_item_port.get_next_item(req);
      send_to_dut(req);
      seq_item_port.item_done();
    end
  endtask
  task send_to_dut(apb_txn req);
    // `uvm_info(get_type_name, $sformatf("%s %p", req.sprint(), apb2core_h), UVM_MEDIUM)

    @(apb2core_h.drv_cb);
    apb2core_h.drv_cb.PADDR_i <= req.PADDR;
    // apb2core_h.drv_cb.PRESETn <= 1'b1;
    apb2core_h.drv_cb.PWRITE_i <= req.PWRITE;
    apb2core_h.drv_cb.PSEL_i <= 1'b1;
    apb2core_h.drv_cb.PENABLE_i <= 1'b0;
    if (req.PWRITE) apb2core_h.drv_cb.PWDATA_i <= req.PWDATA;
    @(apb2core_h.drv_cb);
    apb2core_h.drv_cb.PENABLE_i <= 1'b1;

    // `uvm_info(get_type_name, $sformatf("before wait"), UVM_MEDIUM)
    wait (apb2core_h.drv_cb.PREADY_o)
      if (req.PWRITE == 1'b0) req.PRDATA = apb2core_h.drv_cb.PRDATA_o;

    // `uvm_info(get_type_name, $sformatf("after wait"), UVM_MEDIUM)
    apb2core_h.drv_cb.PSEL_i <= 1'b0;
    apb2core_h.drv_cb.PENABLE_i <= 1'b0;
  endtask
endclass


class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)
  uvm_analysis_port #(apb_txn) port_h;
  function new(string name = "apb_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction

  apb_txn apb_txn_h;
  apb_agt_cfg apb_agt_cfg_h;
  virtual apb2core.mon_mp apb2core_h;
  function void build_phase(uvm_phase phase);
    port_h = new("port_h", this);
    apb_txn_h = apb_txn::type_id::create("apb_txn_h");
  endfunction

  function void connect_phase(uvm_phase phase);
    if (!uvm_config_db#(apb_agt_cfg)::get(this, "", "apb_agt_cfg", apb_agt_cfg_h))
      `uvm_fatal(get_full_name, "Config fetch failed")
    apb2core_h = apb_agt_cfg_h.apb2core_h;
  endfunction

  task run_phase(uvm_phase phase);

    repeat (2) @(apb2core_h.mon_cb);
    forever begin
      sample ();
    end
  endtask
  task sample ();

    wait (apb2core_h.mon_cb.PENABLE_i && apb2core_h.mon_cb.PREADY_o);
    apb_txn_h.PRESETn = apb2core_h.mon_cb.PRESETn;
    apb_txn_h.PSEL = apb2core_h.mon_cb.PSEL_i;
    apb_txn_h.PWRITE = apb2core_h.mon_cb.PWRITE_i;
    apb_txn_h.PENABLE = apb2core_h.mon_cb.PENABLE_i;
    apb_txn_h.PADDR = apb2core_h.mon_cb.PADDR_i;
    if (apb_txn_h.PWRITE) apb_txn_h.PWDATA = apb2core_h.mon_cb.PWDATA_i;
    else apb_txn_h.PRDATA = apb2core_h.mon_cb.PRDATA_o;
    apb_txn_h.PREADY  = apb2core_h.mon_cb.PREADY_o;
    apb_txn_h.PSLVERR = apb2core_h.mon_cb.PSLVERR_o;
    port_h.write(apb_txn_h);
    // `uvm_info(get_type_name, $sformatf("%s", apb_txn_h.sprint()), UVM_MEDIUM)
    @(apb2core_h.mon_cb);
  endtask
endclass


class apb_seqr extends uvm_sequencer #(apb_txn);
  `uvm_component_utils(apb_seqr)
  function new(string name = "apb_seqr", uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class apb_agent extends uvm_agent;
  `uvm_component_utils(apb_agent)
  function new(string name = "apb_agent", uvm_component parent);
    super.new(name, parent);
  endfunction
  apb_agt_cfg apb_agt_cfg_h;
  apb_driver apb_driver_h;
  apb_seqr apb_seqr_h;
  apb_monitor apb_monitor_h;
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(apb_agt_cfg)::get(this, "", "apb_agt_cfg", apb_agt_cfg_h))
      `uvm_fatal(get_full_name, "Config fetch failed")
    if (apb_agt_cfg_h.is_active) begin

      apb_driver_h = apb_driver::type_id::create("apb_driver_h", this);
      apb_seqr_h   = apb_seqr::type_id::create("apb_seqr_h", this);
    end
    apb_monitor_h = apb_monitor::type_id::create("apb_monitor_h", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    if (apb_agt_cfg_h.is_active == UVM_ACTIVE)
      apb_driver_h.seq_item_port.connect(apb_seqr_h.seq_item_export);
  endfunction
endclass





class apb_agt_top extends uvm_env;
  `uvm_component_utils(apb_agt_top)
  function new(string name = "apb_agt_top", uvm_component parent);
    super.new(name, parent);
  endfunction
  apb_agent apb_agent_h[];
  apb_agt_cfg apb_agt_cfg_h[];
  env_cfg env_cfg_h;
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(env_cfg)::get(this, "", "env_cfg", env_cfg_h))
      `uvm_fatal(get_full_name, "Config fetch failed")
    apb_agt_cfg_h = env_cfg_h.apb_agt_cfg_h;
    foreach (apb_agt_cfg_h[i])
    uvm_config_db#(apb_agt_cfg)::set(this, $sformatf("apb_agent_h[%0d]*", i), "apb_agt_cfg",
                                     apb_agt_cfg_h[i]);
    apb_agent_h = new[env_cfg_h.apb_agent_count];
    foreach (apb_agent_h[i])
    apb_agent_h[i] = apb_agent::type_id::create($sformatf("apb_agent_h[%0d]", i), this);
  endfunction
endclass





interface apb2core (
    input bit CLK
);
  logic PCLK;
  logic PRESETn;
  logic PSEL_i;
  logic PWRITE_i;
  logic PENABLE_i;
  logic [2:0] PADDR_i;
  logic [7:0] PWDATA_i;
  logic [7:0] PRDATA_o;
  logic PREADY_o;
  logic PSLVERR_o;
  assign PCLK = CLK;

  clocking drv_cb @(posedge CLK);
    default input #1 output #0;
    output PCLK;
    output PRESETn;
    output PSEL_i;
    output PWRITE_i;
    output PENABLE_i;
    output PADDR_i;
    output PWDATA_i;
    input PRDATA_o;
    input PREADY_o;
    input PSLVERR_o;
  endclocking

  clocking mon_cb @(posedge CLK);
    default input #1 output #0;
    input PCLK;
    input PRESETn;
    input PSEL_i;
    input PWRITE_i;
    input PENABLE_i;
    input PADDR_i;
    input PWDATA_i;
    input PRDATA_o;
    input PREADY_o;
    input PSLVERR_o;
  endclocking

  modport drv_mp(clocking drv_cb);

  modport mon_mp(clocking mon_cb);
  // always @(drv_cb) $display("[%0t] IF CLK posedge", $time);
  // 
  // always @(drv_cb) $display("[%0t] IF CLK posedge", $time);

  //assertion

  // property single_stable;
  //  @(posedge CLK) $rose(PSEL_i)|->($stable(PWRITE_i)&& $stable(PADDR_i) && $stable(PWDATA_i))until PREADY_o[->1];
  // endproperty

  // property penable_stable;
  //  @(posedge CLK) $rose(PSEL_i)|->($stable(PSEL_i)&& $stable(PENABLE_i))until PREADY_o[->1];
  // endproperty

  // property psel_to_pready;
  //  @(posedge CLK) (PSEL_i && PENABLE_i)|-> ##[0:$]PREADY_o;
  // endproperty

  // property address_rev;
  //  @(posedge CLK) PSEL_i |-> ((PADDR_i!=3'b100)||(PADDR_i!=3'b110)||(PADDR_i!=3'b111));
  // endproperty 

  // property penable_deassert;
  //  @(posedge CLK)(!PSEL_i)|-> (!PENABLE_i);
  // endproperty

  // property vaild_write_data_transfer;
  //  @(posedge CLK) (PSEL_i && PENABLE_i && PWRITE_i) |-> (PWDATA_i !='hx);
  // endproperty

  // property valid_read_data_transfer;
  //  @(posedge CLK) (PSEL_i && PENABLE_i && !PWRITE_i) |-> (PRDATA_o !='hx);
  // endproperty

  // property pready_low;
  //  @(posedge CLK) (PSEL_i && !PENABLE_i) |-> (!PREADY_o);
  // endproperty

  // property pready_deassert;
  //  @(posedge CLK)(!PSEL_i)|-> (!PREADY_o);
  // endproperty


  // s1 : assert property(single_stable)
  //          $display("signal_stable done");
  //      else
  //        $display("signal_stable not done");
  // s2 : assert property(penable_stable)
  //        $display("penable_stable done");
  //      else
  //        $display("penable_stable not done");

  // s3 : assert property(psel_to_pready)
  //        $display("psel_to_pready done");
  //      else
  //        $display("psel_to_pready not done");

  // s4 : assert property(address_rev)
  //        $display("address_rev done");
  //      else
  //        $display(" address_rev not done");
  // s5 : assert property(penable_deassert)
  //       $display("penable_deassert done");
  //      else
  //        $display("penable_deassert not done");
  // s6 : assert property(vaild_write_data_transfer)
  //       $display("vaild_wriite_data_transfer done");
  //      else
  //        $display("vaild_write_data_transfer not done");
  // s7 : assert property(valid_read_data_transfer)
  //       $display("vaild_read_data_transfer  done");
  //      else
  //        $display("vaild_read_data_transfer not done");
  // s8 : assert property(pready_low)
  //       $display("pready_low done");
  //      else
  //        $display("pready_low not done");
  // s9 : assert property(pready_deassert)
  //       $display("pready_deassert done");
  //      else
  //        $display("pready_deassert not done");


  //-------------- Assertions -------------
  property signals_stable;
    @(posedge CLK) $rose(
        PSEL_i
    ) |-> ($stable(
        PWRITE_i
    ) && $stable(
        PADDR_i
    ) && $stable(
        PWDATA_i
    )) until PREADY_o [-> 1];
  endproperty

  property penable_stable;
    @(posedge CLK) $rose(
        PENABLE_i
    ) |-> ($stable(
        PSEL_i
    ) && $stable(
        PENABLE_i
    )) until PREADY_o [-> 1];
  endproperty

  property psel_to_pready;
    @(posedge CLK) (PSEL_i && PENABLE_i) |-> ##[0:$] PREADY_o;
  endproperty

  property address_reserved;
    @(posedge CLK) PSEL_i |-> ((PADDR_i != 3'b100) || (PADDR_i != 3'b110) || (PADDR_i != 3'b111));
  endproperty

  property penable_deassert;
    @(posedge CLK) (!PSEL_i) |-> (!PENABLE_i);
  endproperty

  property valid_write_data_transfer;
    @(posedge CLK) (PSEL_i && PENABLE_i && PWRITE_i) |-> (PWDATA_i !== 'hx);
  endproperty

  property valid_read_data_transfer;
    @(posedge CLK) (PSEL_i && PENABLE_i && (!PWRITE_i)) |-> (PRDATA_o !== 'hx);
  endproperty

  property pready_low_at_start;
    @(posedge CLK) (PSEL_i && (!PENABLE_i)) |-> (!PREADY_o);
  endproperty

  property pready_deassert;
    @(posedge CLK) (!PSEL_i) |-> (!PREADY_o);
  endproperty

  SIGNAL_STABLE :
  assert property (signals_stable) $info("signal stablity is verified");
  else $error("signal stablity is not verified");

  PENABLE_STABLE :
  assert property (penable_stable) $info("Penable is stable until Pready is high");
  else $error("Penable is not stable");
  PSEL_TO_PREADY :
  assert property (psel_to_pready) $info("Psel&Penable to Pready is verified ");
  else $error("Psel&Pneable is not verified");

  ADDRESS_RESERVED :
  assert property (address_reserved) $info("reserved addresses are verified");
  else $error("Reserved addresses are not verified");

  PENABLE_DEASSERT :
  assert property (penable_deassert)
    $info("When Psel goes low even Penable should go low is verified");
  else $error("When Psel goes low even Penable should go low is verified");
  PWDATA_TRANSFER :
  assert property (valid_write_data_transfer) $info("Valid Write Data Transfer");
  else $error("Valid write Data Transfer Failed");
  PRDATA_TRANSFER :
  assert property (valid_read_data_transfer) $info("valid read data transfer");
  else $error("valid read data transfer failed");
  PREADY_START :
  assert property (pready_low_at_start) $info("Pready is low at the start");
  else $error("Pready is not low at the start");
  PREADY_DEASSERT :
  assert property (pready_deassert) $info("Pready is low when Psel goes low");
  else $error("Pready is not low when Psel is low");
endinterface

interface core2spi (
    input bit clock
);
  logic sclk_o;
  logic ss_o;
  logic miso_i;
  logic mosi_o;
  logic spi_interrupt_request;
  clocking drv_cb @(posedge clock);
    default input #1 output #0;
    input sclk_o;
    input ss_o;
    output miso_i;
    input mosi_o;
    input spi_interrupt_request;
  endclocking

  clocking mon_cb @(posedge clock);
    default input #1 output #0;
    input sclk_o;
    input ss_o;
    input miso_i;
    input mosi_o;
    input spi_interrupt_request;
  endclocking

  modport drv_mp(clocking drv_cb);

  modport mon_mp(clocking mon_cb);

endinterface



class spi_txn extends uvm_sequence_item;
  `uvm_object_utils(spi_txn)
  function new(string name = "spi_txn");
    super.new(name);
  endfunction
  bit ss;
  bit sclk;
  rand bit [7:0] miso;
  bit [7:0] mosi;
  bit spi_interrupt_req;
  constraint miso_dist {
    miso dist {
      [8'h00 : 8'h0f] := 50,
      [8'h1f : 8'hff] := 50
    };
  }
  function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field("SS", this.ss, 1, UVM_BIN);
    // printer.print_field("MOSI", this.mosi, 8, UVM_DEC);
    // printer.print_field("MISO", this.miso, 8, UVM_DEC);
    printer.print_field("MOSI", this.mosi, 8, UVM_BIN);
    printer.print_field("MISO", this.miso, 8, UVM_BIN);
    printer.print_field("spi_interrupt_req", this.spi_interrupt_req, 1, UVM_BIN);
  endfunction
endclass


class spi_driver extends uvm_driver #(spi_txn);
  `uvm_component_utils(spi_driver)
  function new(string name = "spi_driver", uvm_component parent);
    super.new(name, parent);
  endfunction
  bit cpha;
  bit cpol;
  bit lsbfe;
  bit [7:0] ctrl;
  spi_agt_cfg spi_agt_cfg_h;
  virtual core2spi core2spi_h;
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(spi_agt_cfg)::get(this, "", "spi_agt_cfg", spi_agt_cfg_h))
      `uvm_fatal(get_full_name, "Config fetch failed")
    core2spi_h = spi_agt_cfg_h.core2spi_h;
    // lsbfe = 1;
    // cpha = 0;
    // cpol = 0;
  endfunction
  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      send_to_dut(req);
      seq_item_port.item_done();
    end
  endtask
  task send_to_dut(spi_txn spi_txn_h);

    // wait (!core2spi_h.drv_cb.ss_o);
    // begin
    //   if (lsbfe) begin
    //     if ((!cpha) && (!cpol)) begin
    //       core2spi_h.drv_cb.miso_i <= spi_txn_h.miso[0];
    //       for (int i = 1; i <= 7; i++) begin
    //         @(negedge core2spi_h.drv_cb.sclk_o);
    //         core2spi_h.drv_cb.miso_i <= spi_txn_h.miso[i];
    //       end
    //     end else if ((!cpha) && (cpol)) begin
    //       core2spi_h.drv_cb.miso_i <= spi_txn_h.miso[0];
    //       for (int i = 1; i <= 7; i++) begin
    //         @(posedge core2spi_h.drv_cb.sclk_o);
    //         core2spi_h.drv_cb.miso_i <= spi_txn_h.miso[i];
    //       end
    //     end else if ((cpha) && (!cpol)) begin
    //       for (int i = 0; i <= 7; i++) begin
    //         @(posedge core2spi_h.drv_cb.sclk_o);
    //         core2spi_h.drv_cb.miso_i <= spi_txn_h.miso[i];
    //       end
    //     end else begin
    //       for (int i = 0; i <= 7; i++) begin
    //         @(negedge core2spi_h.drv_cb.sclk_o);
    //         core2spi_h.drv_cb.miso_i <= spi_txn_h.miso[i];
    //       end
    //     end
    //   end else begin
    //     if ((!cpha) && (!cpol)) begin
    //       core2spi_h.drv_cb.miso_i <= spi_txn_h.miso[7];
    //       for (int i = 6; i >= 0; i--) begin
    //         @(negedge core2spi_h.drv_cb.sclk_o);
    //         core2spi_h.drv_cb.miso_i <= spi_txn_h.miso[i];
    //       end
    //     end else if ((!cpha) && (cpol)) begin
    //       core2spi_h.drv_cb.miso_i <= spi_txn_h.miso[7];
    //       for (int i = 6; i >= 0; i--) begin
    //         @(posedge core2spi_h.drv_cb.sclk_o);
    //         core2spi_h.drv_cb.miso_i <= spi_txn_h.miso[i];
    //       end
    //     end else if ((cpha) && (!cpol)) begin
    //       for (int i = 7; i >= 0; i--) begin
    //         @(posedge core2spi_h.drv_cb.sclk_o);
    //         core2spi_h.drv_cb.miso_i <= spi_txn_h.miso[i];
    //       end
    //     end else begin
    //       for (int i = 7; i >= 0; i--) begin
    //         @(negedge core2spi_h.drv_cb.sclk_o);
    //         core2spi_h.drv_cb.miso_i <= spi_txn_h.miso[i];
    //       end
    //     end
    //   end
    // end

    // lsbfe = spi_agt_cfg_h.ctrl[0];
    // cpha = spi_agt_cfg_h.ctrl[2];
    // cpol = spi_agt_cfg_h.ctrl[3];

    // Wait for slave select
    wait (!core2spi_h.drv_cb.ss_o);

    // CPHA = 0 → drive first bit immediately
    if (!cpha) core2spi_h.drv_cb.miso_i <= spi_txn_h.miso[lsbfe?0 : 7];

    // Drive 8 bits
    for (int i = (cpha ? 0 : 1); i < 8; i++) begin

      if (cpha ^ cpol) @(posedge core2spi_h.drv_cb.sclk_o);
      else @(negedge core2spi_h.drv_cb.sclk_o);

      core2spi_h.drv_cb.miso_i <= spi_txn_h.miso[lsbfe?i : (7-i)];
    end


    wait (core2spi_h.drv_cb.ss_o);

  endtask
endclass


class spi_monitor extends uvm_monitor;
  `uvm_component_utils(spi_monitor)
  uvm_analysis_port #(spi_txn) port_h;
  spi_agt_cfg spi_agt_cfg_h;
  virtual core2spi core2spi_h;
  // bit cpha;
  // bit cpol;
  // bit lsbfe;

  bit [7:0] ctrl;
  function new(string name = "spi_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(spi_agt_cfg)::get(this, "", "spi_agt_cfg", spi_agt_cfg_h))
      `uvm_fatal(get_full_name, "Config fetch failed")
    core2spi_h = spi_agt_cfg_h.core2spi_h;
    port_h = new("port_h", this);

  endfunction
  task run_phase(uvm_phase phase);
    forever begin
      // lsbfe = 1;
      // cpha  = 0;
      // cpol  = 0;
      sample ();
    end
  endtask
  task sample ();


    int bit_idx;
    spi_txn spi_txn_h;
    spi_txn_h = spi_txn::type_id::create("spi_txn_h");
    // wait (!core2spi_h.mon_cb.ss_o);
    // begin
    //   if (lsbfe) begin
    //     for (int i = 0; i <= 7; i++) begin
    //       if ((!cpha && !cpol) || (cpha && cpol)) begin
    //         @(posedge core2spi_h.mon_cb.sclk_o);
    //         begin
    //           spi_txn_h.miso[i] = core2spi_h.mon_cb.miso_i;
    //           spi_txn_h.mosi[i] = core2spi_h.mon_cb.mosi_o;
    //           spi_txn_h.ss = core2spi_h.mon_cb.ss_o;
    //           spi_txn_h.spi_interrupt_req = core2spi_h.mon_cb.spi_interrupt_request;
    //         end
    //       end else begin
    //         @(negedge core2spi_h.mon_cb.sclk_o);
    //         begin
    //           spi_txn_h.miso[i] = core2spi_h.mon_cb.miso_i;
    //           spi_txn_h.mosi[i] = core2spi_h.mon_cb.mosi_o;
    //           spi_txn_h.ss = core2spi_h.mon_cb.ss_o;
    //           spi_txn_h.spi_interrupt_req = core2spi_h.mon_cb.spi_interrupt_request;
    //         end
    //       end
    //     end
    //   end else begin
    //     for (int i = 7; i >= 0; i--) begin
    //       if (((!cpha) && (!cpol)) || ((cpha) && (cpol))) begin
    //         @(posedge core2spi_h.mon_cb.sclk_o);
    //         begin
    //           spi_txn_h.miso[i] = core2spi_h.mon_cb.miso_i;
    //           spi_txn_h.mosi[i] = core2spi_h.mon_cb.mosi_o;
    //           spi_txn_h.ss = core2spi_h.mon_cb.ss_o;
    //           spi_txn_h.spi_interrupt_req = core2spi_h.mon_cb.spi_interrupt_request;
    //         end
    //       end else begin
    //         @(negedge core2spi_h.mon_cb.sclk_o) begin
    //           spi_txn_h.miso[i] = core2spi_h.mon_cb.miso_i;
    //           spi_txn_h.mosi[i] = core2spi_h.mon_cb.mosi_o;
    //           spi_txn_h.ss = core2spi_h.mon_cb.ss_o;
    //           spi_txn_h.spi_interrupt_req = core2spi_h.mon_cb.spi_interrupt_request;
    //         end
    //       end
    //     end
    //   end
    // end
    // // `uvm_info(get_full_name, $sformatf("%s", spi_txn_h.sprint()), UVM_MEDIUM)
    // port_h.write(spi_txn_h);
    // 
    wait (!core2spi_h.mon_cb.ss_o);

    // Collect 8 bits
    for (int i = 0; i < 8; i++) begin

      bit_idx = lsbfe ? i : (7 - i);

      // Sampling edge
      if (cpha ^ cpol) @(negedge core2spi_h.mon_cb.sclk_o);
      else @(posedge core2spi_h.mon_cb.sclk_o);

      spi_txn_h.miso[bit_idx]     = core2spi_h.mon_cb.miso_i;
      spi_txn_h.mosi[bit_idx]     = core2spi_h.mon_cb.mosi_o;
      spi_txn_h.ss                = core2spi_h.mon_cb.ss_o;
      spi_txn_h.spi_interrupt_req = core2spi_h.mon_cb.spi_interrupt_request;

    end

    // `uvm_info(get_type_name(), $sformatf("Transaction received from SPI slave:\n%s",
    // spi_txn_h.sprint()), UVM_LOW)

    port_h.write(spi_txn_h);

    @(core2spi_h.mon_cb);
  endtask
endclass

class spi_seq extends uvm_sequence #(spi_txn);
  `uvm_object_utils(spi_seq)
  function new(string name = "spi_seq");
    super.new(name);
  endfunction
  task body();
    req = spi_txn::type_id::create("req");
    repeat (1) begin
      start_item(req);
      assert (req.randomize);
      finish_item(req);
    end
  endtask
endclass


class spi_seqr extends uvm_sequencer #(spi_txn);
  `uvm_component_utils(spi_seqr)
  function new(string name = "spi_seqr", uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class spi_agent extends uvm_agent;
  `uvm_component_utils(spi_agent)
  function new(string name = "spi_agent", uvm_component parent);
    super.new(name, parent);
  endfunction
  spi_agt_cfg spi_agt_cfg_h;
  spi_driver spi_driver_h;
  spi_seqr spi_seqr_h;
  spi_monitor spi_monitor_h;
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(spi_agt_cfg)::get(this, "", "spi_agt_cfg", spi_agt_cfg_h))
      `uvm_fatal(get_full_name, "Config fetch failed")
    if (spi_agt_cfg_h.is_active) begin

      spi_driver_h = spi_driver::type_id::create("spi_driver_h", this);
      spi_seqr_h   = spi_seqr::type_id::create("spi_seqr_h", this);
    end

    spi_monitor_h = spi_monitor::type_id::create("spi_monitor_h", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    if (spi_agt_cfg_h.is_active == UVM_ACTIVE)
      spi_driver_h.seq_item_port.connect(spi_seqr_h.seq_item_export);
  endfunction
endclass



class spi_agt_top extends uvm_env;
  `uvm_component_utils(spi_agt_top)
  function new(string name = "spi_agt_top", uvm_component parent);
    super.new(name, parent);
  endfunction
  spi_agent spi_agent_h[];
  spi_agt_cfg spi_agt_cfg_h[];
  env_cfg env_cfg_h;
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(env_cfg)::get(this, "", "env_cfg", env_cfg_h))
      `uvm_fatal(get_full_name, "Config fetch failed")
    spi_agt_cfg_h = env_cfg_h.spi_agt_cfg_h;
    foreach (spi_agt_cfg_h[i])
    uvm_config_db#(spi_agt_cfg)::set(this, $sformatf("spi_agent_h[%0d]*", i), "spi_agt_cfg",
                                     spi_agt_cfg_h[i]);
    spi_agent_h = new[env_cfg_h.spi_agent_count];
    foreach (spi_agent_h[i])
    spi_agent_h[i] = spi_agent::type_id::create($sformatf("spi_agent_h[%0d]", i), this);
  endfunction
endclass




class sbandref extends uvm_scoreboard;
  `uvm_component_utils(sbandref)
  uvm_tlm_analysis_fifo #(spi_txn) spi_fifo_h[];
  uvm_tlm_analysis_fifo #(apb_txn) apb_fifo_h[];
  env_cfg env_cfg_h;
  apb_txn apb_txn_h;
  spi_txn spi_txn_h;

  spi_reg_block spi_rm;
  uvm_reg_data_t data;
  uvm_status_e status;

  apb_txn apb_txn_cg_h;
  spi_txn spi_txn_cg_h;
  function void build_phase(uvm_phase phase);

    if (!uvm_config_db#(spi_reg_block)::get(this, "", "spi_reg_block", spi_rm))
      `uvm_fatal("NO_REG", "Register model handle not found")
    if (!uvm_config_db#(env_cfg)::get(this, "", "env_cfg", env_cfg_h))
      `uvm_fatal(get_type_name, "Config fetch failed")
    spi_fifo_h = new[env_cfg_h.spi_agent_count];
    apb_fifo_h = new[env_cfg_h.apb_agent_count];
    foreach (spi_fifo_h[i]) spi_fifo_h[i] = new($sformatf("spi_fifo_h[%0d]", i), this);
    foreach (apb_fifo_h[i]) apb_fifo_h[i] = new($sformatf("apb_fifo_h[%0d]", i), this);

    if (env_cfg_h.has_functional_coverage) begin
      apb_txn_cg_h = apb_txn::type_id::create("apb_txn_cg_h");
      spi_txn_cg_h = spi_txn::type_id::create("spi_txn_cg_h");
    end
  endfunction

  covergroup apb_txn_cg;
    option.per_instance = 1;
    PRESETn_cp: coverpoint apb_txn_cg_h.PRESETn {bins PRESETn = {0, 1};}
    PADDR_cp: coverpoint apb_txn_cg_h.PADDR {bins PADDR[] = {0, 1, 2, 5};}
    PSEL_cp: coverpoint apb_txn_cg_h.PSEL {bins PSEL = {0, 1};}
    PENABLE_cp: coverpoint apb_txn_cg_h.PENABLE {bins PENABLE = {0, 1};}
    PWRITE_cp: coverpoint apb_txn_cg_h.PWRITE {bins PWRITE[] = {0, 1};}
    PREADY_cp: coverpoint apb_txn_cg_h.PREADY {bins PREADY = {0, 1};}
    PSLVERR_cp: coverpoint apb_txn_cg_h.PSLVERR {bins PSLVERR = {0, 1};}
    PWDATA_cp: coverpoint apb_txn_cg_h.PWDATA {
      bins PWDATA_LOW = {[8'h00 : 8'h0f]}; bins PWDATA_HIGH = {[8'h1f : 8'hff]};
    }
    cross PSEL_cp, PENABLE_cp;
    cross PSEL_cp, PENABLE_cp, PREADY_cp;
  endgroup

  covergroup spi_txn_cg;
    option.per_instance = 1;
    SS_cp: coverpoint spi_txn_cg_h.ss {bins ss = {0, 1};}
    SPI_INT_REQ_cp: coverpoint spi_txn_cg_h.spi_interrupt_req {bins spi_interrupt_req = {0, 1};}
    MISO_cp: coverpoint spi_txn_cg_h.miso {
      bins miso_LOW = {[8'h00 : 8'h0f]}; bins miso_HIGH = {[8'h1f : 8'hff]};
    }
    MOSI_cp: coverpoint spi_txn_cg_h.mosi {
      bins mosi_LOW = {[8'h00 : 8'h0f]}; bins mosi_HIGH = {[8'h1f : 8'hff]};
    }
  endgroup

  function new(string name = "sbandref", uvm_component parent);
    super.new(name, parent);


    apb_txn_cg = new;

    spi_txn_cg = new;
  endfunction
  task run_phase(uvm_phase phase);
    foreach (apb_fifo_h[i]) begin

      fork
        begin
          forever begin
            apb_fifo_h[i].get(apb_txn_h);

            apb_txn_cg_h = apb_txn_h;
            apb_txn_cg.sample();
            if (apb_txn_h.PADDR == 'd5) compare_data(apb_txn_h);
          end

        end
        forever begin
          spi_fifo_h[i].get(spi_txn_h);

          spi_txn_cg_h = spi_txn_h;
          spi_txn_cg.sample();
        end
      join
    end
  endtask


  task compare_data(apb_txn apb_txn_h);
    wait (apb_txn_h != null);
    wait (spi_txn_h != null);

    if (apb_txn_h.PWRITE && (apb_txn_h.PADDR == 3'b101)) begin
      $display(
          "*******************************************SCOREBOARD***********************************************************");
      if (apb_txn_h.PWDATA == spi_txn_h.mosi) begin
        `uvm_info(get_type_name(), "data compare successfull", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("apb_txn_h= \n%s,\nspi_txn_h= \n%s",
                                             apb_txn_h.sprint(), spi_txn_h.sprint()), UVM_LOW)
      end else begin
        `uvm_error(get_type_name(), "data not match")

        `uvm_info(get_type_name(), $sformatf(
                  "apb_txn_h= \n%s,\nspi_txn_h= \n%s", apb_txn_h.sprint(), spi_txn_h.sprint()),
                  UVM_LOW)
      end

      $display(
          "*******************************************SCOREBOARD***********************************************************");
    end else if (!apb_txn_h.PWRITE && (apb_txn_h.PADDR == 3'b101)) begin

      spi_rm.data_reg.read(status, data, UVM_BACKDOOR);
      $display(
          "*******************************************SCOREBOARD***********************************************************");
      if (data == spi_txn_h.miso) begin
        `uvm_info(get_type_name(), "data compare successfull", UVM_LOW)

        `uvm_info(get_type_name(), $sformatf("apb_txn_h= \n%s,\n apb_txn_h= \n%s",
                                             apb_txn_h.sprint(), spi_txn_h.sprint()), UVM_LOW)

      end else begin
        `uvm_error(get_type_name(), "data not match")
        `uvm_info(get_type_name(), $sformatf(
                  "scoreboard :\n apb_txn_h= \n%s,\n apb_txn_h= \n%s",
                  apb_txn_h.sprint(),
                  spi_txn_h.sprint()
                  ), UVM_LOW)
      end
      $display(
          "*******************************************SCOREBOARD***********************************************************");
    end
    if (apb_txn_h.PWRITE == 0) spi_txn_h = null;
    apb_txn_h = null;
  endtask
endclass


class virtual_seqr extends uvm_sequencer;
  `uvm_component_utils(virtual_seqr)
  function new(string name = "virtual_seqr", uvm_component parent);
    super.new(name, parent);
  endfunction
  env_cfg  env_cfg_h;
  apb_seqr apb_seqr_h[];
  spi_seqr spi_seqr_h[];
  function void build_phase(uvm_phase phase);

    if (!uvm_config_db#(env_cfg)::get(this, "", "env_cfg", env_cfg_h))
      `uvm_fatal(get_type_name, "Config fetch failed")
    apb_seqr_h = new[env_cfg_h.apb_agent_count];
    spi_seqr_h = new[env_cfg_h.spi_agent_count];
    foreach (apb_seqr_h[i])
    apb_seqr_h[i] = apb_seqr::type_id::create($sformatf("apb_seqr_h[%0d]", i), this);
    foreach (spi_seqr_h[i])
    spi_seqr_h[i] = spi_seqr::type_id::create($sformatf("spi_seqr_h[%0d]", i), this);
  endfunction
endclass

class apb_seq extends uvm_sequence #(apb_txn);
  `uvm_object_utils(apb_seq)
  function new(string name = "apb_seq");
    super.new(name);
  endfunction
endclass


class apb_seq_lpm extends apb_seq;
  `uvm_object_utils(apb_seq_lpm)
  function new(string name = "apb_seq_lpm");
    super.new(name);
  endfunction
  task body();
    req = apb_txn::type_id::create("apb_txn");

    start_item(req);
    assert (req.randomize() with {PADDR == 'd5 && PWRITE == 'b1;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PWRITE == 'b1 && PADDR == 'd1 && PWDATA == 8'h02;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PWRITE == 'b1 && PADDR == 'd0 && PWDATA[6] == 'b0;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd5 && PWRITE == 'b1;});
    finish_item(req);


    start_item(req);
    assert (req.randomize() with {PWRITE == 'b1 && PADDR == 'd0 && PWDATA[6] == 'b1;});
    finish_item(req);


    start_item(req);
    assert (req.randomize() with {PADDR == 'd5 && PWRITE == 'b1;});
    finish_item(req);



  endtask
endclass



class apb_seq_read extends apb_seq;

  `uvm_object_utils(apb_seq_read)
  function new(string name = "apb_seq_read");
    super.new(name);
  endfunction
  task body();
    req = apb_txn::type_id::create("apb_txn");
    start_item(req);
    assert (req.randomize() with {PWRITE == 'b0 && PADDR == 'd5;});
    finish_item(req);
  endtask
endclass

class apb_seq_cpol0_cpha0_lsbfe0 extends apb_seq;
  `uvm_object_utils(apb_seq_cpol0_cpha0_lsbfe0)

  function new(string name = "apb_seq_cpol0_cpha0_lsbfe0");
    super.new(name);
  endfunction
  task body();
    req = apb_txn::type_id::create("apb_txn");
    //cpol 3 cpha 2
    // 0        0
    start_item(req);
    assert (req.randomize() with {
      PADDR == 'd0 && PWDATA[0] == 'b0 && PWDATA[3] == 'b0 && PWDATA[2] == 'b0 && PWRITE == 'b1 && PWDATA[4] == 'b1  && PWDATA[1] == 'b1 && PWDATA[7] == 'b1  && PWDATA[6] == 'b1  && PWDATA[5] == 'b1;
    });
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd1 && PWRITE == 'b1 && PWDATA == 'd0;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd2 && PWRITE == 'b1 && PWDATA == 8'h10;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd5 && PWRITE == 'b1;});
    finish_item(req);
  endtask
endclass

class apb_seq_cpol0_cpha1_lsbfe0 extends apb_seq;
  `uvm_object_utils(apb_seq_cpol0_cpha1_lsbfe0)

  function new(string name = "apb_seq_cpol0_cpha1_lsbfe0");
    super.new(name);
  endfunction
  task body();
    req = apb_txn::type_id::create("apb_txn");
    //cpol 3 cpha 2
    // 0       1
    start_item(req);
    assert (req.randomize() with {
      PADDR == 'd0 && PWDATA[0] == 'b0 && PWDATA[3] == 'b0 && PWDATA[2] == 'b1 && PWRITE == 'b1 && PWDATA[4] == 'b1  && PWDATA[1] == 'b1 && PWDATA[7] == 'b1  && PWDATA[6] == 'b1  && PWDATA[5] == 'b1;
    });
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd1 && PWRITE == 'b1 && PWDATA == 'd0;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd2 && PWRITE == 'b1;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd5 && PWRITE == 'b1;});
    finish_item(req);
  endtask
endclass


class apb_seq_cpol1_cpha0_lsbfe0 extends apb_seq;
  `uvm_object_utils(apb_seq_cpol1_cpha0_lsbfe0)

  function new(string name = "apb_seq_cpol1_cpha0_lsbfe0");
    super.new(name);
  endfunction
  task body();
    req = apb_txn::type_id::create("apb_txn");
    //cpol 3 cpha 2
    // 1       0
    start_item(req);
    assert (req.randomize() with {
      PADDR == 'd0 && PWDATA[0] == 'b0 && PWDATA[3] == 'b1 && PWDATA[2] == 'b0 && PWRITE == 'b1 && PWDATA[4] == 'b1  && PWDATA[1] == 'b1 && PWDATA[7] == 'b1  && PWDATA[6] == 'b1  && PWDATA[5] == 'b1;
    });
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd1 && PWRITE == 'b1 && PWDATA == 'd0;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd2 && PWRITE == 'b1;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd5 && PWRITE == 'b1;});
    finish_item(req);
  endtask
endclass


class apb_seq_cpol1_cpha1_lsbfe0 extends apb_seq;
  `uvm_object_utils(apb_seq_cpol1_cpha1_lsbfe0)

  function new(string name = "apb_seq_cpol1_cpha1_lsbfe0");
    super.new(name);
  endfunction
  task body();
    req = apb_txn::type_id::create("apb_txn");
    //cpol 3 cpha 2
    // 1       1
    start_item(req);
    assert (req.randomize() with {
      PADDR == 'd0 && PWDATA[0] == 'b0 && PWDATA[3] == 'b1 && PWDATA[2] == 'b1 && PWRITE == 'b1 && PWDATA[4] == 'b1  && PWDATA[1] == 'b1 && PWDATA[7] == 'b1  && PWDATA[6] == 'b1  && PWDATA[5] == 'b1;
    });
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd1 && PWRITE == 'b1 && PWDATA == 'd0;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd2 && PWRITE == 'b1;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd5 && PWRITE == 'b1;});
    finish_item(req);
  endtask
endclass

class apb_seq_cpol0_cpha0_lsbfe1 extends apb_seq;
  `uvm_object_utils(apb_seq_cpol0_cpha0_lsbfe1)

  function new(string name = "apb_seq_cpol0_cpha0_lsbfe1");
    super.new(name);
  endfunction
  task body();
    req = apb_txn::type_id::create("apb_txn");
    //cpol 3 cpha 2
    // 0        0
    start_item(req);
    assert (req.randomize() with {
      PADDR == 'd0 && PWDATA[0] == 'b1 && PWDATA[3] == 'b0 && PWDATA[2] == 'b0 && PWRITE == 'b1 && PWDATA[4] == 'b1  && PWDATA[1] == 'b1 && PWDATA[7] == 'b1  && PWDATA[6] == 'b1  && PWDATA[5] == 'b1;
    });
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd1 && PWRITE == 'b1 && PWDATA == 'd0;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd2 && PWRITE == 'b1;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd5 && PWRITE == 'b1;});
    finish_item(req);
  endtask
endclass

class apb_seq_cpol0_cpha1_lsbfe1 extends apb_seq;
  `uvm_object_utils(apb_seq_cpol0_cpha1_lsbfe1)

  function new(string name = "apb_seq_cpol0_cpha1_lsbfe1");
    super.new(name);
  endfunction
  task body();
    req = apb_txn::type_id::create("apb_txn");
    //cpol 3 cpha 2
    // 0       1
    start_item(req);
    assert (req.randomize() with {
      PADDR == 'd0 && PWDATA[0] == 'b1 && PWDATA[3] == 'b0 && PWDATA[2] == 'b1 && PWRITE == 'b1 && PWDATA[4] == 'b1  && PWDATA[1] == 'b1 && PWDATA[7] == 'b1  && PWDATA[6] == 'b1  && PWDATA[5] == 'b1;
    });
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd1 && PWRITE == 'b1 && PWDATA == 'd0;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd2 && PWRITE == 'b1;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd5 && PWRITE == 'b1;});
    finish_item(req);
  endtask
endclass


class apb_seq_cpol1_cpha0_lsbfe1 extends apb_seq;
  `uvm_object_utils(apb_seq_cpol1_cpha0_lsbfe1)

  function new(string name = "apb_seq_cpol1_cpha0_lsbfe1");
    super.new(name);
  endfunction
  task body();
    req = apb_txn::type_id::create("apb_txn");
    //cpol 3 cpha 2
    // 1       0
    start_item(req);
    assert (req.randomize() with {
      PADDR == 'd0 && PWDATA[0] == 'b1 && PWDATA[3] == 'b1 && PWDATA[2] == 'b0 && PWRITE == 'b1 && PWDATA[4] == 'b1  && PWDATA[1] == 'b1 && PWDATA[7] == 'b1  && PWDATA[6] == 'b1  && PWDATA[5] == 'b1;
    });
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd1 && PWRITE == 'b1 && PWDATA == 'd0;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd2 && PWRITE == 'b1;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd5 && PWRITE == 'b1;});
    finish_item(req);
  endtask
endclass


class apb_seq_cpol1_cpha1_lsbfe1 extends apb_seq;
  `uvm_object_utils(apb_seq_cpol1_cpha1_lsbfe1)
  function new(string name = "apb_seq_cpol1_cpha1_lsbfe1");
    super.new(name);
  endfunction
  task body();
    req = apb_txn::type_id::create("apb_txn");
    //cpol 3 cpha 2
    // 1       1
    start_item(req);
    assert (req.randomize() with {
      PADDR == 'd0 && PWDATA[0] == 'b1 && PWDATA[3] == 'b1 && PWDATA[2] == 'b1 && PWRITE == 'b1 && PWDATA[4] == 'b1  && PWDATA[1] == 'b1 && PWDATA[7] == 'b1  && PWDATA[6] == 'b1  && PWDATA[5] == 'b1;
    });
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd1 && PWRITE == 'b1 && PWDATA == 'd0;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd2 && PWRITE == 'b1;});
    finish_item(req);

    start_item(req);
    assert (req.randomize() with {PADDR == 'd5 && PWRITE == 'b1;});
    finish_item(req);
  endtask
endclass


class virtual_seq extends uvm_sequence;
  `uvm_object_utils(virtual_seq)
  `uvm_declare_p_sequencer(virtual_seqr)
  function new(string name = "virtual_seq");
    super.new(name);
  endfunction

  // bit CPOL, CPHA, LSBFE;
  spi_seq spi_seq_h;
  apb_seq_cpol0_cpha0_lsbfe0 apb_seq_cpol0_cpha0_lsbfe0_h;
  apb_seq_cpol0_cpha1_lsbfe0 apb_seq_cpol0_cpha1_lsbfe0_h;
  apb_seq_cpol1_cpha0_lsbfe0 apb_seq_cpol1_cpha0_lsbfe0_h;
  apb_seq_cpol1_cpha1_lsbfe0 apb_seq_cpol1_cpha1_lsbfe0_h;
  apb_seq_cpol0_cpha0_lsbfe1 apb_seq_cpol0_cpha0_lsbfe1_h;
  apb_seq_cpol0_cpha1_lsbfe1 apb_seq_cpol0_cpha1_lsbfe1_h;
  apb_seq_cpol1_cpha0_lsbfe1 apb_seq_cpol1_cpha0_lsbfe1_h;
  apb_seq_cpol1_cpha1_lsbfe1 apb_seq_cpol1_cpha1_lsbfe1_h;
  apb_seq_read apb_seq_read_h;
  task body();
    // if (starting_phase != null) starting_phase.raise_objection(this);
    spi_seq_h = spi_seq::type_id::create("spi_seq_h");
    apb_seq_cpol0_cpha0_lsbfe0_h =
        apb_seq_cpol0_cpha0_lsbfe0::type_id::create("apb_seq_cpol0_cpha0_lsbfe0_h");
    apb_seq_cpol0_cpha1_lsbfe0_h =
        apb_seq_cpol0_cpha1_lsbfe0::type_id::create("apb_seq_cpol0_cpha1_lsbfe0_h");
    apb_seq_cpol1_cpha0_lsbfe0_h =
        apb_seq_cpol1_cpha0_lsbfe0::type_id::create("apb_seq_cpol1_cpha0_lsbfe0_h");
    apb_seq_cpol1_cpha1_lsbfe0_h =
        apb_seq_cpol1_cpha1_lsbfe0::type_id::create("apb_seq_cpol1_cpha1_lsbfe0_h");
    apb_seq_cpol0_cpha0_lsbfe1_h =
        apb_seq_cpol0_cpha0_lsbfe1::type_id::create("apb_seq_cpol0_cpha0_lsbfe1_h");
    apb_seq_cpol0_cpha1_lsbfe1_h =
        apb_seq_cpol0_cpha1_lsbfe1::type_id::create("apb_seq_cpol0_cpha1_lsbfe1_h");
    apb_seq_cpol1_cpha0_lsbfe1_h =
        apb_seq_cpol1_cpha0_lsbfe1::type_id::create("apb_seq_cpol1_cpha0_lsbfe1_h");
    apb_seq_cpol1_cpha1_lsbfe1_h =
        apb_seq_cpol1_cpha1_lsbfe1::type_id::create("apb_seq_cpol1_cpha1_lsbfe1_h");

    apb_seq_read_h = apb_seq_read::type_id::create("apb_seq_read_h");
  endtask
endclass


class virtual_seq0 extends virtual_seq;
  `uvm_object_utils(virtual_seq0)

  function new(string name = "virtual_seq0");
    super.new(name);
  endfunction
  task body();
    super.body();

    {lsbfe, cpol, cpha} = 3'd0;

    foreach (p_sequencer.apb_seqr_h[i]) begin
      fork
        apb_seq_cpol0_cpha0_lsbfe0_h.start(p_sequencer.apb_seqr_h[i]);

        spi_seq_h.start(p_sequencer.spi_seqr_h[i]);
      join

      apb_seq_read_h.start(p_sequencer.apb_seqr_h[i]);
    end
  endtask
endclass
class virtual_seq1 extends virtual_seq;
  `uvm_object_utils(virtual_seq1)

  function new(string name = "virtual_seq1");
    super.new(name);
  endfunction
  task body();

    super.body();

    foreach (p_sequencer.apb_seqr_h[i]) begin
      {lsbfe, cpol, cpha} = 3'd1;
      fork
        apb_seq_cpol0_cpha1_lsbfe0_h.start(p_sequencer.apb_seqr_h[i]);
        spi_seq_h.start(p_sequencer.spi_seqr_h[i]);
      join

      apb_seq_read_h.start(p_sequencer.apb_seqr_h[i]);
    end
  endtask
endclass
class virtual_seq2 extends virtual_seq;
  `uvm_object_utils(virtual_seq2)

  function new(string name = "virtual_seq2");
    super.new(name);
  endfunction
  task body();

    super.body();

    foreach (p_sequencer.apb_seqr_h[i]) begin
      {lsbfe, cpol, cpha} = 3'd2;
      fork
        apb_seq_cpol1_cpha0_lsbfe0_h.start(p_sequencer.apb_seqr_h[i]);
        spi_seq_h.start(p_sequencer.spi_seqr_h[i]);
      join

      apb_seq_read_h.start(p_sequencer.apb_seqr_h[i]);
    end
  endtask
endclass
class virtual_seq3 extends virtual_seq;
  `uvm_object_utils(virtual_seq3)

  function new(string name = "virtual_seq3");
    super.new(name);
  endfunction
  task body();

    super.body();

    foreach (p_sequencer.apb_seqr_h[i]) begin
      {lsbfe, cpol, cpha} = 3'd3;
      fork
        apb_seq_cpol1_cpha1_lsbfe0_h.start(p_sequencer.apb_seqr_h[i]);
        spi_seq_h.start(p_sequencer.spi_seqr_h[i]);
      join

      apb_seq_read_h.start(p_sequencer.apb_seqr_h[i]);
    end
  endtask
endclass
class virtual_seq4 extends virtual_seq;
  `uvm_object_utils(virtual_seq4)

  function new(string name = "virtual_seq4");
    super.new(name);
  endfunction
  task body();

    super.body();

    foreach (p_sequencer.apb_seqr_h[i]) begin
      {lsbfe, cpol, cpha} = 3'd4;
      fork
        apb_seq_cpol0_cpha0_lsbfe1_h.start(p_sequencer.apb_seqr_h[i]);
        spi_seq_h.start(p_sequencer.spi_seqr_h[i]);
      join

      apb_seq_read_h.start(p_sequencer.apb_seqr_h[i]);
    end
  endtask
endclass
class virtual_seq5 extends virtual_seq;
  `uvm_object_utils(virtual_seq5)

  function new(string name = "virtual_seq5");
    super.new(name);
  endfunction
  task body();

    super.body();

    foreach (p_sequencer.apb_seqr_h[i]) begin
      {lsbfe, cpol, cpha} = 3'd5;
      fork
        apb_seq_cpol0_cpha1_lsbfe1_h.start(p_sequencer.apb_seqr_h[i]);
        spi_seq_h.start(p_sequencer.spi_seqr_h[i]);
      join

      apb_seq_read_h.start(p_sequencer.apb_seqr_h[i]);
    end
  endtask
endclass
class virtual_seq6 extends virtual_seq;
  `uvm_object_utils(virtual_seq6)

  function new(string name = "virtual_seq6");
    super.new(name);
  endfunction
  task body();

    super.body();

    foreach (p_sequencer.apb_seqr_h[i]) begin
      {lsbfe, cpol, cpha} = 3'd6;
      fork
        apb_seq_cpol1_cpha0_lsbfe1_h.start(p_sequencer.apb_seqr_h[i]);
        spi_seq_h.start(p_sequencer.spi_seqr_h[i]);
      join

      apb_seq_read_h.start(p_sequencer.apb_seqr_h[i]);
    end
  endtask
endclass
class virtual_seq7 extends virtual_seq;
  `uvm_object_utils(virtual_seq7)

  function new(string name = "virtual_seq7");
    super.new(name);
  endfunction
  task body();

    super.body();

    foreach (p_sequencer.apb_seqr_h[i]) begin
      {lsbfe, cpol, cpha} = 3'd7;
      fork
        apb_seq_cpol1_cpha1_lsbfe1_h.start(p_sequencer.apb_seqr_h[i]);
        spi_seq_h.start(p_sequencer.spi_seqr_h[i]);
      join

      apb_seq_read_h.start(p_sequencer.apb_seqr_h[i]);
    end
  endtask
endclass

class spi_backdoor_seq extends uvm_sequence;
  `uvm_object_utils(spi_backdoor_seq)

  spi_reg_block spi_rm;

  task body();
    uvm_status_e   status;
    uvm_reg_data_t data;

    if (!uvm_config_db#(spi_reg_block)::get(null, get_full_name(), "spi_reg_block", spi_rm))
      `uvm_fatal("NO_REG", "Register model handle not found")


    spi_rm.cntrl_reg1.write(status, 8'h55, UVM_BACKDOOR);

    if (status != UVM_IS_OK) `uvm_error("BD_WRITE_FAIL", "Backdoor write failed. Check HDL paths.")

    spi_rm.cntrl_reg1.read(status, data, UVM_BACKDOOR);
    `uvm_info("BD_READ", $sformatf("Read value: %0h", data), UVM_LOW)
  endtask
endclass


class spi_reset_backdoor_seq extends uvm_sequence;
  `uvm_object_utils(spi_reset_backdoor_seq)

  spi_reg_block spi_rm;

  task body();
    uvm_status_e   status;
    uvm_reg_data_t data;

    // if(!uvm_config_db #(spi_reg_block)::get(null, get_full_name(), "spi_rm", spi_rm))
    //    `uvm_fatal("NO_REG", "Register model handle not found")

    spi_rm = spi_reg_block::type_id::create("spi_reg_block");

    spi_rm.cntrl_reg1.write(status, 8'h55, UVM_BACKDOOR);

    if (status != UVM_IS_OK) `uvm_error("BD_WRITE_FAIL", "Backdoor write failed. Check HDL paths.")

    spi_rm.cntrl_reg1.read(status, data, UVM_BACKDOOR);
    `uvm_info("BD_READ", $sformatf("Read value: %0h", data), UVM_LOW)

  endtask
endclass


class env extends uvm_env;
  `uvm_component_utils(env)
  function new(string name = "env", uvm_component parent);
    super.new(name, parent);
  endfunction
  env_cfg env_cfg_h;
  sbandref sbandref_h;
  apb_agt_top apb_agt_top_h;
  spi_agt_top spi_agt_top_h;
  virtual_seqr virtual_seqr_h;
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(env_cfg)::get(this, "", "env_cfg", env_cfg_h))
      `uvm_fatal(get_full_name, "The config fetch failed.")
    if (env_cfg_h.has_scoreboard) sbandref_h = sbandref::type_id::create("sb", this);
    if (env_cfg_h.has_virtual_sequencer)
      virtual_seqr_h = virtual_seqr::type_id::create("virtual_seqr_h", this);
    if (env_cfg_h.has_apb_agent)
      apb_agt_top_h = apb_agt_top::type_id::create("apb_agt_top_h", this);

    if (env_cfg_h.has_spi_agent)
      spi_agt_top_h = spi_agt_top::type_id::create("spi_agt_top_h", this);


  endfunction

  function void connect_phase(uvm_phase phase);
    if (env_cfg_h.has_scoreboard) begin
      foreach (apb_agt_top_h.apb_agent_h[i])
      apb_agt_top_h.apb_agent_h[i].apb_monitor_h.port_h.connect(
          sbandref_h.apb_fifo_h[i].analysis_export);
      foreach (spi_agt_top_h.spi_agent_h[i])
      spi_agt_top_h.spi_agent_h[i].spi_monitor_h.port_h.connect(
          sbandref_h.spi_fifo_h[i].analysis_export);
    end
    if (env_cfg_h.has_virtual_sequencer) begin

      foreach (virtual_seqr_h.apb_seqr_h[i])
      if (env_cfg_h.apb_agt_cfg_h[i].is_active)
        virtual_seqr_h.apb_seqr_h[i] = apb_agt_top_h.apb_agent_h[i].apb_seqr_h;
      foreach (virtual_seqr_h.spi_seqr_h[i])
      if (env_cfg_h.spi_agt_cfg_h[i].is_active)
        virtual_seqr_h.spi_seqr_h[i] = spi_agt_top_h.spi_agent_h[i].spi_seqr_h;
    end
  endfunction

endclass

// sonia@maven-silicon.com




class test extends uvm_test;
  `uvm_component_utils(test)
  function new(string name = "test", uvm_component parent);
    super.new(name, parent);
  endfunction
  env_cfg env_cfg_h;
  env env_h;
  spi_reg_block spi_rm;
  // virtual_seq virtual_seq_h;
  virtual_seq0 virtual_seq_h0;
  virtual_seq1 virtual_seq_h1;
  virtual_seq2 virtual_seq_h2;
  virtual_seq3 virtual_seq_h3;
  virtual_seq4 virtual_seq_h4;
  virtual_seq5 virtual_seq_h5;
  virtual_seq6 virtual_seq_h6;
  virtual_seq7 virtual_seq_h7;
  apb_seq_lpm apb_seq_lpm_h;
  function void build_phase(uvm_phase phase);
    // virtual_seq_h = virtual_seq::type_id::create("virtual_seq_h", this);
    env_cfg_h = env_cfg::type_id::create("env_cfg_h");
    env_cfg_h.has_functional_coverage = 1;
    env_cfg_h.has_virtual_sequencer = 1;
    env_cfg_h.has_scoreboard = 1;
    env_cfg_h.has_apb_agent = 1;
    env_cfg_h.has_spi_agent = 1;
    env_cfg_h.spi_agent_count = 1;
    env_cfg_h.apb_agent_count = 1;
    env_cfg_h.seq_count = 8;
    env_cfg_h.apb_agt_cfg_h = new[1];
    env_cfg_h.spi_agt_cfg_h = new[1];
    foreach (env_cfg_h.apb_agt_cfg_h[i]) begin
      env_cfg_h.apb_agt_cfg_h[i] = apb_agt_cfg::type_id::create($sformatf("apb_agt_cfg[%0d]", i));
      env_cfg_h.apb_agt_cfg_h[i].is_active = UVM_ACTIVE;
      if (!uvm_config_db#(virtual apb2core)::get(
              this, "", "apb2core", env_cfg_h.apb_agt_cfg_h[i].apb2core_h
          ))
        `uvm_fatal(get_full_name, "Config fetch failed.")
    end
    foreach (env_cfg_h.spi_agt_cfg_h[i]) begin

      env_cfg_h.spi_agt_cfg_h[i] = spi_agt_cfg::type_id::create($sformatf("spi_agt_cfg[%0d]", i));
      env_cfg_h.spi_agt_cfg_h[i].is_active = UVM_ACTIVE;
      if (!uvm_config_db#(virtual core2spi)::get(
              this, "", "core2spi", env_cfg_h.spi_agt_cfg_h[i].core2spi_h
          ))
        `uvm_fatal(get_full_name, "Config fetch failed.")
    end
    uvm_config_db#(env_cfg)::set(this, "*", "env_cfg", env_cfg_h);
    env_h  = env::type_id::create("env_h", this);

    spi_rm = spi_reg_block::type_id::create("spi_reg_block");

    spi_rm.build();
    uvm_config_db#(spi_reg_block)::set(null, "*", "spi_reg_block", spi_rm);
    virtual_seq_h0 = virtual_seq0::type_id::create("virtual_seq0");
    virtual_seq_h1 = virtual_seq1::type_id::create("virtual_seq1");
    virtual_seq_h2 = virtual_seq2::type_id::create("virtual_seq2");
    virtual_seq_h3 = virtual_seq3::type_id::create("virtual_seq3");
    virtual_seq_h4 = virtual_seq4::type_id::create("virtual_seq4");
    virtual_seq_h5 = virtual_seq5::type_id::create("virtual_seq5");
    virtual_seq_h6 = virtual_seq6::type_id::create("virtual_seq6");
    virtual_seq_h7 = virtual_seq7::type_id::create("virtual_seq7");
    apb_seq_lpm_h  = apb_seq_lpm::type_id::create("apb_seq_lpm_h");
  endfunction
  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction
  // task run_phase(uvm_phase phase);
  //   phase.raise_objection(this);
  //   virtual_seq_h.start(env_h.virtual_seqr_h);
  //   phase.drop_objection(this);
  // endtask
endclass

class test0 extends test;
  `uvm_component_utils(test0)

  function new(string name = "test0", uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    repeat (txn_count) virtual_seq_h0.start(env_h.virtual_seqr_h);
    phase.drop_objection(this);
  endtask

endclass
class test1 extends test;
  `uvm_component_utils(test1)

  function new(string name = "test1", uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    repeat (txn_count) virtual_seq_h1.start(env_h.virtual_seqr_h);
    phase.drop_objection(this);
  endtask

endclass

class test2 extends test;
  `uvm_component_utils(test2)

  function new(string name = "test2", uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    repeat (txn_count) virtual_seq_h2.start(env_h.virtual_seqr_h);
    phase.drop_objection(this);
  endtask

endclass

class test3 extends test;
  `uvm_component_utils(test3)

  function new(string name = "test3", uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    repeat (txn_count) virtual_seq_h3.start(env_h.virtual_seqr_h);
    phase.drop_objection(this);
  endtask

endclass

class test4 extends test;
  `uvm_component_utils(test4)

  function new(string name = "test4", uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    repeat (txn_count) virtual_seq_h4.start(env_h.virtual_seqr_h);
    phase.drop_objection(this);
  endtask

endclass

class test5 extends test;
  `uvm_component_utils(test5)

  function new(string name = "test5", uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    repeat (txn_count) virtual_seq_h5.start(env_h.virtual_seqr_h);
    phase.drop_objection(this);
  endtask

endclass

class test6 extends test;
  `uvm_component_utils(test6)

  function new(string name = "test6", uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    repeat (txn_count) virtual_seq_h6.start(env_h.virtual_seqr_h);
    phase.drop_objection(this);
  endtask

endclass

class test7 extends test;
  `uvm_component_utils(test7)

  function new(string name = "test7", uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    repeat (txn_count) virtual_seq_h7.start(env_h.virtual_seqr_h);
    phase.drop_objection(this);
  endtask

endclass



class test8 extends test;
  `uvm_component_utils(test8)

  function new(string name = "test8", uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    virtual_seq_h0.start(env_h.virtual_seqr_h);
    apb_seq_lpm_h.start(env_h.apb_agt_top_h.apb_agent_h[0].apb_seqr_h);
    phase.drop_objection(this);
  endtask

endclass

// module assertion(input clk,[1:0] mode);
// property modechange;
// @(posedge clk) 
// endproperty

// endmodule
module top;


  bit clk = 0;
  initial begin
    forever #10 clk = ~clk;
  end
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, top);
  end




  apb2core apb2core_h (clk);
  core2spi core2spi_h (clk);

  spi_core spi_core_h (
      .PCLK(apb2core_h.PCLK),
      .PRESETn(apb2core_h.PRESETn),
      .PADDR(apb2core_h.PADDR_i),
      .PWRITE(apb2core_h.PWRITE_i),
      .PSEL(apb2core_h.PSEL_i),
      .PENABLE(apb2core_h.PENABLE_i),
      .PWDATA(apb2core_h.PWDATA_i),
      .PRDATA(apb2core_h.PRDATA_o),
      .PREADY(apb2core_h.PREADY_o),
      .PSLVERR(apb2core_h.PSLVERR_o),
      .miso(core2spi_h.miso_i),
      .ss(core2spi_h.ss_o),
      .sclk(core2spi_h.sclk_o),
      .spi_interrupt_request(core2spi_h.spi_interrupt_request),
      .mosi(core2spi_h.mosi_o)
  );
  initial begin
    uvm_config_db#(virtual apb2core)::set(null, "*", "apb2core", apb2core_h);

    uvm_config_db#(virtual core2spi)::set(null, "*", "core2spi", core2spi_h);
    run_test();
  end

endmodule

