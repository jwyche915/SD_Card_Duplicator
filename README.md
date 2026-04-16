# SD Card Duplicator — FPGA

A VHDL project that duplicates the contents of one SD card to another using the
**Digilent Nexys Video** (Artix-7 XC7A200T) FPGA development board.

- **Source SD card:** Onboard microSD slot
- **Destination SD card:** VKLSVAN SD card reader/writer on **PMOD JA**
- **Interface:** SPI mode (both cards)

## Getting Started

### Prerequisites
- Xilinx Vivado 2020.2 or later
- Digilent Nexys Video board

### Create the Vivado Project
1. Open Vivado
2. In the Tcl Console, navigate to this directory:
   ```tcl
   cd C:/Users/diana/source/repos/Antigravity/SD_Card_Duplicator
   ```
3. Run the project creation script:
   ```tcl
   source create_project.tcl
   ```

### Build and Program
```tcl
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
```
Then use the Hardware Manager to program the FPGA.

### Run Simulation
```tcl
launch_simulation
```
The default simulation top is `tb_spi_master`. Change it in project settings
to run `tb_sd_card_controller`.

## Usage

1. Insert the **source** microSD card into the onboard slot.
2. Connect the **VKLSVAN SD module** to **PMOD JA** and insert the destination card.
3. Set the **switches (SW[15:0])** to select the number of 512-byte blocks to
   copy (value × 1024). For example:
   - `SW = 1` → 1024 blocks = **512 KB**
   - `SW = 2` → 2048 blocks = **1 MB**
   - `SW = 1024` → ~**512 MB**
4. Press **BTNC** to start the duplication.
5. Monitor progress via the **LEDs**:
   - LED 0: Heartbeat (system running)
   - LED 1: Source card initialized
   - LED 2: Destination card initialized
   - LED 3: Copy in progress (blinking)
   - LED 4–7: Progress bar
   - All LEDs solid: Done
   - All LEDs flashing: Error

## PMOD JA Pin Mapping

| JA Pin | FPGA Pin | Signal      |
|--------|----------|-------------|
| 1      | AB22     | `CS_N`      |
| 2      | AB21     | `MOSI`      |
| 3      | AB20     | `MISO`      |
| 4      | AB18     | `SCLK`      |
| 5      | —        | GND         |
| 6      | —        | VCC (3.3V)  |

## Project Structure

```
SD_Card_Duplicator/
├── README.md
├── .gitignore
├── create_project.tcl
├── src/
│   ├── sd_card_duplicator_top.vhd
│   ├── spi_master.vhd
│   ├── sd_card_controller.vhd
│   ├── duplicator_fsm.vhd
│   ├── clk_divider.vhd
│   └── status_display.vhd
├── constrs/
│   └── nexys_video.xdc
└── sim/
    ├── tb_spi_master.vhd
    └── tb_sd_card_controller.vhd
```

## Module Hierarchy

```
sd_card_duplicator_top
├── clk_divider (source)
├── spi_master (source)
├── sd_card_controller (source)
├── clk_divider (destination)
├── spi_master (destination)
├── sd_card_controller (destination)
├── duplicator_fsm
└── status_display
```

## License

This project is for educational / personal use.
