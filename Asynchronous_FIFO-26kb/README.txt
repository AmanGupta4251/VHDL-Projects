26 KB ASYNCHRONOUS FIFO — BEGINNER BEHAVIORAL VHDL

Capacity:
26 KB = 26,624 bytes = 212,992 bits.

Implementation:
- 8-bit data
- 26,624 byte storage
- Independent write and read clocks
- 100% behavioral modelling for the FIFO and testbench
- Gray-coded clock-domain pointer crossing
- Two flip-flop synchronizers
- Exact non-power-of-two FIFO capacity
- No structural component instantiation in the FIFO

Files:
1. async_fifo_26kb.vhd
   Main FIFO. Contains the memory, pointers, CDC synchronizers,
   full/empty logic and read/write logic.

2. sram_26kb.vhd
   Standalone behavioral 26 KB SRAM model for learning/reference.
   It is intentionally not instantiated by the FIFO because doing so
   would turn the top-level into structural/hierarchical modelling.

3. tb_async_fifo_26kb.vhd
   Behavioral testbench with independent clocks and read/write tests.

GHDL commands:

ghdl -a --std=08 async_fifo_26kb.vhd
ghdl -a --std=08 tb_async_fifo_26kb.vhd
ghdl -e --std=08 tb_async_fifo_26kb
ghdl -r --std=08 tb_async_fifo_26kb --wave=fifo_26kb.ghw

GTKWave:
gtkwave fifo_26kb.ghw

Recommended signals:
wr_clk
rd_clk
reset
wr_en
wr_data
full
rd_en
rd_data
empty

IMPORTANT:
The standalone sram_26kb.vhd is not used by async_fifo_26kb.vhd.
This is intentional so that the FIFO remains 100% behavioral as requested.
