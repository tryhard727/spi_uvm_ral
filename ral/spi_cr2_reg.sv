`include "common/uvm_pkg_includes.svh"

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
