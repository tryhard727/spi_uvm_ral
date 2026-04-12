`include "common/uvm_pkg_includes.svh"
`include "tb/env_config.sv"
`include "apb_agent/apb_agent_top.sv"
`include "spi_agent/spi_agent_top.sv"
`include "tb/scoreboard.sv"
`include "tb/virtual_sequencer.sv"
`include "ral/spi_reg_block.sv"

class spi_env extends uvm_env;
  `uvm_component_utils(spi_env)

  env_cfg env_cfg_h;
  apb_agt_top apb_env_h;
  spi_agt_top spi_env_h;
  sbandref sb_h;
  virtual_seqr v_seqr_h;
  spi_reg_block spi_rm;

  function new(string name = "spi_env", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(env_cfg)::get(this, "", "env_cfg", env_cfg_h))
      `uvm_fatal(get_full_name(), "env_cfg not found")

    apb_env_h = apb_agt_top::type_id::create("apb_env_h", this);
    spi_env_h = spi_agt_top::type_id::create("spi_env_h", this);
    sb_h = sbandref::type_id::create("sb_h", this);
    v_seqr_h = virtual_seqr::type_id::create("v_seqr_h", this);
    spi_rm = spi_reg_block::type_id::create("spi_rm", this);
    spi_rm.build();
    uvm_config_db#(spi_reg_block)::set(this, "*", "spi_reg_block", spi_rm);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Connect APB monitor to scoreboard
    foreach (apb_env_h.apb_agent_h[i]) begin
      apb_env_h.apb_agent_h[i].apb_monitor_h.port_h.connect(sb_h.apb_fifo_h[i]);
    end
    // Connect SPI monitor to scoreboard
    foreach (spi_env_h.spi_agent_h[i]) begin
      spi_env_h.spi_agent_h[i].spi_monitor_h.port_h.connect(sb_h.spi_fifo_h[i]);
    end
  endfunction

endclass
