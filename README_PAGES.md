# SPI UVM RAL — Interactive Protocol Lab

A static GitHub Pages companion for the APB-to-SPI UVM verification project.

## Features

- SPI timing explorer with CPOL/CPHA modes 0–3, editable or random 8-bit MOSI/MISO data, play/pause, single-edge stepping, and speed control.
- APB timing explorer with read/write selection, address/data fields, configurable PREADY wait states, play/pause, single-cycle stepping, and speed control.
- APB agent ↔ DUT ↔ SPI agent architecture diagram with signal directions.
- Responsive layout styled to match the dark technical palette of `allfathergivemesite`.

## Enable GitHub Pages

1. Open **Settings → Pages** in this repository.
2. Under **Build and deployment**, choose **Deploy from a branch**.
3. Select branch **master** and folder **/(root)**, then save.
4. Wait for GitHub Pages to publish the site. The URL should be `https://tryhard727.github.io/spi_uvm_ral/`.

The site is plain HTML/CSS/JavaScript; no build step or package installation is required.

## Important scope note

The waveform explorer is an educational timing visualization, not a simulator of the actual RTL or UVM testbench. The architecture uses common APB/SPI naming and should be reconciled against the current interface and RTL signal declarations before treating every name as exact.
