`include "common/uvm_pkg_includes.svh"
`include "spi_agent/spi_txn.sv"

class spi_seqr extends uvm_sequencer #(spi_txn);
  `uvm_component_utils(spi_seqr)
  function new(string name = "spi_seqr", uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
