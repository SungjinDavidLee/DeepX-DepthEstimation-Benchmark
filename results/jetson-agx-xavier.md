# Jetson AGX Xavier — 원본 측정값

측정일: 2026-08-10
도구: `trtexec` (TensorRT 8.5.2)
조건: FP16, 배치 1, 스트림 1, 전력 모드 `pmode 0007`

---

## 1. 장치 정보

`trtexec` 보고 기준.

```
Selected Device: Xavier
Compute Capability: 7.2
SMs: 8
Compute Clock Rate: 1.377 GHz
Device Global Memory: 30990 MiB
Shared Memory per SM: 96 KiB
Memory Bus Width: 256 bits (ECC disabled)
Memory Clock Rate: 0.675 GHz
TensorRT version: 8.5.2
```

JetPack R35.6.4, Ubuntu 20.04.6 LTS, 커널 5.10.216-tegra, CUDA 11.4 (V11.4.315), Python 3.8.10.

전력 모드는 `/var/lib/nvpmodel/status`에서 `pmode:0007`로 확인했다. 모드 명칭은 확인하지 못했다.

---

## 2. 객체 검출 — yolov8n, 640×640

**성능** (반복 2000회)

| 항목 | min | max | mean | median | p90 | p95 | p99 |
|---|---|---|---|---|---|---|---|
| Latency | — | — | 9.79 ms | 9.79 ms | 9.83 | 9.85 | 9.90 |
| **GPU Compute** | 9.17 ms | 9.36 ms | **9.28 ms** | 9.27 ms | 9.30 | 9.31 | 9.32 |
| H2D Latency | 0.29 ms | 0.52 ms | 0.31 ms | 0.30 ms | 0.33 | 0.35 | 0.39 |
| D2H Latency | 0.15 ms | 0.22 ms | 0.22 ms | 0.22 ms | 0.22 | 0.22 | 0.22 |
| Enqueue Time | 1.45 ms | 4.67 ms | 1.96 ms | 1.73 ms | 2.61 | 2.72 | 3.00 |

처리량 107.75 qps.

**전력** — 평균 총 전류 693.9 mA, 19.4 V 기준 13.46 W. 유휴 대비 증가분 269.9 mA (5.24 W). 효율 8.00 FPS/W.

**재현성** — 최초 측정(기본 반복)에서 GPU Compute 9.266 ms, 재측정에서 9.275 ms로 0.1% 차이다.

---

## 3. 인스턴스 분할 — yolov8n-seg, 640×640

입력 바인딩 `images`, `1x3x640x640` 확인.

**성능** (반복 2000회)

| 항목 | min | max | mean | median | p90 | p95 | p99 |
|---|---|---|---|---|---|---|---|
| Latency | 11.51 ms | 11.81 ms | 11.72 ms | 11.72 ms | 11.76 | 11.77 | 11.80 |
| **GPU Compute** | 10.62 ms | 11.36 ms | **10.72 ms** | 10.72 ms | 10.76 | 10.77 | 10.79 |
| H2D Latency | 0.28 ms | 0.36 ms | 0.29 ms | 0.29 ms | 0.30 | 0.31 | 0.35 |
| D2H Latency | 0.51 ms | 0.72 ms | 0.69 ms | 0.69 ms | 0.70 | 0.70 | 0.72 |

처리량 93.19 qps.

**전력** — 평균 총 전류 696.5 mA, 13.51 W. 유휴 대비 증가분 272.5 mA (5.29 W). 효율 6.90 FPS/W.

---

## 4. 깊이 추정 — Depth Anything V2 ViT-S, 224×224

입력이 동적이므로 `--shapes=pixel_values:1x3x224x224`로 지정하여 빌드했다.

**성능** (반복 2000회)

| 항목 | min | max | mean | median | p90 | p95 | p99 |
|---|---|---|---|---|---|---|---|
| Latency | 13.84 ms | 14.26 ms | 13.99 ms | 13.99 ms | 14.09 | 14.13 | 14.19 |
| **GPU Compute** | 13.75 ms | 14.49 ms | **13.90 ms** | 13.89 ms | 13.93 | 13.96 | 14.05 |
| H2D Latency | 0.04 ms | 0.15 ms | 0.05 ms | 0.04 ms | 0.06 | 0.07 | 0.10 |
| D2H Latency | 0.013 ms | 0.021 ms | 0.018 ms | 0.018 ms | 0.020 | 0.020 | 0.021 |

처리량 71.94 qps.

**전력** — 평균 총 전류 678.5 mA, 13.16 W. 유휴 대비 증가분 254.5 mA (4.94 W). 효율 5.47 FPS/W.

부하 시 채널별 평균 전류 (유휴값 괄호): hwmon4 curr2 38.3 mA (24), curr3 81.8 mA (40), hwmon5 curr2 64.8 mA (16), curr3 493.6 mA (344).

---

## 5. 깊이 추정 — Depth Anything V2 ViT-B, 224×224

**성능** (반복 2000회)

| 항목 | min | max | mean | median | p90 | p95 | p99 |
|---|---|---|---|---|---|---|---|
| Latency | 31.81 ms | 32.08 ms | 31.95 ms | 31.95 ms | 32.05 | 32.07 | 32.08 |
| **GPU Compute** | 31.71 ms | 32.57 ms | **31.87 ms** | 31.86 ms | 31.95 | 31.98 | 32.07 |
| H2D Latency | 0.041 ms | 0.065 ms | 0.047 ms | 0.045 ms | 0.055 | 0.058 | 0.065 |
| D2H Latency | 0.013 ms | 0.021 ms | 0.018 ms | 0.018 ms | 0.020 | 0.021 | 0.021 |

처리량 31.38 qps.

**전력** — 평균 총 전류 733.3 mA, 14.23 W. 유휴 대비 증가분 309.3 mA (6.00 W). 효율 2.21 FPS/W.

---

## 6. 클래스 무관 분할 — FastSam-S, 640×640

입력 바인딩 `image`, `1x3x640x640` 확인. 정적 shape 모델이므로 `--shapes` 미지정.

**성능** (반복 2000회)

| 항목 | min | max | mean | median | p90 | p95 | p99 |
|---|---|---|---|---|---|---|---|
| Latency | 20.26 ms | 20.57 ms | 20.40 ms | 20.39 ms | 20.44 | 20.48 | 20.57 |
| **GPU Compute** | 19.59 ms | 40.35 ms | **19.74 ms** | 19.70 ms | 19.73 | 19.73 | 19.77 |
| H2D Latency | 0.28 ms | 0.48 ms | 0.33 ms | 0.32 ms | 0.38 | 0.39 | 0.46 |
| D2H Latency | 0.25 ms | 0.37 ms | 0.35 ms | 0.35 ms | 0.36 | 0.36 | 0.36 |

처리량 50.66 qps.

**전력** — 평균 총 전류 705.3 mA, 13.68 W. 유휴 대비 증가분 281.3 mA (5.46 W). 효율 3.70 FPS/W.

Raspberry Pi 측정에 사용한 DX-M1 모델은 1024×1024이므로 입력 해상도가 다르다.

---

## 7. 참고 — 해상도 변경 측정

Depth Anything V2 ViT-S를 518×518로 빌드한 결과다.

| 항목 | mean | p99 |
|---|---|---|
| GPU Compute | 83.63 ms | 83.78 ms |
| Latency | 83.92 ms | 84.08 ms |
| H2D | 0.20 ms | 0.23 ms |
| D2H | 0.09 ms | 0.096 ms |

처리량 11.92 qps. 224×224 대비 픽셀 수 5.35배, 연산 시간 6.01배.

---

## 8. 폐기한 측정값

Depth Anything V2 ViT-S를 `--shapes` 지정 없이 빌드한 결과는 무효다.

```
[W] Dynamic dimensions required for input: pixel_values, but no shapes were
    provided. Automatically overriding shape to: 1x3x1x1
[I] Created input binding for pixel_values with dimensions 1x3x1x1
[I] Created output binding for predicted_depth with dimensions 1x0x0
```

이 상태에서 GPU Compute 0.0177 ms, 처리량 20,126 qps로 기록되었으나, 실제로는 1픽셀 입력을 처리한 값이다. `trtexec`도 GPU 미활용 경고와 변동계수 32.9%를 보고했다.

동적 입력 모델은 빌드 후 반드시 입력 바인딩 크기를 확인해야 한다.

---

## 9. 측정하지 않은 항목

- **INT8 측정** — 캘리브레이션 데이터셋이 필요하여 수행하지 않았다
- **전력 모드 명칭** — `/etc/nvpmodel.conf` 조회를 수행하지 않았다
- **클럭 고정** — `jetson_clocks` 미적용
- **정확도** — 측정 범위에 포함하지 않았다
- **전력 레일 식별** — INA3221 채널의 레일 명칭이 노출되지 않아 개별 채널이 GPU/CPU/기타 중 무엇인지 확정하지 못했다. 부하 시 증가폭이 가장 큰 채널은 hwmon5 curr3이다

## 10. 환경 제약

- 디스크 여유 7.4 GB
- `pip` 미설치. ONNX export를 이 장비에서 수행할 수 없어 외부 배포본을 사용했다
- `tegrastats`가 전력 항목을 출력하지 않는다
- sysfs 전력 파일이 root 전용이다
