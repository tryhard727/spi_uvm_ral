`include "common/uvm_pkg_includes.svh"

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
