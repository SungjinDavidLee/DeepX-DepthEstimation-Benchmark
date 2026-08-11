# On-Device Vision Inference Benchmark

Latency, throughput, and power measurements for vision inference models on DEEPX DX-M1, NVIDIA Jetson AGX Xavier, and NVIDIA Jetson AGX Thor.

Four tasks are covered — object detection, instance segmentation, class-agnostic segmentation, and monocular depth estimation — across five models on each platform.

The purpose is to record measurement procedures and raw figures. Cross-platform comparisons are presented only where conditions match; mismatched items are listed separately.

[한국어 문서](../README.md)

---

## 1. Summary

**Low-power conditions (on-device deployment range)**

| Task | DX-M1 (INT8, 3–5 W) | Xavier 15 W (INT8) |
|---|---|---|
| Object detection | **3.83 ms** | 6.82 ms |
| Instance segmentation | **5.26 ms** | 7.52 ms |
| Depth estimation ViT-S | 17.99 ms | **15.29 ms** |
| Depth estimation ViT-B | 46.66 ms | **29.38 ms** |

DX-M1 is faster on convolution-heavy models; Xavier is faster on transformer-based depth estimation models.

**Higher-tier platform reference**

Thor (120 W mode) is fastest across all tasks. Its power budget differs substantially from the two platforms above, so it is not placed in the same table. Figures are in [3-3](#3-3-reference--thor-120-w-mode).

**Qualitative comparison**

Depth map output videos, produced by running the same input clip on all three platforms, are in [docs/qualitative.md](../docs/qualitative.md) and [media/](../media/). Measurement conditions differ from this document, so the two sets of figures should not be mixed.

---

## 2. Measurement environments

### 2-1. Raspberry Pi 5 + DEEPX DX-M1

| Item | Value |
|---|---|
| Host | Raspberry Pi 5, 8 GB |
| Accelerator | DEEPX DX-M1 (M.2 2280) |
| NPU | 3 cores, 1000 MHz, 750 mV |
| Accelerator memory | LPDDR5 5600 Mbps, 3.92 GiB |
| Interface | PCIe Gen3 x1 |
| OS / kernel | Debian 13 (trixie) / 6.18.39+rpt-rpi-2712 |
| Runtime | DXRT v3.4.0 (driver v2.6.0, PCIe v2.5.0, FW v2.7.4) |
| Precision | INT8 (hardware-fixed) |
| Power | 3 W typ / 5 W max `[chip spec, not measured]` |

DX-M1 is an INT8-only accelerator. No other precision can be selected, so this platform is always INT8 in precision comparisons.

### 2-2. Jetson AGX Xavier

| Item | Value |
|---|---|
| Compute capability | 7.2 |
| SM count | 8 |
| Core clock | 1.377 GHz |
| Memory | 30,990 MiB, 256-bit, 0.675 GHz |
| OS / kernel | Ubuntu 20.04.6 LTS / 5.10.216-tegra |
| JetPack | R35.6.4 |
| CUDA / TensorRT | 11.4 / **8.5.2** |
| Power mode | **pmode 7 = MODE_15W_DESKTOP** |
| Idle power | 8.23 W (424 mA @ 19.4 V) |

### 2-3. Jetson AGX Thor Developer Kit

| Item | Value |
|---|---|
| Memory | 122 GiB |
| OS / kernel | Ubuntu 24.04.4 LTS / 6.8.12-1021-tegra |
| JetPack | R39.2.0 |
| CUDA / TensorRT | 13.2 / **10.16.2** |
| Power mode | **pmode 1 = 120 W** |
| Idle power | 18.98–19.44 W |

---

## 3. Results

### 3-1. Raspberry Pi 5 + DX-M1 (INT8)

`dxbenchmark` NPU task profile. Values are means.

| Task | Model | Input | NPU inference | H2D | D2H | Output format | CPU task |
|---|---|---|---|---|---|---|---|
| Object detection | yolov8-n | 640² | 3.83 ms | 3.15 ms | 7.97 ms | 11.75 ms | 20.41 ms |
| Instance segmentation | yolov8-n-seg | 640² | 5.26 ms | 3.40 ms | 13.84 ms | 20.19 ms | 22.33 ms |
| Class-agnostic segmentation | FastSAM-s | 1024² | 22.39 ms | 7.13 ms | 23.61 ms | 47.57 ms | 51.60 ms |
| Depth estimation | DAv2 ViT-S | 224² | 17.99 ms | 1.01 ms | 2.66 ms | 4.22 ms | 47.27 ms |
| Depth estimation | DAv2 ViT-B | 224² | 46.66 ms | 1.02 ms | 5.16 ms | 9.35 ms | 92.12 ms |

Depth estimation models have an additional CPU preprocessing task accounting for 0.31 ms.

Power was not measured. The Raspberry Pi 5 has no onboard power sensor and no external instrument was available.

### 3-2. Jetson AGX Xavier (15 W mode)

Measured with `trtexec`.

**FP16**

| Task | Input | GPU compute | p99 | Throughput | Power | FPS/W |
|---|---|---|---|---|---|---|
| Object detection | 640² | 9.28 ms | 9.32 ms | 107.75 qps | 13.46 W | 8.00 |
| Instance segmentation | 640² | 10.72 ms | 10.79 ms | 93.19 qps | 13.51 W | 6.90 |
| Class-agnostic segmentation | 640² | 19.74 ms | 19.77 ms | 50.66 qps | 13.68 W | 3.70 |
| Depth estimation ViT-S | 224² | 13.90 ms | 14.05 ms | 71.94 qps | 13.16 W | 5.47 |
| Depth estimation ViT-B | 224² | 31.87 ms | 32.07 ms | 31.38 qps | 14.23 W | 2.21 |

**INT8** (no calibration — see 5-4)

| Task | Input | GPU compute | p99 | Throughput | Power | FPS/W |
|---|---|---|---|---|---|---|
| Object detection | 640² | 6.82 ms | 7.26 ms | 137.35 qps | 12.51 W | 10.98 |
| Instance segmentation | 640² | 7.52 ms | 7.56 ms | 119.03 qps | 12.98 W | 9.17 |
| Class-agnostic segmentation | 640² | 12.55 ms | 12.60 ms | 79.68 qps | 13.10 W | 6.08 |
| Depth estimation ViT-S | 224² | 15.29 ms | 15.38 ms | 65.08 qps | 13.04 W | 4.99 |
| Depth estimation ViT-B | 224² | 29.38 ms | 29.49 ms | 33.95 qps | 13.68 W | 2.48 |

### 3-3. Reference — Thor (120 W mode)

The power budget differs substantially from the two platforms above. These figures are reference material showing what a higher-tier platform achieves, not a like-for-like comparison.

**FP16**

| Task | Input | GPU compute | p99 | Throughput | Power | FPS/W |
|---|---|---|---|---|---|---|
| Object detection | 640² | 0.854 ms | 0.939 ms | 1137.09 qps | 59.50 W | 19.11 |
| Instance segmentation | 640² | 0.940 ms | 1.035 ms | 1019.77 qps | 65.19 W | 15.64 |
| Class-agnostic segmentation | 640² | 1.237 ms | 1.331 ms | 779.76 qps | 81.17 W | 9.61 |
| Depth estimation ViT-S | 224² | 1.214 ms | 1.397 ms | 801.46 qps | 58.76 W | 13.64 |
| Depth estimation ViT-B | 224² | 1.999 ms | 2.145 ms | 488.83 qps | 82.55 W | 5.92 |

**INT8** (no calibration — see 5-4)

| Task | Input | GPU compute | p99 | Throughput | Power | FPS/W |
|---|---|---|---|---|---|---|
| Object detection | 640² | 1.017 ms | 1.082 ms | 982.04 qps | 47.57 W | 20.64 |
| Instance segmentation | 640² | 1.203 ms | 1.317 ms | 786.08 qps | 49.82 W | 15.78 |
| Class-agnostic segmentation | 640² | 1.387 ms | 1.529 ms | 699.61 qps | 54.86 W | 12.75 |
| Depth estimation ViT-S | 224² | 1.088 ms | 1.219 ms | 893.64 qps | 48.45 W | 18.44 |
| Depth estimation ViT-B | 224² | 1.712 ms | 1.896 ms | 572.20 qps | 57.30 W | 9.99 |

---

## 4. Observations

### 4-1. Relative performance depends on task type

DX-M1 versus Xavier, both at INT8.

| Task | DX-M1 | Xavier 15 W | Ratio |
|---|---|---|---|
| Object detection | 3.83 ms | 6.82 ms | DX-M1 1.78× |
| Instance segmentation | 5.26 ms | 7.52 ms | DX-M1 1.43× |
| Depth estimation ViT-S | 17.99 ms | 15.29 ms | Xavier 1.18× |
| Depth estimation ViT-B | 46.66 ms | 29.38 ms | Xavier 1.59× |

DX-M1 leads on convolution-heavy models; Xavier leads on transformer-based models.

**Hypothesis:** DX-M1's compute units are optimised for convolution, while attention operations in ViT-family models are more constrained by memory bandwidth. This cannot be confirmed from these measurements alone; operator-level profiling would be required.

### 4-2. INT8 has opposite effects on the two Jetson platforms

Change in GPU compute time relative to FP16.

| Task | Xavier | Thor |
|---|---|---|
| Object detection | 26% faster | **19% slower** |
| Instance segmentation | 30% faster | **28% slower** |
| Class-agnostic segmentation | 36% faster | **12% slower** |
| Depth estimation ViT-S | **10% slower** | 10% faster |
| Depth estimation ViT-B | 8% faster | 14% faster |

Xavier gains substantially from INT8 on convolution models but loses on ViT-S. Thor shows the opposite: INT8 is slower on convolution models and only benefits ViT-family models.

**Hypothesis:** Thor's FP16 path is sufficiently optimised that quantisation and dequantisation overhead outweighs INT8 compute gains for convolution operations. The absence of calibration may also contribute.

Power is lower under INT8 on both platforms. On Thor: FP16 59–83 W, INT8 48–57 W.

### 4-3. Non-inference stages dominate on DX-M1

Share of pure inference within the total NPU task.

| Model | Inference | NPU task total | Share |
|---|---|---|---|
| yolov8-n | 3.83 ms | 27.48 ms | 14% |
| yolov8-n-seg | 5.26 ms | 43.77 ms | 12% |
| FastSAM-s | 22.39 ms | 102.89 ms | 22% |
| DAv2 ViT-S | 17.99 ms | 27.40 ms | 66% |
| DAv2 ViT-B | 46.66 ms | 63.94 ms | 73% |

For detection and segmentation models, D2H transfer and output format conversion substantially exceed inference time. The NPU output of yolov8-n-seg is 10 tensors totalling 9.19 MB; D2H alone takes 13.84 ms over the PCIe Gen3 x1 link.

Depth estimation models have small output tensors and therefore a lower share, but their CPU postprocessing tasks exceed inference time (ViT-S 47.27 ms, ViT-B 92.12 ms).

### 4-4. NPU core load is uneven

Per-core inference times on DX-M1.

| Model | Core 0 | Core 1 | Core 2 |
|---|---|---|---|
| yolov8-n | 3.81 ms | 5.76 ms | 5.17 ms |
| yolov8-n-seg | 5.23 ms | 8.09 ms | 7.81 ms |
| DAv2 ViT-S | 17.96 ms | 21.29 ms | 21.45 ms |
| DAv2 ViT-B | 46.55 ms | 61.74 ms | 61.25 ms |

Core 0 is consistently shortest. Load distribution appears uneven at batch size 1, but the cause was not identified.

### 4-5. Latency distribution

On both Jetson platforms, p99 falls within 1.01–1.13× of the mean. Thor shows relatively greater variation but its absolute latency is short enough that this is not a practical concern.

`dxbenchmark` reports only min/max/mean/coefficient of variation and no percentiles, so the latency distribution on DX-M1 could not be characterised in the same form.

### 4-6. Reproducibility

Thor FP16 was measured twice.

| Model | Run 1 | Run 2 | Difference |
|---|---|---|---|
| yolov8n | 0.848 ms | 0.854 ms | 0.7% |
| yolov8n-seg | 0.928 ms | 0.940 ms | 1.3% |
| FastSam-S | 1.223 ms | 1.237 ms | 1.2% |
| DAv2 ViT-S | 1.161 ms | 1.214 ms | 4.6% |
| DAv2 ViT-B | 2.007 ms | 1.999 ms | 0.4% |

Run 2, with a larger sample, is used in the body of this document.

Xavier yolov8n FP16 was also measured twice, yielding 9.266 ms and 9.275 ms — a 0.1% difference.

---

## 5. Limitations

The following should be considered when citing these measurements.

### 5-1. Power modes do not match

| Platform | Power budget |
|---|---|
| DX-M1 | 3–5 W (chip spec, fixed) |
| Xavier | 15 W (`MODE_15W_DESKTOP`) |
| Thor | 120 W |

Configuration change permissions were unavailable, so the modes could not be aligned. Re-measuring Xavier at MAXN and Thor at 70 W (its lowest mode) would improve conditions but was not performed.

In particular, **Thor's results should not be compared directly with the other two platforms.** The power budgets differ by 8–40×.

### 5-2. TensorRT versions differ

Xavier uses 8.5.2, Thor uses 10.16.2. These are tied to JetPack and cannot be changed. Performance differences between the two Jetson platforms therefore include both hardware generation and compiler improvements, and these cannot be separated.

### 5-3. Raspberry Pi power was not measured

There is no onboard power sensor. `dxrt-cli --status` reports NPU voltage (750 mV) and temperature only, not current. The 3–5 W figure cited is the chip manufacturer's specification, not a measurement.

### 5-4. INT8 calibration was not performed

The Jetson INT8 figures in section 3 come from engines built with `trtexec --int8 --fp16` without a calibration dataset. This is valid for latency, throughput, and power measurement, but **accuracy is not guaranteed.**

Inspecting the output quality of these engines revealed that **depth estimation output collapsed**: the entire frame compressed to near a single colour, making depth distinctions impossible. Applying calibration restored normal gradation with no change in speed (4.05 ms to 4.20 ms, within measurement variance).

Details are in [docs/qualitative.md](../docs/qualitative.md), section 4.

DX-M1 output is normal because calibration is applied at vendor compile time. Section 3's INT8 comparison is therefore **calibrated DX-M1 versus uncalibrated Jetson**. It remains valid for speed, but this asymmetry should be noted when citing it.

### 5-5. FastSAM input resolutions differ

DX-M1 uses 1024×1024, Jetson uses 640×640 — a 2.56× difference in pixel count. This task was excluded from cross-platform comparison.

### 5-6. Model sources differ

DX-M1 uses vendor-precompiled `.dxnn` files; Jetson uses engines built from publicly distributed ONNX. Whether the graph scopes match exactly was not verified. See [docs/models.md](../docs/models.md).

### 5-7. Accuracy was not measured

Accuracy metrics such as mAP and depth error were outside the scope of this measurement.

### 5-8. Thermal conditions were not controlled

Ambient temperature and cooling conditions were not recorded. Throttling effects during extended runs cannot be ruled out.

---

## 6. Planned follow-up

- Re-measure after aligning power modes
- Align iteration counts (currently Xavier 2000, Thor 5000)
- Measure Raspberry Pi power (requires external instrument)
- Apply INT8 calibration and evaluate accuracy
- Align FastSAM input resolution
- Compare model graph scopes

---

## 7. Repository structure

```
docs/
  methodology.md    Tools, procedures, comparison conditions
  models.md         Model sources and conditions
  setup.md          Environment setup
  qualitative.md    Same-clip depth estimation comparison
results/
  dx-m1.md          Raspberry Pi 5 + DX-M1 raw measurements
  xavier.md         Jetson AGX Xavier raw measurements
  thor.md           Jetson AGX Thor raw measurements
media/
  input_scene.mp4   Input clip (shared)
  dxm1_int8.mp4     DX-M1 output
  thor_int8.mp4     Thor output (INT8, calibrated)
  thor_fp16.mp4     Thor output (FP16)
  xavier_int8.mp4   Xavier output (INT8, calibrated)
en/
  README.md         This document
```
