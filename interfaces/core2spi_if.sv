interface core2spi (
    input bit clock
);
  logic sclk_o;
  logic ss_o;
  logic miso_i;
  logic mosi_o;
  logic spi_interrupt_request;
  clocking drv_cb @(posedge clock);
    default input #1 output #0;
    input sclk_o;
    input ss_o;
    output miso_i;
    input mosi_o;
    input spi_interrupt_request;
  endclocking

  clocking mon_cb @(posedge clock);
    default input #1 output #0;
    input sclk_o;
    input ss_o;
    input miso_i;
    input mosi_o;
    input spi_interrupt_request;
  endclocking

  modport drv_mp(clocking drv_cb);

  modport mon_mp(clocking mon_cb);

endinterface
