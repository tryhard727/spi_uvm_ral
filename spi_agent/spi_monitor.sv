`include "common/uvm_pkg_includes.svh"
`include "spi_agent/spi_txn.sv"
`include "spi_agent/spi_config.sv"

class spi_monitor extends uvm_monitor;
  `uvm_component_utils(spi_monitor)
  uvm_analysis_port #(spi_txn) port_h;
  spi_agt_cfg spi_agt_cfg_h;
  virtual core2spi core2spi_h;
  // bit cpha;
  // bit cpol;
  // bit lsbfe;

  bit [7:0] ctrl;
  function new(string name = "spi_monitor", uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(spi_agt_cfg)::get(this, "", "spi_agt_cfg", spi_agt_cfg_h))
      `uvm_fatal(get_full_name, "Config fetch failed")
    core2spi_h = spi_agt_cfg_h.core2spi_h;
    port_h = new("port_h", this);

  endfunction
  task run_phase(uvm_phase phase);
    forever begin
      // lsbfe = 1;
      // cpha  = 0;
      // cpol  = 0;
      sample ();
    end
  endtask
  task sample ();


    int bit_idx;
    spi_txn spi_txn_h;
    spi_txn_h = spi_txn::type_id::create("spi_txn_h");
    // 
    wait (!core2spi_h.mon_cb.ss_o);

    // Collect 8 bits
    for (int i = 0; i < 8; i++) begin

      bit_idx = lsbfe ? i : (7 - i);

      // Sampling edge
      if (cpha ^ cpol) @(negedge core2spi_h.mon_cb.sclk_o);
      else @(posedge core2spi_h.mon_cb.sclk_o);

      spi_txn_h.miso[bit_idx]     = core2spi_h.mon_cb.miso_i;
      spi_txn_h.mosi[bit_idx]     = core2spi_h.mon_cb.mosi_o;
      spi_txn_h.ss                = core2spi_h.mon_cb.ss_o;
      spi_txn_h.spi_interrupt_req = core2spi_h.mon_cb.spi_interrupt_request;

    end

    // `uvm_info(get_type_name(), $sformatf("Transaction received from SPI slave:\n%s",
    // spi_txn_h.sprint()), UVM_LOW)

    port_h.write(spi_txn_h);

    @(core2spi_h.mon_cb);
  endtask
endclass
