`include "common/uvm_pkg_includes.svh"
`include "ral/spi_cr1_reg.sv"
`include "ral/spi_cr2_reg.sv"
`include "ral/spi_br_reg.sv"
`include "ral/spi_sr_reg.sv"
`include "ral/spi_dr_reg.sv"

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
