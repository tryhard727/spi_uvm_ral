`include "common/uvm_pkg_includes.svh"
`include "interfaces/core2spi_if.sv"

class spi_agt_cfg extends uvm_object;
  `uvm_object_utils(spi_agt_cfg)
  function new(string name = "spi_agt_cfg");
    super.new(name);
  endfunction
  uvm_active_passive_enum is_active;
  virtual core2spi core2spi_h;
  bit [7:0] ctrl;
endclass
