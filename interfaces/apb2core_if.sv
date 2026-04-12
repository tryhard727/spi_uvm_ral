interface apb2core (
    input bit CLK
);
  logic PCLK;
  logic PRESETn;
  logic PSEL_i;
  logic PWRITE_i;
  logic PENABLE_i;
  logic [2:0] PADDR_i;
  logic [7:0] PWDATA_i;
  logic [7:0] PRDATA_o;
  logic PREADY_o;
  logic PSLVERR_o;
  assign PCLK = CLK;

  clocking drv_cb @(posedge CLK);
    default input #1 output #0;
    output PCLK;
    output PRESETn;
    output PSEL_i;
    output PWRITE_i;
    output PENABLE_i;
    output PADDR_i;
    output PWDATA_i;
    input PRDATA_o;
    input PREADY_o;
    input PSLVERR_o;
  endclocking

  clocking mon_cb @(posedge CLK);
    default input #1 output #0;
    input PCLK;
    input PRESETn;
    input PSEL_i;
    input PWRITE_i;
    input PENABLE_i;
    input PADDR_i;
    input PWDATA_i;
    input PRDATA_o;
    input PREADY_o;
    input PSLVERR_o;
  endclocking

  modport drv_mp(clocking drv_cb);

  modport mon_mp(clocking mon_cb);

  //-------------- Assertions -------------
  property signals_stable;
    @(posedge CLK) $rose(
        PSEL_i
    ) |-> ($stable(
        PWRITE_i
    ) && $stable(
        PADDR_i
    ) && $stable(
        PWDATA_i
    )) until PREADY_o [-> 1];
  endproperty

  property penable_stable;
    @(posedge CLK) $rose(
        PENABLE_i
    ) |-> ($stable(
        PSEL_i
    ) && $stable(
        PENABLE_i
    )) until PREADY_o [-> 1];
  endproperty

  property psel_to_pready;
    @(posedge CLK) (PSEL_i && PENABLE_i) |-> ##[0:$] PREADY_o;
  endproperty

  property address_reserved;
    @(posedge CLK) PSEL_i |-> ((PADDR_i != 3'b100) || (PADDR_i != 3'b110) || (PADDR_i != 3'b111));
  endproperty

  property penable_deassert;
    @(posedge CLK) (!PSEL_i) |-> (!PENABLE_i);
  endproperty

  property valid_write_data_transfer;
    @(posedge CLK) (PSEL_i && PENABLE_i && PWRITE_i) |-> (PWDATA_i !== 'hx);
  endproperty

  property valid_read_data_transfer;
    @(posedge CLK) (PSEL_i && PENABLE_i && (!PWRITE_i)) |-> (PRDATA_o !== 'hx);
  endproperty

  property pready_low_at_start;
    @(posedge CLK) (PSEL_i && (!PENABLE_i)) |-> (!PREADY_o);
  endproperty

  property pready_deassert;
    @(posedge CLK) (!PSEL_i) |-> (!PREADY_o);
  endproperty

  SIGNAL_STABLE :
  assert property (signals_stable) $info("signal stablity is verified");
  else $error("signal stablity is not verified");

  PENABLE_STABLE :
  assert property (penable_stable) $info("Penable is stable until Pready is high");
  else $error("Penable is not stable");
  PSEL_TO_PREADY :
  assert property (psel_to_pready) $info("Psel&Penable to Pready is verified ");
  else $error("Psel&Pneable is not verified");

  ADDRESS_RESERVED :
  assert property (address_reserved) $info("reserved addresses are verified");
  else $error("Reserved addresses are not verified");

  PENABLE_DEASSERT :
  assert property (penable_deassert)
    $info("When Psel goes low even Penable should go low is verified");
  else $error("When Psel goes low even Penable should go low is verified");
  PWDATA_TRANSFER :
  assert property (valid_write_data_transfer) $info("Valid Write Data Transfer");
  else $error("Valid write Data Transfer Failed");
  PRDATA_TRANSFER :
  assert property (valid_read_data_transfer) $info("valid read data transfer");
  else $error("valid read data transfer failed");
  PREADY_START :
  assert property (pready_low_at_start) $info("Pready is low at the start");
  else $error("Pready is not low at the start");
  PREADY_DEASSERT :
  assert property (pready_deassert) $info("Pready is low when Psel goes low");
  else $error("Pready is not low when Psel is low");
endinterface
