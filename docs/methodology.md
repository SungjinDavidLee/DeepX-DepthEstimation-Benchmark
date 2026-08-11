# 측정 방법

---

## 1. 측정 원칙

| 항목 | 값 |
|---|---|
| 입력 | 합성 데이터 또는 반복 실행 |
| 배치 크기 | 1 |
| 스트림 수 | 1 |

카메라 입력을 사용하지 않는다. 카메라를 사용하면 프레임 레이트가 상한으로 작용하여 가속기 성능을 측정할 수 없다.

측정 지표는 다음과 같다.

| 지표 | 정의 |
|---|---|
| 가속기 연산 시간 | 입력 텐서가 가속기에 전달된 뒤 출력이 산출될 때까지 |
| 데이터 전송 | 호스트-가속기 간 전송 (H2D, D2H) |
| 처리량 | 단위 시간당 처리 횟수 |
| 전력 | 시스템 전체 소비 전력 |

---

## 2. Raspberry Pi 5 + DX-M1

```bash
dxbenchmark --dir <모델_디렉토리> --loops 300 --warmup 50 -v --use-ort
```

| 옵션 | 의미 |
|---|---|
| `--dir` | 모델 디렉토리. 파일 단위 지정은 지원하지 않는다 |
| `--loops` | 반복 횟수 |
| `--warmup` | 워밍업 시간 |
| `-v` | NPU 처리 시간과 지연 출력 |
| `--use-ort` | 그래프 내 CPU 태스크를 ONNX Runtime으로 실행 |

### 주의 사항

**모델은 하나씩 측정한다.** 여러 모델을 한 디렉토리에 넣으면 모든 모델이 로드되지만 프로파일러 결과는 마지막 모델의 것만 출력된다.

**`--use-ort`를 반드시 지정한다.** 그래프에 CPU 태스크가 포함된 모델에서 이 옵션이 없으면 태스크 그래프 구성 오류가 발생하고 NPU 구간만 측정된다.

**`DXRT_DYNAMIC_CPU_THREAD`는 기본값(미설정)으로 둔다.** 이 옵션을 켜면 CPU 태스크 대기 시간이 줄지만 실제 작업 시간은 변하지 않는다. Depth Anything V2 ViT-S 기준 변화는 다음과 같다.

| 항목 | 미설정 | ON |
|---|---|---|
| cpu_1 입력 큐 부하 | 72.22% | 45.20% |
| cpu_1 소요 시간 | 47.27 ms | 49.18 ms |
| cpu_1 디스패치 대기 | 188.69 ms | 63.94 ms |
| NPU 추론 | 17.99 ms | 18.77 ms |

연속 프레임 처리량에는 영향이 있으나 단일 프레임 지연은 개선되지 않는다.

**NPU 코어는 3개 모두 사용한다.** `-n`, `-d` 옵션으로 제한할 수 있으나 이번 측정은 기본값(`all`)이다.

### 출력 해석

`npu_0` 태스크 표의 항목은 다음과 같다.

| 항목 | 의미 |
|---|---|
| `Inference` | 순수 추론 시간. 플랫폼 간 대조에 사용 |
| `NPU Input/Output Format Handler` | 텐서 형식 변환 |
| `H2D` / `D2H` | 호스트-장치 전송 |
| `NPU Task (total)` | 위 항목의 합계 |
| `Buffer Pool Wait` | 버퍼 대기. 파이프라인 상태에 따라 변동이 크다 |

---

## 3. Jetson (Xavier / Thor 공통)

### 엔진 빌드

```bash
trtexec --onnx=<모델>.onnx --saveEngine=<출력>.engine --fp16
```

INT8은 폴백 정밀도를 함께 지정한다.

```bash
trtexec --onnx=<모델>.onnx --saveEngine=<출력>.engine --int8 --fp16
```

동적 입력 차원을 가진 모델은 shape을 명시한다.

```bash
  --shapes=pixel_values:1x3x224x224
```

**빌드 후 입력 크기를 반드시 확인한다.**

```bash
grep -i "input binding" build.log
```

의도한 해상도와 다르면 해당 측정값은 무효다. 정적 shape 모델에 `--shapes`를 지정하면 빌드가 실패하므로 옵션을 제거한다.

### 측정

```bash
trtexec --loadEngine=<엔진>.engine --iterations=<횟수> --avgRuns=100
```

`Performance summary`에서 사용하는 값은 다음과 같다.

| 항목 | 의미 |
|---|---|
| `GPU Compute Time` | 순수 연산 시간. 플랫폼 간 대조에 사용 |
| `Latency` | 전송을 포함한 전체 지연 |
| `H2D Latency` / `D2H Latency` | 호스트-장치 전송 |
| `Throughput` | 처리량 |

각 항목에 min/max/mean/median/p90/p95/p99가 제공된다.

### `trtexec` 경로

| 플랫폼 | 경로 |
|---|---|
| Xavier | `/usr/src/tensorrt/bin/trtexec` |
| Thor | `/usr/bin/trtexec` (PATH에 포함) |

---

## 4. 전력 측정

### Xavier — INA3221

레일 명칭이 노출되지 않는다. 채널별 유휴값은 다음과 같으며 `curr1`은 양쪽 모두 0이므로 미사용 채널로 판단했다.

| | curr1 | curr2 | curr3 | in1 |
|---|---|---|---|---|
| hwmon4 | 0 mA | 24 mA | 40 mA | 19,448 mV |
| hwmon5 | 0 mA | 16 mA | 344 mA | 19,456 mV |

총 전류 424 mA, 전압 약 19.45 V로 유휴 8.23 W다.

sysfs 파일이 root 전용이므로 관리자 권한이 필요하다.

```bash
ls -l /sys/class/hwmon/hwmon4/curr1_input
# -r-------- 1 root root
```

전력은 총 전류에 입력 전압을 곱해 산출한다.

### Thor — INA238

`power1_input`을 직접 제공하므로 계산이 필요 없다.

```bash
cat /sys/class/hwmon/hwmon5/power1_input   # uW
```

`ina3221`도 함께 존재하나 `ina238`의 값을 사용했다.

### 측정 스크립트

벤치마크를 백그라운드로 실행하고 프로세스가 살아 있는 동안 전력을 주기적으로 기록한다.

**Thor용**

```bash
#!/bin/bash
cd <작업_디렉토리>
TX=$(which trtexec)
OUT=<결과_파일>
PW=/sys/class/hwmon/hwmon5/power1_input
echo "pmode: $(cat /var/lib/nvpmodel/status)" > $OUT
echo "idle power: $(cat $PW) uW" >> $OUT
for E in <엔진_목록>; do
  [ -f "$E.engine" ] || continue
  echo "=== $E ===" >> $OUT
  $TX --loadEngine=$E.engine --iterations=5000 --avgRuns=100 > /tmp/t.log 2>&1 &
  BP=$!
  S=0; N=0
  while kill -0 $BP 2>/dev/null; do
    S=$((S+$(cat $PW))); N=$((N+1)); sleep 0.2
  done
  wait $BP
  grep -E "Throughput:|GPU Compute Time:|H2D Latency:|D2H Latency:" /tmp/t.log >> $OUT
  [ $N -gt 0 ] && echo "avg power: $((S/N)) uW (samples $N)" >> $OUT
done
```

**Xavier용** — 전력 부분을 전류 합산으로 대체한다.

```bash
    A=$(cat /sys/class/hwmon/hwmon4/curr2_input)
    B=$(cat /sys/class/hwmon/hwmon4/curr3_input)
    C=$(cat /sys/class/hwmon/hwmon5/curr2_input)
    D=$(cat /sys/class/hwmon/hwmon5/curr3_input)
    S=$((S+A+B+C+D)); N=$((N+1))
```

**로깅은 벤치마크보다 먼저 시작해야 부하 구간이 기록된다.**

### `tegrastats`

Xavier에서는 전력 항목을 출력하지 않는다. RAM, CPU 사용률, GPU 사용률(`GR3D_FREQ`), 온도만 표시된다. 부하 확인과 스로틀링 판정에는 사용할 수 있다.

### Raspberry Pi

내장 전력 센서가 없다. 외부 계측이 필요하며 이번 측정에서는 수행하지 못했다.

---

## 5. 전력 모드

측정 시점의 설정이다.

| 플랫폼 | 모드 | 확인 방법 |
|---|---|---|
| Xavier | `pmode 7 = MODE_15W_DESKTOP` | `cat /var/lib/nvpmodel/status`, `grep POWER_MODEL /etc/nvpmodel.conf` |
| Thor | `pmode 1 = 120W` | 동일 |
| DX-M1 | 고정 (모드 없음) | — |

Xavier의 선택 가능 모드는 MAXN(0), 10W(1), 15W(2), 30W 계열(3~6), 15W_DESKTOP(7)이다.
Thor는 MAXN(0), 120W(1), 90W(2), 70W(3)이다.

---

## 6. 비교 시 대응 관계

| DX-M1 | Jetson | 대응 |
|---|---|---|
| `Inference` | `GPU Compute Time` | 대응 |
| `H2D` / `D2H` | `H2D Latency` / `D2H Latency` | 대응하나 인터페이스가 다르다 |
| `NPU Output Format Handler` | 해당 없음 | 비대응 |
| `CPU Task (total)` | 해당 없음 | 비대응 |
| `NPU Task (total)` | `Latency` | **비대응** |

`NPU Task (total)`은 형식 변환을 포함하고 `Latency`는 포함하지 않는다. 이 둘을 비교하면 안 된다.

---

## 7. 반복 횟수

| 플랫폼 | 반복 |
|---|---|
| DX-M1 | 300 (FastSAM 200), 워밍업 50 (FastSAM 30) |
| Xavier | 2000 |
| Thor | 5000 |

통일하지 못했다. Thor는 연산 시간이 짧아 동일 반복 횟수에서 측정 구간이 지나치게 짧아지므로 늘렸다. 이 차이는 전력 표본 수에 영향을 준다.
