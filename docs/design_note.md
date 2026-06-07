# Design Notes: Matrix-Vector Accelerator Implementation

## 1. Mathematical Pipeline & Data Precision

All internal datapath logic utilizes fixed-point arithmetic, with data widths and scaling factors annotated in the VHDL source comments.

* **Row Multiplication:** The core processes the matrix row-by-row 
* **Saturation Guard:** To prevent saturation, the output of each multiplication phase is actively checked. If it overflows, it is hard-clipped to a 16-bit signed boundary: **`32767`** or **`-32768`**.
* **Scaling Plane (Z):** The clipped results are integrated into the internal accumulator (`scalar_acc`). This accumulated value is then multiplied by the configuration coefficient B to produce the intermediate output value Z

---

## 2. Activation Layer (`tanh_approx`)

The non-linear activation stage uses an optimized, AI-generated symmetric Look-Up Table (LUT) to approximate the hyperbolic tangent function.

* **Granularity:** The LUT tracks input changes in steps of **`0.25`**.
* **Symmetry Optimization:** Because $\tanh(x)$ is an **odd function** ($\tanh(-x) = -\tanh(x)$), the physical LUT table only needs to store half the dataset.
* **Input Window:** The logic handles active inputs ranging between **`-3.75` and `+3.75**`, mapping outputs smoothly within a **`-1` to `+1**` normalized range.

```