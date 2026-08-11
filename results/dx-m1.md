# Raspberry Pi 5 + DEEPX DX-M1 — 원본 측정값

측정일: 2026-08-10
도구: `dxbenchmark` (DXRT v3.4.0)
조건: 배치 1, NPU 3코어 전체, `--use-ort`, `DXRT_DYNAMIC_CPU_THREAD` 미설정

---

## 1. 장치 정보

```
Device 0: M1, Accelerator type
RT Driver version   : v2.6.0
PCIe Driver version : v2.5.0
FW version          : v2.7.4
Memory : LPDDR5 5600 Mbps, 3.92GiB
Board  : M.2, Rev 1.0
PCIe   : Gen3 X1
NPU 0: voltage 750 mV, clock 1000 MHz, temperature 37'C
NPU 1: voltage 750 mV, clock 1000 MHz, temperature 37'C
NPU 2: voltage 750 mV, clock 1000 MHz, temperature 37'C
```

호스트 메모리 7.87 GB, 커널 6.18.39+rpt-rpi-2712, Debian 13 (trixie).

연산 정밀도는 INT8 고정이다. 다른 정밀도를 선택할 수 없다.

---

## 2. 종합

| 작업 | 모델 | 입력 | NPU 추론 | NPU 태스크 총계 | CPU 태스크 |
|---|---|---|---|---|---|
| 객체 검출 | yolov8-n | 640² | 3.83 ms | 27.48 ms | 20.41 ms |
| 인스턴스 분할 | yolov8-n-seg | 640² | 5.26 ms | 43.77 ms | 22.33 ms |
| 클래스 무관 분할 | FastSAM-s | 1024² | 22.39 ms | 102.89 ms | 51.60 ms |
| 깊이 추정 | DAv2 ViT-S | 224² | 17.99 ms | 27.40 ms | 47.27 ms (+ 전처리 0.32 ms) |
| 깊이 추정 | DAv2 ViT-B | 224² | 46.66 ms | 63.94 ms | 92.12 ms (+ 전처리 0.31 ms) |

---



https://github.com/user-attachments/assets/ab57e8a5-4359-42df-8034-9e2e33f87ce4



## 3. 객체 검출 — yolov8-n, 640×640

반복 300회, 워밍업 50.

**그래프 구조**

```
images [1,640,640,3] UINT8 → npu_0 → cpu_0 → output0 [1,84,8400]
```

NPU 출력은 6개 텐서, 합계 4.84 MB. NPU 메모리 사용량 77.5 MB.

**npu_0**

| 항목 | min | max | 평균 | CoV |
|---|---|---|---|---|
| Buffer Pool Wait | 2.31 ms | 70.50 ms | 17.74 ms | 46.28% |
| NPU Task (total) | 22.69 ms | 70.50 ms | 27.48 ms | 15.34% |
| NPU Input Format Handler | 0.50 µs | 110.54 µs | 6.42 µs | 120.13% |
| H2D | 1.87 ms | 7.10 ms | 3.15 ms | 27.08% |
| **Inference** | **3.80 ms** | **6.02 ms** | **3.83 ms** | **6.07%** |
| Inference Core 0 | 3.80 ms | 6.02 ms | 3.81 ms | 3.83% |
| Inference Core 1 | 5.58 ms | 5.95 ms | 5.76 ms | 4.48% |
| Inference Core 2 | 4.75 ms | 5.59 ms | 5.17 ms | 11.38% |
| D2H | 7.70 ms | 18.08 ms | 7.97 ms | 11.64% |
| NPU Output Format Handler | 9.08 ms | 16.72 ms | 11.75 ms | 8.14% |

**cpu_0**

| 항목 | min | max | 평균 | CoV |
|---|---|---|---|---|
| Buffer Pool Wait | 4.96 µs | 26.00 µs | 7.91 µs | 32.99% |
| CPU Dispatch Wait | 15.06 µs | 83.91 ms | 65.63 ms | 41.85% |
| CPU Task (total) | 15.80 ms | 33.98 ms | 20.41 ms | 8.28% |

---

## 4. 인스턴스 분할 — yolov8-n-seg, 640×640

반복 300회, 워밍업 50.

**그래프 구조**

```
images [1,640,640,3] UINT8 → npu_0 → cpu_0 → output0 [1,116,8400], output1 [1,32,160,160]
```

NPU 출력은 10개 텐서, 합계 9.19 MB. NPU 메모리 사용량 135.2 MB.

**npu_0**

| 항목 | min | max | 평균 | CoV |
|---|---|---|---|---|
| Buffer Pool Wait | 2.91 ms | 102.22 ms | 19.29 ms | 49.03% |
| NPU Task (total) | 39.87 ms | 126.52 ms | 43.77 ms | 16.99% |
| NPU Input Format Handler | 0.48 µs | 67.52 µs | 3.79 µs | 125.02% |
| H2D | 1.87 ms | 9.03 ms | 3.40 ms | 28.72% |
| **Inference** | **5.21 ms** | **8.31 ms** | **5.26 ms** | **6.77%** |
| Inference Core 0 | 5.21 ms | 8.13 ms | 5.23 ms | 3.95% |
| Inference Core 1 | 7.87 ms | 8.31 ms | 8.09 ms | 3.88% |
| Inference Core 2 | 7.53 ms | 8.10 ms | 7.81 ms | 5.09% |
| D2H | 12.98 ms | 25.63 ms | 13.84 ms | 10.29% |
| NPU Output Format Handler | 18.81 ms | 30.30 ms | 20.19 ms | 6.07% |

**cpu_0**

| 항목 | min | max | 평균 | CoV |
|---|---|---|---|---|
| CPU Dispatch Wait | 19.39 µs | 73.82 ms | 59.63 ms | 41.75% |
| CPU Task (total) | 16.60 ms | 39.81 ms | 22.33 ms | 6.87% |

---

## 5. 클래스 무관 분할 — FastSAM-s, 1024×1024

반복 200회, 워밍업 30.

**그래프 구조**

```
images [1,1024,1024,3] UINT8 → npu_0 → cpu_0 → output0 [1,37,21504], output1 [1,32,256,256]
```

NPU 출력은 10개 텐서, 합계 16.73 MB. NPU 메모리 사용량 344.2 MB, 전체 675.7 MB.

**npu_0**

| 항목 | min | max | 평균 | CoV |
|---|---|---|---|---|
| Buffer Pool Wait | 3.06 µs | 222.40 ms | 45.63 ms | 49.71% |
| NPU Task (total) | 92.18 ms | 278.88 ms | 102.89 ms | 19.35% |
| NPU Input Format Handler | 0.61 µs | 75.46 µs | 4.02 µs | 136.75% |
| H2D | 4.68 ms | 14.89 ms | 7.13 ms | 24.00% |
| **Inference** | **22.10 ms** | **35.09 ms** | **22.39 ms** | **7.67%** |
| Inference Core 0 | 22.10 ms | 35.09 ms | 22.21 ms | 4.75% |
| Inference Core 1 | 31.61 ms | 34.47 ms | 33.04 ms | 6.12% |
| Inference Core 2 | 31.24 ms | 32.80 ms | 32.02 ms | 3.43% |
| D2H | 21.59 ms | 42.03 ms | 23.61 ms | 12.34% |
| NPU Output Format Handler | 41.80 ms | 69.98 ms | 47.57 ms | 7.47% |

**cpu_0**

| 항목 | min | max | 평균 | CoV |
|---|---|---|---|---|
| CPU Dispatch Wait | 18.83 µs | 171.31 ms | 141.17 ms | 40.22% |
| CPU Task (total) | 35.55 ms | 75.51 ms | 51.60 ms | 9.39% |

---

## 6. 깊이 추정 — Depth Anything V2 ViT-S, 224×224

반복 500회, 워밍업 50.

**그래프 구조**

```
input [1,3,224,224] → cpu_0 → npu_0 → cpu_1 → output [1,224,224]
```

cpu_0은 patch embedding conv를 수행하여 `[1,588,16,16]`을 산출한다. npu_0 출력은 `[1,32,128,128]`이며 cpu_1이 최종 해상도로 변환한다. NPU 메모리 사용량 76.4 MB.

**npu_0**

| 항목 | min | max | 평균 | CoV |
|---|---|---|---|---|
| Buffer Pool Wait | 3.44 µs | 21.70 µs | 5.57 µs | 18.64% |
| NPU Task (total) | 26.76 ms | 58.16 ms | 27.40 ms | 8.22% |
| NPU Input Format Handler | 1.03 ms | 1.75 ms | 1.11 ms | 4.57% |
| H2D | 0.94 ms | 1.29 ms | 1.01 ms | 1.73% |
| **Inference** | **17.94 ms** | **21.68 ms** | **17.99 ms** | **1.97%** |
| Inference Core 0 | 17.94 ms | 21.68 ms | 17.96 ms | 1.15% |
| Inference Core 1 | 21.20 ms | 21.37 ms | 21.29 ms | 0.56% |
| Inference Core 2 | 21.31 ms | 21.59 ms | 21.45 ms | 0.90% |
| D2H | 2.58 ms | 7.24 ms | 2.66 ms | 9.71% |
| NPU Output Format Handler | 4.00 ms | 5.48 ms | 4.22 ms | 3.51% |

**cpu_0 / cpu_1**

| 항목 | cpu_0 | cpu_1 |
|---|---|---|
| CPU Task (total) 평균 | 0.32 ms | 47.27 ms |
| CoV | 7.20% | 3.14% |
| CPU Dispatch Wait 평균 | 21.31 µs | 188.69 ms |

CPU 태스크 입력 큐 부하 72.22%.

---

## 7. 깊이 추정 — Depth Anything V2 ViT-B, 224×224

반복 500회, 워밍업 50. 그래프 구조는 ViT-S와 동일하되 npu_0 출력이 `[1,64,128,128]`이다. NPU 메모리 사용량 170.5 MB.

**npu_0**

| 항목 | min | max | 평균 | CoV |
|---|---|---|---|---|
| Buffer Pool Wait | 3.28 µs | 10.43 µs | 5.29 µs | 9.03% |
| NPU Task (total) | 62.80 ms | 156.01 ms | 63.94 ms | 10.32% |
| NPU Input Format Handler | 1.03 ms | 1.43 ms | 1.09 ms | 2.49% |
| H2D | 0.93 ms | 1.28 ms | 1.02 ms | 1.56% |
| **Inference** | **46.42 ms** | **62.10 ms** | **46.66 ms** | **3.33%** |
| Inference Core 0 | 46.42 ms | 61.91 ms | 46.55 ms | 1.92% |
| Inference Core 1 | 61.38 ms | 62.10 ms | 61.74 ms | 0.83% |
| Inference Core 2 | 60.73 ms | 61.76 ms | 61.25 ms | 1.19% |
| D2H | 5.05 ms | 14.49 ms | 5.16 ms | 9.66% |
| NPU Output Format Handler | 9.02 ms | 13.58 ms | 9.35 ms | 3.23% |

**cpu_0 / cpu_1**

| 항목 | cpu_0 | cpu_1 |
|---|---|---|
| CPU Task (total) 평균 | 0.31 ms | 92.12 ms |
| CoV | 5.54% | 0.98% |
| CPU Dispatch Wait 평균 | 22.13 µs | 358.65 ms |

---

## 8. 참고 — `DXRT_DYNAMIC_CPU_THREAD` 비교

Depth Anything V2 ViT-S에서만 두 조건을 측정했다.

| 항목 | 미설정 | ON |
|---|---|---|
| cpu_1 입력 큐 부하 | 72.22% | 45.20% |
| cpu_1 Task (total) | 47.27 ms | 49.18 ms |
| cpu_1 Dispatch Wait | 188.69 ms | 63.94 ms |
| NPU Inference | 17.99 ms | 18.77 ms |
| Inference Core 0/1/2 | 17.96 / 21.29 / 21.45 ms | 18.65 / 18.91 / 20.04 ms |

ON에서 코어 간 편차가 줄었으나 단일 프레임 지연은 개선되지 않았다. 본 문서의 다른 측정값은 모두 미설정 상태다.

---

## 9. 측정하지 않은 항목

- **전력** — Raspberry Pi 5에 내장 전력 센서가 없고 외부 계측기를 확보하지 못했다. `dxrt-cli --status`는 NPU 전압(750 mV)과 온도만 보고하며 전류를 제공하지 않는다
- **지연 백분위수** — `dxbenchmark`는 min/max/평균/CoV만 출력한다
- **다른 정밀도** — 하드웨어가 INT8 전용이다
- **NPU 코어 수 변화** — `-n`, `-d` 옵션으로 코어 수를 제한한 측정은 수행하지 않았다
- **정확도**
- **열 조건 통제**
