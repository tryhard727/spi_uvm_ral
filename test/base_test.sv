`include "common/uvm_pkg_includes.svh"
`include "tb/env.sv"
`include "tb/virtual_sequence.sv" // NEW

class base_test extends uvm_test;
  `uvm_component_utils(base_test)

  spi_env env_h;
  virtual_sequence v_seq_h; // NEW

  function new(string name = "base_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env_h = spi_env::type_id::create("env_h", this);
    v_seq_h = virtual_sequence::type_id::create("v_seq_h"); // NEW
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    v_seq_h.start(env_h.v_seqr_h); // Start the virtual sequence on the virtual sequencer
    #1000; // Run for some time
    phase.drop_objection(this);
  endtask

endclass
