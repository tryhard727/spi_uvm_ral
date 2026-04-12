`include "common/uvm_pkg_includes.svh"
`include "spi_agent/spi_config.sv"
`include "spi_agent/spi_driver.sv"
`include "spi_agent/spi_monitor.sv"
`include "spi_agent/spi_seqr.sv"

class spi_agent extends uvm_agent;
  `uvm_component_utils(spi_agent)
  function new(string name = "spi_agent", uvm_component parent);
    super.new(name, parent);
  endfunction
  spi_agt_cfg spi_agt_cfg_h;
  spi_driver spi_driver_h;
  spi_seqr spi_seqr_h;
  spi_monitor spi_monitor_h;
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(spi_agt_cfg)::get(this, "", "spi_agt_cfg", spi_agt_cfg_h))
      `uvm_fatal(get_full_name, "Config fetch failed")
    if (spi_agt_cfg_h.is_active) begin

      spi_driver_h = spi_driver::type_id::create("spi_driver_h", this);
      spi_seqr_h   = spi_seqr::type_id::create("spi_seqr_h", this);
    end

    spi_monitor_h = spi_monitor::type_id::create("spi_monitor_h", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    if (spi_agt_cfg_h.is_active == UVM_ACTIVE)
      spi_driver_h.seq_item_port.connect(spi_seqr_h.seq_item_export);
  endfunction
endclass
