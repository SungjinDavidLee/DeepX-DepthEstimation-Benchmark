# Jetson AGX Xavier

상태: **진행 중** — 깊이 추정 측정은 아직 수행하지 않았다.

---

## 1. 환경

`trtexec` 실행 시 보고된 장치 정보와 시스템 조회 결과다.

| 항목 | 값 |
|---|---|
| 장치 | Jetson AGX Xavier |
| Compute Capability | 7.2 |
| SM 수 | 8 |
| Compute Clock | 1.377 GHz |
| Global Memory | 30,990 MiB |
| Memory Bus | 256-bit (ECC disabled) |
| Memory Clock | 0.675 GHz |
| OS | Ubuntu 20.04.6 LTS |
| 커널 | 5.10.216-tegra |
| JetPack | R35.6.4 |
| CUDA | 11.4 (V11.4.315) |
| TensorRT | 8.5.2 |
| Python | 3.8.10 |
| 디스크 여유 | 7.4 GB |
| 전력 모드 | `pmode:0007` (모드 명칭 미확인) |

> **주의:** 이 장비는 Jetson AGX **Xavier**다. AGX Orin 또는 AGX Thor와 혼동하지 않도록 한다. 세대와 아키텍처가 다르므로 비교 결과를 인용할 때 장비명을 정확히 표기해야 한다.

## 2. 툴체인 검증

깊이 추정 모델 측정에 앞서, TensorRT 빌드·실행 경로가 정상 동작하는지 확인했다. 검증용으로 객체 검출 모델을 사용했으며 **이 결과는 깊이 추정 벤치마크의 일부가 아니다.**

```bash
/usr/src/tensorrt/bin/trtexec --onnx=yolov8n.onnx --saveEngine=yolov8n_fp16.engine --fp16
```

| 항목 | 값 |
|---|---|
| 모델 | yolov8n (640×640, 공개 ONNX) |
| 정밀도 | FP16 |
| Throughput | 107.59 qps |
| GPU Compute Time (mean) | 9.27 ms |
| GPU Compute Time (p99) | 9.32 ms |
| 전체 Latency (mean) | 9.79 ms |
| 전체 Latency (p99) | 9.90 ms |
| H2D Latency (mean) | 0.31 ms |
| D2H Latency (mean) | 0.22 ms |

p99가 평균의 1.01배로 지연 분포가 안정적이다. 호스트-장치 전송(H2D + D2H = 0.53 ms)이 전체의 약 5%를 차지한다.

빌드 및 실행 경로가 정상임을 확인했다.

## 3. 진행 상황

- [x] TensorRT 툴체인 동작 확인
- [x] 전력 센서 경로 확인 — INA3221 두 채널(`/sys/class/hwmon/hwmon4`, `hwmon5`)에 `curr1~4_input`(mA), `in1_input`(mV) 노출. 레일 명칭은 미노출이므로 부하 시 변화량으로 식별 필요
- [ ] Depth Anything V2 ONNX 입력 해상도 확인
- [ ] 엔진 빌드 및 측정
- [ ] 전력 측정
- [ ] 전력 모드 명칭 확인 (`/etc/nvpmodel.conf`)

## 4. 확인된 제약

- **디스크 여유가 7.4 GB다.** 엔진 파일 자체는 크지 않으나 빌드 중 임시 공간을 소모하므로 대형 모델 처리 시 주의가 필요하다.
- **`pip`가 설치되어 있지 않다.** ONNX export를 이 장비에서 수행할 수 없다. 외부에서 변환한 ONNX를 반입하거나 사전 배포된 ONNX를 사용해야 한다.
- **`tegrastats`가 전력 항목을 출력하지 않는다.** RAM, CPU 사용률, 온도만 표시된다. 전력은 sysfs에서 직접 읽어야 한다.
- **전력 모드 조회에 관리자 권한이 필요하다.** `/var/lib/nvpmodel/status`로 모드 번호는 확인 가능하나 명칭 확인은 `/etc/nvpmodel.conf` 조회가 필요하다.

## 5. 다음 측정 시 유의

- DX-M1은 224×224 입력을 사용한다. 공개 Depth Anything V2 ONNX는 518×518인 경우가 많으므로, 비교 전에 입력 해상도를 확인하고 필요 시 통일해야 한다.
- `trtexec`는 합성 데이터로 측정한다. DX-M1 측정에 포함된 전처리·후처리가 여기에는 포함되지 않는다. 비교 시 `Inference` 대 `GPU Compute Time`만 대응시킨다.
- 전력 로깅은 벤치마크 실행 **전에** 시작해야 부하 구간이 기록된다.
