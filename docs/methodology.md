# 측정 방법론

플랫폼이 다르면 측정 도구도 달라진다. 도구가 다르면 같은 이름의 지표가 다른 것을 재고 있을 수 있다. 이 문서는 어떤 값을 어떻게 얻었는지, 그리고 어떤 값끼리 비교해도 되는지를 정의한다.

---

## 1. 측정 지표

| 지표 | 정의 |
|---|---|
| 추론 지연 | 입력 텐서가 가속기에 올라간 뒤 출력이 나올 때까지의 시간 |
| 전체 지연 | 프레임 획득부터 후처리 완료까지 |
| 처리량 | 단위 시간당 처리 프레임 수 |
| 꼬리 지연 | p90 / p95 / p99 |

실시간 시스템에서는 평균보다 꼬리 지연이 중요하다. 평균이 낮아도 p99가 크면 주기적으로 데드라인을 놓친다.

---

## 2. 플랫폼별 측정 방식

### 2-1. DEEPX DX-M1

DX-RT 배포판에 포함된 C++ 예제를 사용한다. 예제는 카메라 입력을 직접 받으며, 종료 시 구간별 요약을 출력한다.

```bash
./depth_anything_v2_vitb_sync \
  -m ../assets/models/depthanythingv2-vits_224x224.dxnn \
  -c <camera_index> --no-display
```

출력 구간은 `Read`, `Preprocess`, `Inference`, `Postprocess`이며 각각 평균 지연과 처리량을 보고한다.

**제약:** 평균값만 출력한다. 지연 분포를 얻을 수 없다.

### 2-2. NVIDIA Jetson (TensorRT)

ONNX를 TensorRT 엔진으로 빌드한 뒤 `trtexec`로 측정한다.

```bash
/usr/src/tensorrt/bin/trtexec --onnx=model.onnx --saveEngine=model.engine --fp16
/usr/src/tensorrt/bin/trtexec --loadEngine=model.engine --iterations=500 --avgRuns=100
```

출력에는 `GPU Compute Time`, `H2D Latency`, `D2H Latency`, 전체 `Latency`가 포함되며 각각 min/max/mean/median/p90/p95/p99를 보고한다.

**제약:** 합성 데이터로 측정한다. 카메라 획득과 전처리·후처리가 포함되지 않는다.

---

## 3. 비교 성립 조건

두 플랫폼의 숫자를 나란히 놓기 전에 아래를 확인한다.

### 3-1. 대응하는 구간끼리 비교한다

| DX-M1 | Jetson | 대응 여부 |
|---|---|---|
| `Inference` | `GPU Compute Time` | 대응 |
| `Read` + `Preprocess` | 없음 | 비대응 |
| `Postprocess` | 없음 | 비대응 |
| `Overall FPS` | `Throughput` | **비대응** |

`Overall FPS`는 전처리·후처리를 포함하고 `Throughput`은 포함하지 않는다. 이 둘을 비교하면 안 된다.

### 3-2. 입력 해상도를 일치시킨다

공개 ONNX와 벤더 사전 컴파일 모델의 입력 해상도가 다를 수 있다. Depth Anything V2의 경우 공개 배포본은 518×518이 흔한 반면 DX-M1 Model Zoo는 224×224다. 해상도가 다르면 연산량이 달라 비교가 성립하지 않는다.

해결 방법은 둘 중 하나다.

- 동일 해상도로 ONNX를 재export하여 양쪽에서 다시 컴파일
- 해상도 차이를 명시하고, 절대 비교 대신 각 플랫폼 내부의 상대 비교만 수행

### 3-3. 정밀도 조건을 명시한다

DX-M1은 INT8 고정이다. Jetson은 FP32/FP16/INT8을 선택할 수 있다.

두 가지 비교 축이 있으며 **혼용하지 않는다.**

| 축 | 설정 | 의미 |
|---|---|---|
| 동일 조건 비교 | 양쪽 INT8 | 하드웨어 자체의 차이 |
| 최선 성능 비교 | DX-M1 INT8, Jetson FP16 | 실제 배포 시 도달 가능한 성능 |

정확도를 함께 평가하는 경우 최선 성능 비교만으로는 결론을 낼 수 없다. 정밀도 차이가 정확도 차이로 나타나기 때문이다.

### 3-4. 측정 조건을 기록한다

아래 항목이 없는 숫자는 재현할 수 없다.

- 전력 모드 (Jetson: `nvpmodel` 모드 번호 및 이름)
- 클럭 고정 여부 (Jetson: `jetson_clocks` 적용 여부)
- 배치 크기, 스트림 수
- 표본 크기와 측정 시간
- 주변 온도 및 방열 조건
- 워밍업 수행 여부

---

## 4. 표본 크기

측정 시간이 짧으면 신뢰구간이 넓어진다. 서로 다른 표본 크기의 결과를 나란히 제시할 때는 이를 명시한다.

권장: 동일 모델·동일 플랫폼 내에서는 표본 크기를 통일한다. 최소 300프레임 이상, 가능하면 30초 이상 연속 측정.

---

## 5. 전력 측정

### Jetson

INA3221 전력 모니터가 sysfs로 노출된다.

```bash
ls /sys/class/hwmon/
cat /sys/class/hwmon/hwmonN/curr1_input   # mA
cat /sys/class/hwmon/hwmonN/in1_input     # mV
```

레일 이름이 노출되지 않는 경우, 부하를 걸었을 때 값이 크게 변하는 채널을 GPU 레일로 판별한다.

`tegrastats`로 GPU 사용률(`GR3D_FREQ`)과 온도를 동시에 기록하여 스로틀링 여부를 확인한다.

```bash
tegrastats --interval 500 --logfile power.log
```

측정 순서가 중요하다. 로깅을 먼저 시작한 뒤 벤치마크를 실행해야 부하 구간이 기록된다.

### Raspberry Pi

내장 전력 센서가 없으므로 외부 계측이 필요하다. USB 전력계 또는 인라인 전류계를 사용한다.

---

## 6. 기록하지 않는 것

- 측정하지 않은 값을 추정치로 채우지 않는다
- 다른 문헌의 수치를 자체 측정값과 같은 표에 넣지 않는다
- 조건이 다른 측정을 같은 표에 넣을 때는 반드시 조건 열을 함께 표기한다
