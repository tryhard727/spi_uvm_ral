`include "common/uvm_pkg_includes.svh"
`include "apb_agent/apb_txn.sv"

class apb_seq extends uvm_sequence #(apb_txn);
  `uvm_object_utils(apb_seq)

  function new(string name = "apb_seq");
    super.new(name);
  endfunction

  virtual task body();
    req = apb_txn::type_id::create("req");
    repeat (1) begin
      start_item(req);
      assert(req.randomize());
      finish_item(req);
    end
  endtask

endclass
