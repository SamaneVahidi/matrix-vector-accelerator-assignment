# matrix-vector-accelerator-assignment
Here is the updated, perfectly formatted Markdown block for your `README.md` file. It cleans up the commands, fixes the duplicate file analysis, fixes the trace extension, and formats the testbench sequence into a professional, easy-to-read layout.

---

```markdown
## Simulation & Verification Guide

### 1. Running the Simulation (GHDL & GTKWave)

Run these compilation commands sequentially in your terminal to analyze the design units, elaborate the testbench, and dump the simulation waveforms into a VCD trace:

```bash
# Step 1: Analyze packages and hardware sub-modules
ghdl -a --std=08 rtl/my_types_pkg.vhd
ghdl -a --std=08 rtl/tanh_approx.vhd
ghdl -a --std=08 rtl/mac_engine.vhd
ghdl -a --std=08 rtl/axi_reg.vhd

# Step 2: Analyze top structural core module and testbench
ghdl -a --std=08 rtl/matrix_vector_core.vhd
ghdl -a --std=08 tb/tb_matrix_vector_core.vhd

# Step 3: Elaborate and execute the simulation (Generates waves.vcd)
ghdl -e --std=08 tb_matrix_vector_core
ghdl -r --std=08 tb_matrix_vector_core --vcd=waves.vcd

```

To view and verify the internal processing lines visually, launch the resulting trace file in GTKWave:

```bash
gtkwave waves.vcd &

```

---

### 2. Testbench Host Driver Procedure Breakdown

The verification testbench (`tb_matrix_vector_core.vhd`) utilizes native VHDL-2008 bus verification procedures to emulate a real host CPU driving the AXI4 interface. The stimulus pipeline follows this exact operational sequence:

* **System Initialization:** Issues a hardware master reset pulse to clear the system state. This forces all internal MAC accumulators, index pointers, and memory control registers into a known, deterministic zero state before processing starts.
* **Start Strobe Handshake:** Executes an AXI register write transaction to toggle the execution bit. This edge-triggered control pulse shifts the hardware Finite State Machine (FSM) out of its low-power `IDLE` state.
* **Parameter Configuration:** Writes the custom scaling coefficient $B$ directly to address `0x00` (`REG_CFG`), setting up the dynamic math scaling parameters for the downstream calculation layers.
* **Matrix Stream Burst:** Streams the complete 256-byte verification weight matrix into memory block boundary `0x20`. To bypass memory line latency bottlenecks, data is packed **16 bytes at a time** to perfectly saturate the core processing engine's wide 128-bit internal memory gateway interface.

```
