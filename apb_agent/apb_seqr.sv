`include "common/uvm_pkg_includes.svh"
`include "apb_agent/apb_txn.sv"

class apb_seqr extends uvm_sequencer #(apb_txn);
  `uvm_object_utils(apb_seqr)
  function new(string name = "apb_seqr", uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
