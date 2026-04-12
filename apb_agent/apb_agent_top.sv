`include "common/uvm_pkg_includes.svh"
`include "apb_agent/apb_agent.sv"
`include "apb_agent/apb_config.sv"
`include "tb/env_config.sv" // Assuming env_cfg is in tb/env_config.sv

class apb_agt_top extends uvm_env;
  `uvm_component_utils(apb_agt_top)
  function new(string name = "apb_agt_top", uvm_component parent);
    super.new(name, parent);
  endfunction
  apb_agent apb_agent_h[];
  apb_agt_cfg apb_agt_cfg_h[];
  env_cfg env_cfg_h;
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(env_cfg)::get(this, "", "env_cfg", env_cfg_h))
      `uvm_fatal(get_full_name, "Config fetch failed")
    apb_agt_cfg_h = env_cfg_h.apb_agt_cfg_h;
    foreach (apb_agt_cfg_h[i])
    uvm_config_db#(apb_agt_cfg)::set(this, $sformatf("apb_agent_h[%0d]*", i), "apb_agt_cfg",
                                     apb_agt_cfg_h[i]);
    apb_agent_h = new[env_cfg_h.apb_agent_count];
    foreach (apb_agent_h[i])
    apb_agent_h[i] = apb_agent::type_id::create($sformatf("apb_agent_h[%0d]", i), this);
  endfunction
endclass
