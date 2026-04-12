`include "common/uvm_pkg_includes.svh"
`include "spi_agent/spi_txn.sv"

class spi_seq extends uvm_sequence #(spi_txn);
  `uvm_object_utils(spi_seq)
  function new(string name = "spi_seq");
    super.new(name);
  endfunction
  task body();
    req = spi_txn::type_id::create("req");
    repeat (1) begin
      start_item(req);
      assert (req.randomize);
      finish_item(req);
    end
  endtask
endclass
