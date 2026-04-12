`include "common/uvm_pkg_includes.svh"
`include "apb_agent/apb_seq.sv"
`include "spi_agent/spi_seq.sv"

class virtual_sequence extends uvm_sequence;
  `uvm_object_utils(virtual_sequence)

  apb_seq apb_seq_h;
  spi_seq spi_seq_h;

  function new(string name = "virtual_sequence");
    super.new(name);
  endfunction

  virtual task body();
    apb_seq_h = apb_seq::type_id::create("apb_seq_h");
    spi_seq_h = spi_seq::type_id::create("spi_seq_h");

    fork
      apb_seq_h.start(p_sequencer.apb_seqr_h[0]); // Assuming one APB agent
      spi_seq_h.start(p_sequencer.spi_seqr_h[0]); // Assuming one SPI agent
    join
  endtask

endclass
