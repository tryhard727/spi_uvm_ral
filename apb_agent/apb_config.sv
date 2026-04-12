`include "common/uvm_pkg_includes.svh"
`include "interfaces/apb2core_if.sv"

class apb_agt_cfg extends uvm_object;
  `uvm_object_utils(apb_agt_cfg)
  function new(string name = "apb_agt_cfg");
    super.new(name);
  endfunction
  uvm_active_passive_enum is_active;
  virtual apb2core apb2core_h;
endclass
