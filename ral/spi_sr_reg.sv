`include "common/uvm_pkg_includes.svh"

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
