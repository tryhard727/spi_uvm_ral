`include "common/uvm_pkg_includes.svh"

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
