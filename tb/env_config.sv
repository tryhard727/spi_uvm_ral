`include "common/uvm_pkg_includes.svh"
`include "apb_agent/apb_config.sv"
`include "spi_agent/spi_config.sv"

class env_cfg extends uvm_object;
  `uvm_object_utils(env_cfg)
  function new(string name = "env_cfg");
    super.new(name);
  endfunction
  bit has_functional_coverage;
  bit has_virtual_sequencer;
  bit has_scoreboard;
  bit has_apb_agent;
  bit has_spi_agent;
  int spi_agent_count;
  int apb_agent_count;
  int seq_count;

  apb_agt_cfg apb_agt_cfg_h[];
  spi_agt_cfg spi_agt_cfg_h[];
endclass
