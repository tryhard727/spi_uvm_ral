`include "common/uvm_pkg_includes.svh"

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
