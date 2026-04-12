`include "common/uvm_pkg_includes.svh"
`include "apb_agent/apb_txn.sv"
`include "apb_agent/apb_config.sv"

class apb_driver extends uvm_driver #(apb_txn);
  `uvm_component_utils(apb_driver)
  function new(string name = "apb_driver", uvm_component parent);
    super.new(name, parent);
  endfunction
  apb_agt_cfg apb_agt_cfg_h;
  virtual apb2core apb2core_h;
  function void connect_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual apb2core)::get(this, "", "apb2core", apb2core_h))
      `uvm_fatal(get_full_name, "Config fetch failed")
    //    apb2core_h = apb_agt_cfg_h.apb2core_h;
  endfunction
  task run_phase(uvm_phase phase);


    apb2core_h.drv_cb.PRESETn <= 1'b0;
    repeat (2) @(apb2core_h.drv_cb);

    apb2core_h.drv_cb.PRESETn <= 1'b1;
    forever begin
      seq_item_port.get_next_item(req);
      send_to_dut(req);
      seq_item_port.item_done();
    end
  endtask
  task send_to_dut(apb_txn req);
    // `uvm_info(get_type_name, $sformatf("%s %p", req.sprint(), apb2core_h), UVM_MEDIUM)

    @(apb2core_h.drv_cb);
    apb2core_h.drv_cb.PADDR_i <= req.PADDR;
    // apb2core_h.drv_cb.PRESETn <= 1'b1;
    apb2core_h.drv_cb.PWRITE_i <= req.PWRITE;
    apb2core_h.drv_cb.PSEL_i <= 1'b1;
    apb2core_h.drv_cb.PENABLE_i <= 1'b0;
    if (req.PWRITE) apb2core_h.drv_cb.PWDATA_i <= req.PWDATA;
    @(apb2core_h.drv_cb);
    apb2core_h.drv_cb.PENABLE_i <= 1'b1;

    // `uvm_info(get_type_name, $sformatf("before wait"), UVM_MEDIUM)
    wait (apb2core_h.drv_cb.PREADY_o)
      if (req.PWRITE == 1'b0) req.PRDATA = apb2core_h.drv_cb.PRDATA_o;

    // `uvm_info(get_type_name, $sformatf("after wait"), UVM_MEDIUM)
    apb2core_h.drv_cb.PSEL_i <= 1'b0;
    apb2core_h.drv_cb.PENABLE_i <= 1'b0;
  endtask
endclass
