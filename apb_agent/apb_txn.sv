`include "common/uvm_pkg_includes.svh"

class apb_txn extends uvm_sequence_item;
  `uvm_object_utils(apb_txn)
  function new(string name = "apb_txn");
    super.new(name);
  endfunction
  rand bit PRESETn;
  rand bit PWRITE;
  bit PSEL;
  bit PENABLE;
  rand bit [2:0] PADDR;
  rand bit [7:0] PWDATA;
  bit [7:0] PRDATA;
  bit PREADY;
  bit PSLVERR;
  constraint valid_addr {
    if (!PWRITE)
    PADDR inside {[0 : 3], 5};
    else
    PADDR inside {[0 : 2], 5};
  }
  constraint valid_rst {
    PRESETn dist {
      0 := 1,
      1 := 99
    };
  }
  // function void post_randomize();
  //   bit [7:0] CR1_MASK = 8'hFF;
  //   bit [7:0] CR2_MASK = 8'h1B;
  //   bit [7:0] BDR_MASK = 8'h77;
  //   bit [7:0] STATUS_MASK = 8'h00;
  //   bit [7:0] DATA_MASK = 8'hFF;
  //   if (PWRITE) begin
  //     case (PADDR)
  //       'b000:   PWDATA = CR1_MASK & PWDATA;
  //       'b001:   PWDATA = CR2_MASK & PWDATA;
  //       'b010:   PWDATA = BDR_MASK & PWDATA;
  //       // 'b011: PWDATA = STATUS_MASK & PWDATA;
  //       'b101:   PWDATA = DATA_MASK & PWDATA;
  //       default: PWDATA = DATA_MASK & PWDATA;
  //     endcase
  //   end
  // endfunction

  function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field("PRESETn", this.PRESETn, 1, UVM_BIN);
    printer.print_field("PWRITE", this.PWRITE, 1, UVM_BIN);
    printer.print_field("PSEL", this.PSEL, 1, UVM_BIN);
    printer.print_field("PENABLE", this.PENABLE, 1, UVM_BIN);
    printer.print_field("PADDR", this.PADDR, 3, UVM_DEC);
    // printer.print_field("PWDATA", this.PWDATA, 8, UVM_DEC);
    // printer.print_field("PRDATA", this.PRDATA, 8, UVM_DEC);
    printer.print_field("PWDATA", this.PWDATA, 8, UVM_BIN);
    printer.print_field("PRDATA", this.PRDATA, 8, UVM_BIN);
    printer.print_field("PREADY", this.PREADY, 1, UVM_BIN);
    printer.print_field("PSLVERR", this.PSLVERR, 1, UVM_BIN);
  endfunction

endclass
