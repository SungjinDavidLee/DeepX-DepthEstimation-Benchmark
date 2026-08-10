# DeepX Depth Estimation Benchmark

온디바이스 가속기에서 단안 깊이 추정(monocular depth estimation) 모델의 추론 지연과 처리량을 측정하고, 플랫폼 간 비교 가능한 형태로 기록하는 저장소다.

기준 플랫폼은 Raspberry Pi 5 + DEEPX DX-M1이며, NVIDIA Jetson 계열을 비교 대상으로 둔다.

---

## 측정 대상

| 모델 | 계열 | 비고 |
|---|---|---|
| Depth Anything V2 (ViT-S) | 단안 깊이 추정 | 경량 |
| Depth Anything V2 (ViT-B) | 단안 깊이 추정 | 기준 |

카메라로는 Intel RealSense D405를 사용한다. D405는 스테레오 방식으로 깊이를 직접 출력하므로, 추후 단안 추정 결과의 정확도 대조군으로 사용할 수 있다.

## 플랫폼

| 플랫폼 | 가속기 | 실행 스택 | 상태 |
|---|---|---|---|
| Raspberry Pi 5 | DEEPX DX-M1 | DX-RT (INT8) | 측정 완료 |
| Jetson AGX Xavier | Volta GPU (SM 8) | TensorRT 8.5.2 (FP16) | 진행 중 |
| Jetson AGX Thor | — | TensorRT | 예정 |

---

## 현재 결과

### Raspberry Pi 5 + DX-M1

측정 조건: 카메라 실시간 입력, sync 모드, 배치 1, 렌더링 비활성화.

| 모델 | 입력 | 추론 지연 | 전체 FPS |
|---|---|---|---|
| depthanythingv2-vits | 224×224 | 76.63 ms | 12.4 |
| depthanythingv2-vitb | 224×224 | 162.37 ms | 6.0 |

구간별 분해와 측정 조건은 [results/dx-m1-raspberry-pi-5.md](results/dx-m1-raspberry-pi-5.md) 참조.

### Jetson AGX Xavier

깊이 추정 측정은 아직 수행하지 않았다. 환경 확인 및 툴체인 검증 내역은 [results/agx-xavier.md](results/agx-xavier.md)에 기록되어 있다.

---

## 플랫폼 간 비교 시 주의

현 시점의 두 측정은 **직접 비교할 수 없다.** 아래 세 가지가 다르기 때문이다.

1. **측정 도구가 다르다.** DX-M1은 카메라 입력을 받는 응용 예제로 측정했고 전처리·후처리가 포함된다. Jetson은 `trtexec`가 합성 데이터로 순수 추론만 측정한다.
2. **연산 정밀도가 다르다.** DX-M1은 INT8 고정, Jetson은 FP16이 기본 최선 설정이다.
3. **모델 출처가 다르다.** DX-M1은 벤더가 사전 컴파일한 `.dxnn`을, Jetson은 공개 ONNX를 자체 빌드한 엔진을 사용한다. 입력 해상도도 일치하지 않을 수 있다.

비교를 성립시키려면 최소한 아래를 맞춰야 한다.

- 추론 구간만 분리하여 대조 (DX-M1의 `Inference` 항목 대 Jetson의 `GPU Compute Time`)
- 동일 입력 해상도
- 정밀도 조건 명시 (동일 INT8 비교 또는 각 플랫폼 최선 설정 비교 중 택일, 혼용 금지)

자세한 규칙은 [docs/methodology.md](docs/methodology.md)에 정리했다.

---

## 저장소 구성

```
docs/
  methodology.md              측정 방법과 비교 성립 조건
  setup-dx-m1.md              Pi 5 + DX-M1 + RealSense 환경 구축
results/
  dx-m1-raspberry-pi-5.md     DX-M1 측정 결과
  agx-xavier.md               Xavier 환경 및 진행 상황
```

## 진행 예정

- [ ] Xavier에서 Depth Anything V2 엔진 빌드 및 측정
- [ ] 입력 해상도 통일 (224×224 기준)
- [ ] 전력 측정 추가 (Jetson: INA3221 sysfs, Pi: 외부 계측)
- [ ] 정확도 평가 — 단안 추정 결과와 D405 스테레오 깊이 대조
- [ ] Jetson AGX Thor 측정
