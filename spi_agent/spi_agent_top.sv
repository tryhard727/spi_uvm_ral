`include "common/uvm_pkg_includes.svh"
`include "spi_agent/spi_agent.sv"
`include "spi_agent/spi_config.sv"
`include "tb/env_config.sv" // Assuming env_cfg is in tb/env_config.sv

class spi_agt_top extends uvm_env;
  `uvm_component_utils(spi_agt_top)
  function new(string name = "spi_agt_top", uvm_component parent);
    super.new(name, parent);
  endfunction
  spi_agent spi_agent_h[];
  spi_agt_cfg spi_agt_cfg_h[];
  env_cfg env_cfg_h;
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(env_cfg)::get(this, "", "env_cfg", env_cfg_h))
      `uvm_fatal(get_full_name, "Config fetch failed")
    spi_agt_cfg_h = env_cfg_h.spi_agt_cfg_h;
    foreach (spi_agt_cfg_h[i])
    uvm_config_db#(spi_agt_cfg)::set(this, $sformatf("spi_agent_h[%0d]*", i), "spi_agt_cfg",
                                     spi_agt_cfg_h[i]);
    spi_agent_h = new[env_cfg_h.spi_agent_count];
    foreach (spi_agent_h[i])
    spi_agent_h[i] = spi_agent::type_id::create($sformatf("spi_agent_h[%0d]", i), this);
  endfunction
endclass
