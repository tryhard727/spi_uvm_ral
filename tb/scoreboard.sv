`include "common/uvm_pkg_includes.svh"
`include "tb/env_config.sv"
`include "apb_agent/apb_txn.sv"
`include "spi_agent/spi_txn.sv"
`include "ral/spi_reg_block.sv"

class sbandref extends uvm_scoreboard;
  `uvm_component_utils(sbandref)
  uvm_tlm_analysis_fifo #(spi_txn) spi_fifo_h[];
  uvm_tlm_analysis_fifo #(apb_txn) apb_fifo_h[];
  env_cfg env_cfg_h;
  apb_txn apb_txn_h;
  spi_txn spi_txn_h;

  spi_reg_block spi_rm;
  uvm_reg_data_t data;
  uvm_status_e status;

  apb_txn apb_txn_cg_h;
  spi_txn spi_txn_cg_h;
  function void build_phase(uvm_phase phase);

    if (!uvm_config_db#(spi_reg_block)::get(this, "", "spi_reg_block", spi_rm))
      `uvm_fatal("NO_REG", "Register model handle not found")
    if (!uvm_config_db#(env_cfg)::get(this, "", "env_cfg", env_cfg_h))
      `uvm_fatal(get_type_name, "Config fetch failed")
    spi_fifo_h = new[env_cfg_h.spi_agent_count];
    apb_fifo_h = new[env_cfg_h.apb_agent_count];
    foreach (spi_fifo_h[i]) spi_fifo_h[i] = new($sformatf("spi_fifo_h[%0d]", i), this);
    foreach (apb_fifo_h[i]) apb_fifo_h[i] = new($sformatf("apb_fifo_h[%0d]", i), this);

    if (env_cfg_h.has_functional_coverage) begin
      apb_txn_cg_h = apb_txn::type_id::create("apb_txn_cg_h");
      spi_txn_cg_h = spi_txn::type_id::create("spi_txn_cg_h");
    end
  endfunction

  covergroup apb_txn_cg;
    option.per_instance = 1;
    PRESETn_cp: coverpoint apb_txn_cg_h.PRESETn {bins PRESETn = {0, 1};}
    PADDR_cp: coverpoint apb_txn_cg_h.PADDR {bins PADDR[] = {0, 1, 2, 5};}
    PSEL_cp: coverpoint apb_txn_cg_h.PSEL {bins PSEL = {0, 1};}
    PENABLE_cp: coverpoint apb_txn_cg_h.PENABLE {bins PENABLE = {0, 1};}
    PWRITE_cp: coverpoint apb_txn_cg_h.PWRITE {bins PWRITE[] = {0, 1};}
    PREADY_cp: coverpoint apb_txn_cg_h.PREADY {bins PREADY = {0, 1};}
    PSLVERR_cp: coverpoint apb_txn_cg_h.PSLVERR {bins PSLVERR = {0, 1};}
    PWDATA_cp: coverpoint apb_txn_cg_h.PWDATA {
      bins PWDATA_LOW = {[8'h00 : 8'h0f]}; bins PWDATA_HIGH = {[8'h1f : 8'hff]};
    }
    cross PSEL_cp, PENABLE_cp;
    cross PSEL_cp, PENABLE_cp, PREADY_cp;
  endgroup

  covergroup spi_txn_cg;
    option.per_instance = 1;
    SS_cp: coverpoint spi_txn_cg_h.ss {bins ss = {0, 1};}
    SPI_INT_REQ_cp: coverpoint spi_txn_cg_h.spi_interrupt_req {bins spi_interrupt_req = {0, 1};}
    MISO_cp: coverpoint spi_txn_cg_h.miso {
      bins miso_LOW = {[8'h00 : 8'h0f]}; bins miso_HIGH = {[8'h1f : 8'hff]};
    }
    MOSI_cp: coverpoint spi_txn_cg_h.mosi {
      bins mosi_LOW = {[8'h00 : 8'h0f]}; bins mosi_HIGH = {[8'h1f : 8'hff]};
    }
  endgroup

  function new(string name = "sbandref", uvm_component parent);
    super.new(name, parent);


    apb_txn_cg = new;

    spi_txn_cg = new;
  endfunction
  task run_phase(uvm_phase phase);
    foreach (apb_fifo_h[i]) begin

      fork
        begin
          forever begin
            apb_fifo_h[i].get(apb_txn_h);

            apb_txn_cg_h = apb_txn_h;
            apb_txn_cg.sample();
            if (apb_txn_h.PADDR == 'd5) compare_data(apb_txn_h);
          end

        end
        forever begin
          spi_fifo_h[i].get(spi_txn_h);

          spi_txn_cg_h = spi_txn_h;
          spi_txn_cg.sample();
        end
      join
    end
  endtask


  task compare_data(apb_txn apb_txn_h);
    wait (apb_txn_h != null);
    wait (spi_txn_h != null);

    if (apb_txn_h.PWRITE && (apb_txn_h.PADDR == 3'b101)) begin
      $display(
          "*******************************************SCOREBOARD***********************************************************");
      if (apb_txn_h.PWDATA == spi_txn_h.mosi) begin
        `uvm_info(get_type_name(), "data compare successfull", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("apb_txn_h= \n%s,\nspi_txn_h= \n%s",
                                             apb_txn_h.sprint(), spi_txn_h.sprint()), UVM_LOW)
      end else begin
        `uvm_error(get_type_name(), "data not match")

        `uvm_info(get_type_name(), $sformatf(
                  "apb_txn_h= \n%s,\nspi_txn_h= \n%s", apb_txn_h.sprint(), spi_txn_h.sprint()),
                  UVM_LOW)
      end

      $display(
          "*******************************************SCOREBOARD***********************************************************");
    end else if (!apb_txn_h.PWRITE && (apb_txn_h.PADDR == 3'b101)) begin

      spi_rm.data_reg.read(status, data, UVM_BACKDOOR);
      $display(
          "*******************************************SCOREBOARD***********************************************************");
      if (data == spi_txn_h.miso) begin
        `uvm_info(get_type_name(), "data compare successfull", UVM_LOW)

        `uvm_info(get_type_name(), $sformatf("apb_txn_h= \n%s,\n apb_txn_h= \n%s",
                                             apb_txn_h.sprint(), spi_txn_h.sprint()), UVM_LOW)

      end else begin
        `uvm_error(get_type_name(), "data not match")
        `uvm_info(get_type_name(), $sformatf(
                  "scoreboard :\n apb_txn_h= \n%s,\n apb_txn_h= \n%s",
                  apb_txn_h.sprint(),
                  spi_txn_h.sprint()
                  ), UVM_LOW)
      end
      $display(
          "*******************************************SCOREBOARD***********************************************************");
    end
    if (apb_txn_h.PWRITE == 0) spi_txn_h = null;
    apb_txn_h = null;
  endtask
endclass
