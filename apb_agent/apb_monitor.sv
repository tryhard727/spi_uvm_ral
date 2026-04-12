`include "common/uvm_pkg_includes.svh"
`include "apb_agent/apb_txn.sv"
`include "apb_agent/apb_config.sv"

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
