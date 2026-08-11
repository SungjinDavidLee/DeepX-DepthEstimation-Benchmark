# Jetson AGX Xavier — 원본 측정값

측정일: 2026-08-10 (FP16), 2026-08-11 (INT8)
도구: `trtexec` (TensorRT 8.5.2)
조건: 배치 1, 스트림 1, 반복 2000회, `pmode 7 = MODE_15W_DESKTOP`

---

## 1. 환경

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

| 항목 | 값 |
|---|---|
| OS | Ubuntu 20.04.6 LTS |
| 커널 | 5.10.216-tegra |
| JetPack | R35 revision 6.4 |
| CUDA | 11.4 (V11.4.315) |
| Python | 3.8.10 |
| 디스크 여유 | 7.4 GB |
| 전력 모드 | pmode 7 = `MODE_15W_DESKTOP` |

전력 모드 선택지는 MAXN(0), 10W(1), 15W(2), 30W_ALL(3), 30W_6CORE(4), 30W_4CORE(5), 30W_2CORE(6), 15W_DESKTOP(7)이다.

---

## 2. 전력 측정 기준

INA3221 두 채널이 sysfs에 노출된다. 레일 명칭은 제공되지 않는다.

| | curr1 | curr2 | curr3 | in1 |
|---|---|---|---|---|
| hwmon4 | 0 mA | 24 mA | 40 mA | 19,448 mV |
| hwmon5 | 0 mA | 16 mA | 344 mA | 19,456 mV |

유휴 총 전류 424 mA, 전압 약 19.45 V, 유휴 전력 8.23 W.

부하 시 증가폭이 가장 큰 채널은 hwmon5 curr3이나, 레일 명칭이 없어 GPU 레일임을 확정하지 못했다.

`tegrastats`는 이 환경에서 전력 항목을 출력하지 않는다.

---

## 3. FP16

| 모델 | 입력 | GPU Compute mean | p90 | p95 | p99 | Throughput | 전류 | 전력 | FPS/W |
|---|---|---|---|---|---|---|---|---|---|
| yolov8n | 640² | 9.28 ms | 9.30 | 9.31 | 9.32 | 107.75 qps | 693.9 mA | 13.46 W | 8.00 |
| yolov8n-seg | 640² | 10.72 ms | 10.76 | 10.77 | 10.79 | 93.19 qps | 696.5 mA | 13.51 W | 6.90 |
| FastSam-S | 640² | 19.74 ms | 19.73 | 19.73 | 19.77 | 50.66 qps | 705.3 mA | 13.68 W | 3.70 |
| DAv2 ViT-S | 224² | 13.90 ms | 13.93 | 13.96 | 14.05 | 71.94 qps | 678.5 mA | 13.16 W | 5.47 |
| DAv2 ViT-B | 224² | 31.87 ms | 31.95 | 31.98 | 32.07 | 31.38 qps | 733.3 mA | 14.23 W | 2.21 |

전송 지연.

| 모델 | H2D mean | D2H mean |
|---|---|---|
| yolov8n | 0.31 ms | 0.22 ms |
| yolov8n-seg | 0.29 ms | 0.69 ms |
| FastSam-S | 0.33 ms | 0.35 ms |
| DAv2 ViT-S | 0.050 ms | 0.018 ms |
| DAv2 ViT-B | 0.047 ms | 0.018 ms |

ViT-S 부하 시 채널별 평균 전류(유휴값 괄호): hwmon4 curr2 38.3 mA (24), curr3 81.8 mA (40), hwmon5 curr2 64.8 mA (16), curr3 493.6 mA (344).

---

## 4. INT8

캘리브레이션 미수행. `--int8 --fp16`으로 빌드했다.

| 모델 | 입력 | GPU Compute mean | p90 | p95 | p99 | Throughput | 전류 | 전력 | FPS/W |
|---|---|---|---|---|---|---|---|---|---|
| yolov8n | 640² | 6.82 ms | 6.83 | 6.84 | 7.26 | 137.35 qps | 645 mA | 12.51 W | 10.98 |
| yolov8n-seg | 640² | 7.52 ms | 7.55 | 7.55 | 7.56 | 119.03 qps | 669 mA | 12.98 W | 9.17 |
| FastSam-S | 640² | 12.55 ms | 12.58 | 12.58 | 12.60 | 79.68 qps | 675 mA | 13.10 W | 6.08 |
| DAv2 ViT-S | 224² | 15.29 ms | 15.34 | 15.35 | 15.38 | 65.08 qps | 672 mA | 13.04 W | 4.99 |
| DAv2 ViT-B | 224² | 29.38 ms | 29.44 | 29.46 | 29.49 | 33.95 qps | 705 mA | 13.68 W | 2.48 |

전송 지연.

| 모델 | H2D mean | D2H mean |
|---|---|---|
| yolov8n | 0.265 ms | 0.180 ms |
| yolov8n-seg | 0.264 ms | 0.602 ms |
| FastSam-S | 0.292 ms | 0.359 ms |
| DAv2 ViT-S | 0.047 ms | 0.017 ms |
| DAv2 ViT-B | 0.047 ms | 0.016 ms |

---

## 5. FP16 대 INT8

| 모델 | FP16 | INT8 | 변화 |
|---|---|---|---|
| yolov8n | 9.28 ms | 6.82 ms | 26% 감소 |
| yolov8n-seg | 10.72 ms | 7.52 ms | 30% 감소 |
| FastSam-S | 19.74 ms | 12.55 ms | 36% 감소 |
| DAv2 ViT-S | 13.90 ms | 15.29 ms | 10% 증가 |
| DAv2 ViT-B | 31.87 ms | 29.38 ms | 8% 감소 |

Convolution 위주 모델에서 INT8 이득이 크다. ViT-S는 오히려 느려졌다.

---

## 6. 재현성

yolov8n FP16을 두 차례 측정했다. GPU Compute 9.266 ms와 9.275 ms로 0.1% 차이다.

---

## 7. 빌드

전체 엔진 빌드 소요 시간은 INT8 기준 약 2시간 30분이다(11:55 ~ 14:09). FP16은 모델당 수 분이다.

입력 바인딩은 전 모델에서 의도한 해상도로 확인되었다.

```
yolov8n       1x3x640x640
yolov8n-seg   1x3x640x640
FastSam-S     1x3x640x640
DAv2 ViT-S    1x3x224x224
DAv2 ViT-B    1x3x224x224
```

---

## 8. 폐기한 측정값

Depth Anything V2 ViT-S를 `--shapes` 지정 없이 빌드한 결과는 무효다.

```
[W] Dynamic dimensions required for input: pixel_values, but no shapes were
    provided. Automatically overriding shape to: 1x3x1x1
[I] Created input binding for pixel_values with dimensions 1x3x1x1
[I] Created output binding for predicted_depth with dimensions 1x0x0
```

이 상태에서 GPU Compute 0.0177 ms, 처리량 20,126 qps로 기록되었으나 실제로는 1픽셀 입력을 처리한 값이다. `trtexec`도 GPU 미활용 경고와 변동계수 32.9%를 보고했다.

동적 입력 모델은 빌드 후 반드시 입력 바인딩 크기를 확인해야 한다.

---

## 9. 참고 — 해상도 변경

Depth Anything V2 ViT-S를 518×518로 빌드한 FP16 결과다.

| 항목 | mean | p99 |
|---|---|---|
| GPU Compute | 83.63 ms | 83.78 ms |
| Latency | 83.92 ms | 84.08 ms |

처리량 11.92 qps. 224×224 대비 픽셀 수 5.35배, 연산 시간 6.01배다.

---

## 10. 환경 제약

- 디스크 여유 7.4 GB
- `pip` 미설치. ONNX export를 이 장비에서 수행할 수 없어 외부 배포본을 사용했다
- `tegrastats`가 전력 항목을 출력하지 않는다
- sysfs 전력 파일이 root 전용이다

---

## 11. 측정하지 않은 항목

- 다른 전력 모드(MAXN 등)에서의 측정
- INT8 캘리브레이션 적용
- 전력 레일 식별
- 정확도
- 열 조건 통제
- 클럭 고정(`jetson_clocks`) 적용
