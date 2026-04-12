`include "common/uvm_pkg_includes.svh"
`include "common/defines.svh"
`include "interfaces/apb2core_if.sv"
`include "interfaces/core2spi_if.sv"
`include "rtl/spi_core_top.sv"
`include "tb/env.sv"
`include "tb/env_config.sv"
`include "test/test_pkg.sv" // Include the package for UVM components

module top_tb;

  bit CLK;
  bit PRESETn;

  // Clock generation
  always #5 CLK = ~CLK;

  // Reset generation
  initial begin
    PRESETn = 1'b0;
    #100;
    PRESETn = 1'b1;
  end

  // Interfaces
  apb2core apb_if(.CLK(CLK));
  core2spi spi_if(.clock(CLK));

  // DUT
  spi_core_top spi_core_h (
      .PCLK(apb_if.PCLK),
      .PRESETn(apb_if.PRESETn),
      .PADDR(apb_if.PADDR_i),
      .PWRITE(apb_if.PWRITE_i),
      .PSEL(apb_if.PSEL_i),
      .PENABLE(apb_if.PENABLE_i),
      .PWDATA(apb_if.PWDATA_i),
      .PRDATA(apb_if.PRDATA_o),
      .PREADY(apb_if.PREADY_o),
      .PSLVERR(apb_if.PSLVERR_o),
      .miso(spi_if.miso_i),
      .ss(spi_if.ss_o),
      .sclk(spi_if.sclk_o),
      .spi_interrupt_request(spi_if.spi_interrupt_request),
      .mosi(spi_if.mosi_o)
  );

  // UVM Environment
  // The UVM environment is built and run through the uvm_pkg and test_pkg
  // The actual instantiation of the env and running of the test is done in the initial block.

  initial begin
    // Set up configuration for the environment
    test_pkg::env_cfg env_cfg_h;
    env_cfg_h = test_pkg::env_cfg::type_id::create("env_cfg_h");
    env_cfg_h.has_functional_coverage = 1;
    env_cfg_h.has_virtual_sequencer = 1;
    env_cfg_h.has_scoreboard = 1;
    env_cfg_h.has_apb_agent = 1;
    env_cfg_h.has_spi_agent = 1;
    env_cfg_h.spi_agent_count = 1;
    env_cfg_h.apb_agent_count = 1;
    env_cfg_h.seq_count = 1;

    env_cfg_h.apb_agt_cfg_h = new[1];
    env_cfg_h.apb_agt_cfg_h[0] = test_pkg::apb_agt_cfg::type_id::create("apb_agt_cfg_h[0]");
    env_cfg_h.apb_agt_cfg_h[0].is_active = UVM_ACTIVE;
    env_cfg_h.apb_agt_cfg_h[0].apb2core_h = apb_if;

    env_cfg_h.spi_agt_cfg_h = new[1];
    env_cfg_h.spi_agt_cfg_h[0] = test_pkg::spi_agt_cfg::type_id::create("spi_agt_cfg_h[0]");
    env_cfg_h.spi_agt_cfg_h[0].is_active = UVM_ACTIVE;
    env_cfg_h.spi_agt_cfg_h[0].core2spi_h = spi_if;

    uvm_config_db#(test_pkg::env_cfg)::set(null, "*", "env_cfg", env_cfg_h);
    uvm_config_db#(virtual apb2core)::set(null, "*apb_driver*", "apb2core", apb_if);
    uvm_config_db#(virtual core2spi)::set(null, "*spi_driver*", "core2spi", spi_if);

    run_test("base_test");
  end

endmodule
