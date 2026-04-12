package test_pkg;

  `include "common/uvm_pkg_includes.svh"
  `include "common/defines.svh"

  // Interfaces
  `include "interfaces/apb2core_if.sv"
  `include "interfaces/core2spi_if.sv"

  // RAL
  `include "ral/spi_cr1_reg.sv"
  `include "ral/spi_cr2_reg.sv"
  `include "ral/spi_br_reg.sv"
  `include "ral/spi_sr_reg.sv"
  `include "ral/spi_dr_reg.sv"
  `include "ral/spi_reg_block.sv"

  // APB Agent
  `include "apb_agent/apb_config.sv"
  `include "apb_agent/apb_txn.sv"
  `include "apb_agent/apb_seq.sv"
  `include "apb_agent/apb_driver.sv"
  `include "apb_agent/apb_monitor.sv"
  `include "apb_agent/apb_seqr.sv"
  `include "apb_agent/apb_agent.sv"
  `include "apb_agent/apb_agent_top.sv"

  // SPI Agent
  `include "spi_agent/spi_config.sv"
  `include "spi_agent/spi_txn.sv"
  `include "spi_agent/spi_seq.sv"
  `include "spi_agent/spi_driver.sv"
  `include "spi_agent/spi_monitor.sv"
  `include "spi_agent/spi_seqr.sv"
  `include "spi_agent/spi_agent.sv"
  `include "spi_agent/spi_agent_top.sv"

  // TB Components
  `include "tb/env_config.sv"
  `include "tb/scoreboard.sv"
  `include "tb/virtual_sequencer.sv"
  `include "tb/virtual_sequence.sv"
  `include "tb/env.sv"

  // Tests
  `include "test/base_test.sv"

endpackage
