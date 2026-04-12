`include "common/uvm_pkg_includes.svh"
`include "tb/env_config.sv"
`include "apb_agent/apb_seqr.sv"
`include "spi_agent/spi_seqr.sv"

class virtual_seqr extends uvm_sequencer;
  `uvm_component_utils(virtual_seqr)
  function new(string name = "virtual_seqr", uvm_component parent);
    super.new(name, parent);
  endfunction
  env_cfg  env_cfg_h;
  apb_seqr apb_seqr_h[];
  spi_seqr spi_seqr_h[];
  function void build_phase(uvm_phase phase);

    if (!uvm_config_db#(env_cfg)::get(this, "", "env_cfg", env_cfg_h))
      `uvm_fatal(get_type_name, "Config fetch failed")
    apb_seqr_h = new[env_cfg_h.apb_agent_count];
    spi_seqr_h = new[env_cfg_h.spi_agent_count];
    foreach (apb_seqr_h[i])
    apb_seqr_h[i] = apb_seqr::type_id::create($sformatf("apb_seqr_h[%0d]", i), this);
    foreach (spi_seqr_h[i])
    spi_seqr_h[i] = spi_seqr::type_id::create($sformatf("spi_seqr_h[%0d]", i), this);
  endfunction
endclass
