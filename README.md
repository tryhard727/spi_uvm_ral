# My APB SPI UVM Verification Environment

## What is this project?

This repository showcases my personal Universal Verification Methodology (UVM) testbench developed for thoroughly verifying an APB (Advanced Peripheral Bus) to SPI (Serial Peripheral Interface) RTL (Register Transfer Level) design. It's a comprehensive verification environment built from the ground up to ensure the robustness and correctness of the SPI core.

## Why did I build this?

I embarked on this project to deepen my understanding of advanced verification methodologies, particularly UVM, and to gain hands-on experience in building a complete, reusable, and scalable testbench for a common peripheral like SPI. It serves as a practical demonstration of my skills in SystemVerilog, UVM, and digital design verification.

## What has been implemented and how?

This UVM environment is structured to provide a robust and efficient verification flow. Here's a breakdown of the key components and their implementation:

*   **APB Agent**: I've developed a complete UVM agent for the APB interface. This includes:
    *   **`apb_driver`**: Responsible for driving APB transactions to the RTL.
    *   **`apb_monitor`**: Observes APB activity and converts it into transactions for scoreboard and functional coverage.
    *   **`apb_sequencer`**: Manages and streams APB sequences to the driver.
    *   **`apb_sequence`**: Custom sequences to generate various APB transactions (e.g., writes, reads, error conditions).
*   **SPI Agent**: Similarly, a dedicated UVM agent handles the SPI interface, comprising:
    *   **`spi_driver`**: Drives SPI transactions to the RTL.
    *   **`spi_monitor`**: Monitors SPI bus activity and converts it into transactions.
    *   **`spi_sequencer`**: Controls the flow of SPI sequences.
    *   **`spi_sequence`**: Sequences designed to generate different SPI scenarios (e.g., master writes, reads, various clock polarities and phases).
*   **Register Abstraction Layer (RAL)**: I've implemented a full RAL for the SPI core's registers. This allows for abstract, high-level access to the DUT's registers, simplifying test development and improving readability. Each register (e.g., `spi_br_reg`, `spi_cr1_reg`, `spi_dr_reg`) is modeled, enabling easy read/write access and field manipulation.
*   **RTL Integration**: The `rtl/` directory contains the actual design under test (DUT) components, such as `apb_slave.sv`, `baud_generator.sv`, `shifter.sv`, and `spi_core_top.sv`. These are integrated into the UVM environment, allowing the agents to interact directly with the design.
*   **Testbench Environment (`tb/`)**: The `env.sv` orchestrates the agents, scoreboards, and functional coverage.
    *   **`virtual_sequencer`**: Coordinates sequences between the APB and SPI agents for complex, multi-interface scenarios.
    *   **`scoreboard`**: Compares expected behavior (from reference models or predictions) with actual DUT outputs observed by the monitors, flagging any discrepancies.
*   **Test Cases (`test/`)**: I've developed various test cases (`base_test.sv`) to target specific functionalities and corner cases of the SPI core, leveraging the sequences and RAL for efficient test development.

## Project Structure

- `apb_agent/`: My UVM agent for the APB interface.
- `spi_agent/`: My UVM agent for the SPI interface.
- `ral/`: My Register Abstraction Layer (RAL) for the SPI registers.
- `rtl/`: The RTL (Register Transfer Level) design files for the APB-SPI core under verification.
- `tb/`: My top-level testbench components, including the environment, virtual sequencer, and scoreboard.
- `test/`: My collection of test cases for the UVM environment.
- `common/`: Common definitions and UVM package includes used across the testbench.
- `interfaces/`: SystemVerilog interfaces connecting the RTL and testbench.
- `mergedral.sv`: A merged file likely containing the complete RAL model.

## Getting Started

To explore this project, you'll need a SystemVerilog simulator (e.g., Questa, VCS, Xcelium). Detailed compilation and simulation commands would typically be provided here to get the testbench up and running.

## Verification Goals

My primary goal with this UVM environment is to achieve comprehensive functional verification of the APB-SPI RTL design. This includes ensuring:
*   Correct APB slave functionality (reads and writes to SPI registers).
*   Accurate SPI master/slave communication, including various clock polarities and phases.
*   Proper baud rate generation and data shifting.
*   Robust handling of edge cases and error conditions.
*   High functional coverage of the design's features.
