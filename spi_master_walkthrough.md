SPI Master Controller — Detailed Walkthrough

This VHDL module implements a Serial Peripheral Interface (SPI) master for transmitting and receiving 8-bit bytes. It's designed to interface with devices like SD cards, where the parent module controls chip-select timing across multi-byte transactions.

High-Level Operation

The module shifts out one byte on MOSI (most-significant bit first) while simultaneously sampling one byte from MISO. A single transfer takes 8 bit periods, with each bit period divided into two phases by the external clken timing signal.

Port Descriptions
Clock and Reset
• clk — System clock; all logic is synchronous to this edge.
• reset — Synchronous reset; returns the module to idle with outputs in known states.

SPI Bus Signals
| Signal | Direction | Purpose |
|--------|-----------|---------|
| sclk | out | SPI clock; idles low, pulses high during each bit transfer |
| mosi | out | Master-out, slave-in data line |
| miso | in | Master-in, slave-out data line |
| csn | out | Active-low chip select (directly driven by csnin) |

Control Inputs
• csnin — The parent module supplies this value, and it passes straight through to csn. This allows multi-byte SD commands to hold chip-select asserted across several byte transfers.
• clken — A one-cycle pulse at the desired SPI half-period rate. The module advances its internal phase (and thus toggles sclk) only when clken is high.

Data Interface
| Signal | Direction | Purpose |
|--------|-----------|---------|
| txdata | in | Byte to transmit |
| txvalid | in | Pulse high for one cycle to begin a transfer |
| txready | out | High when idle and ready for a new byte |
| rxdata | out | Received byte (valid when rxvalid pulses) |
| rxvalid | out | One-cycle pulse indicating rxdata is valid |

Internal State Machine

The controller uses a simple three-state FSM:

``mermaid
stateDiagram-v2
    [*] --> SIDLE
    SIDLE --> STRANSFER : txvalid = '1'
    STRANSFER --> SDONE : bitcnt = 7 and trailing edge
    SDONE --> SIDLE : (unconditional, next cycle)
`

State Descriptions

SIDLE
• sclk held low, mosi held high (idle state).
• txready asserted so the parent knows it can issue a new byte.
• On seeing txvalid, the module latches txdata into shiftout, drives the MSB onto mosi immediately, clears the bit counter, de-asserts txready, and transitions to STRANSFER.

STRANSFER
• The module waits for each clken pulse, then alternates between two phases controlled by the internal phase flag:

| Phase | clken Action |
|-------|-----------------|
| 0 (leading edge) | Drive sclk high; sample miso into the LSB of shiftin (left-shift and append) |
| 1 (trailing edge) | Drive sclk low; if bitcnt < 7, increment counter, left-shift shiftout, and present the next bit on mosi; if bitcnt = 7, move to SDONE |

This produces the classic SPI Mode 0 timing: data is set up on the falling edge and sampled on the rising edge.

SDONE
• Lasts exactly one clock cycle.
• Copies shiftin to rxdata and pulses rxvalid.
• Re-asserts txready and returns to SIDLE.

Timing Diagram (Conceptual)

For a single-byte transfer of 0xA5 (10100101):

`
clken   ⎍⎍⎍⎍⎍⎍⎍⎍⎍⎍⎍⎍⎍⎍⎍⎍
sclk     ⎍⎍⎍⎍⎍⎍⎍⎍⎍⎍⎍⎍⎍⎍⎍⎍__
mosi        1  0  1  0  0  1  0  1   (idle '1')
miso     (sampled on rising sclk edges)
txready ⎺⎺_________⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺⎺
rxvalid _______⎍___
`

Each clken pulse advances half a bit period, so 16 pulses complete one byte (8 rising edges + 8 falling edges).

Key Design Points
External clock enable — Rather than embedding a prescaler, the module delegates bit timing to an external clkdivider. This keeps the SPI master simple and lets the system adjust baud rate by changing the divider.

Pass-through chip select — csnin flows directly to csn. The SPI master doesn't decide when to assert or release CS; that responsibility stays with the parent, which is essential for protocols like SD/MMC where CS must stay low across multi-byte command sequences.

Immediate MOSI drive — When a transfer begins, the MSB appears on mosi in the same cycle. This ensures the data line is stable before the first rising clock edge.

Single-cycle completion pulse — rxvalid is high for exactly one clock, making it easy to register the received byte without missing or double-counting.

Typical Usage Flow
Parent asserts csnin low to select the slave.
Parent places the command byte on txdata and pulses txvalid.
Parent waits for txready to return high (or watches for rxvalid).
Repeat steps 2–3 for additional bytes in the transaction.
Parent releases csn_in` high when the transaction is complete.