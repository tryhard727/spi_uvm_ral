`include "common/uvm_pkg_includes.svh"
`include "apb_agent/apb_config.sv"
`include "apb_agent/apb_driver.sv"
`include "apb_agent/apb_monitor.sv"
`include "apb_agent/apb_seqr.sv"

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
