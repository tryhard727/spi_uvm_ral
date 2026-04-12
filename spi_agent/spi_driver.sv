`include "common/uvm_pkg_includes.svh"
`include "spi_agent/spi_txn.sv"
`include "spi_agent/spi_config.sv"

class spi_driver extends uvm_driver #(spi_txn);
  `uvm_component_utils(spi_driver)
  function new(string name = "spi_driver", uvm_component parent);
    super.new(name, parent);
  endfunction
  bit cpha;
  bit cpol;
  bit lsbfe;
  bit [7:0] ctrl;
  spi_agt_cfg spi_agt_cfg_h;
  virtual core2spi core2spi_h;
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(spi_agt_cfg)::get(this, "", "spi_agt_cfg", spi_agt_cfg_h))
      `uvm_fatal(get_full_name, "Config fetch failed")
    core2spi_h = spi_agt_cfg_h.core2spi_h;
    // lsbfe = 1;
    // cpha = 0;
    // cpol = 0;
  endfunction
  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      send_to_dut(req);
      seq_item_port.item_done();
    end
  endtask
  task send_to_dut(spi_txn spi_txn_h);

    // Wait for slave select
    wait (!core2spi_h.drv_cb.ss_o);

    // CPHA = 0 → drive first bit immediately
    if (!cpha) core2spi_h.drv_cb.miso_i <= spi_txn_h.miso[lsbfe?0 : 7];

    // Drive 8 bits
    for (int i = (cpha ? 0 : 1); i < 8; i++) begin

      if (cpha ^ cpol) @(posedge core2spi_h.drv_cb.sclk_o);
      else @(negedge core2spi_h.drv_cb.sclk_o);

      core2spi_h.drv_cb.miso_i <= spi_txn_h.miso[lsbfe?i : (7-i)];
    end


    wait (core2spi_h.drv_cb.ss_o);

  endtask
endclass
