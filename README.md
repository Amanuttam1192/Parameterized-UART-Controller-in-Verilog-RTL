# Parameterized UART Controller in Verilog (RTL) with Self-Checking Testbench

A synthesizable UART (Universal Asynchronous Receiver/Transmitter) written in
Verilog RTL, verified with a self-checking loopback testbench. Built to
practise the frontend digital-design flow: FSM-based RTL, clock-domain
synchronisation, parameterised design, and simulation-based verification.

## Features

- **8-N-1 framing** (8 data bits, no parity, 1 stop bit), LSB first
- **Transmitter**: 4-state FSM (IDLE / START / DATA / STOP)
- **Receiver**: 16x oversampling with **mid-bit sampling** for noise margin
- **2-flip-flop synchroniser** on the async RX line to avoid metastability
- **Baud generator** parameterised by clock frequency, baud rate, oversample
- Fully **parameterised** — same RTL runs at any clock/baud on real hardware

## Module hierarchy

```
uart_top
├── baud_gen   : generates a BAUD*16 tick strobe from the system clock
├── uart_tx    : START/DATA/STOP transmit FSM, shifts data LSB-first
└── uart_rx    : oversampling receive FSM + 2-FF input synchroniser
```

## Simulation

Requires Icarus Verilog (`iverilog`, `vvp`).

```
iverilog -g2012 -o uart_sim rtl/*.v tb/tb_uart.v
vvp uart_sim
```

The testbench loops TX back into RX, sends a set of test bytes (walking bits,
0x00, 0xFF, ASCII 'T''I'), and checks each recovered byte against what was
sent. Output:

```
=== UART loopback self-check ===
  [PASS] byte 0: sent 0x55, received 0x55
  ...
  [PASS] byte 7: sent 0x49, received 0x49
sent = 8, received = 8, errors = 0
RESULT: ALL TESTS PASSED
```

A `uart.vcd` waveform is produced for viewing in GTKWave.

## Design notes (interview-relevant)

- **Why oversample 16x?** The RX has no shared clock with the TX. Sampling 16
  times per bit lets the receiver find the start-bit edge and then sample each
  data bit near its centre, tolerating baud mismatch up to a few percent.
- **Why the 2-FF synchroniser?** `rx` is asynchronous to the receiver clock;
  sampling it directly risks metastability. Two flip-flops let any metastable
  value settle before the logic uses it — the standard single-bit CDC fix.
- **Synthesizable style**: single clock, synchronous reset, no latches (every
  branch of every FSM assigns the outputs), no blocking/non-blocking mixing in
  sequential blocks.
- **Parameterisation**: `CLK_FREQ`, `BAUD`, `OVERSAMPLE` are parameters so the
  divisor is computed at elaboration; the testbench uses a small ratio for
  speed while hardware uses the real values.

## Possible extensions

Configurable parity, a TX/RX FIFO for buffering, an APB/AXI-Lite register
interface, and a `frame_error` output on a bad stop bit.
