`include "common/uvm_pkg_includes.svh"

class spi_txn extends uvm_sequence_item;
  `uvm_object_utils(spi_txn)
  function new(string name = "spi_txn");
    super.new(name);
  endfunction
  bit ss;
  bit sclk;
  rand bit [7:0] miso;
  bit [7:0] mosi;
  bit spi_interrupt_req;
  constraint miso_dist {
    miso dist {
      [8'h00 : 8'h0f] := 50,
      [8'h1f : 8'hff] := 50
    };
  }
  function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field("SS", this.ss, 1, UVM_BIN);
    // printer.print_field("MOSI", this.mosi, 8, UVM_DEC);
    // printer.print_field("MISO", this.miso, 8, UVM_DEC);
    printer.print_field("MOSI", this.mosi, 8, UVM_BIN);
    printer.print_field("MISO", this.miso, 8, UVM_BIN);
    printer.print_field("spi_interrupt_req", this.spi_interrupt_req, 1, UVM_BIN);
  endfunction
endclass
