# 측정 방법

---

## 1. 측정 지표

| 지표 | 정의 |
|---|---|
| 가속기 연산 시간 | 입력 텐서가 가속기에 전달된 뒤 출력이 산출될 때까지의 시간 |
| 데이터 전송 | 호스트와 가속기 사이의 전송(H2D, D2H) |
| 처리량 | 단위 시간당 처리 횟수 |
| 전력 | 시스템 전체 소비 전력 |

측정은 모두 합성 데이터 또는 반복 실행 기준이며, 카메라 입력을 사용하지 않는다. 카메라를 사용하면 카메라의 프레임 레이트가 상한으로 작용하여 가속기 성능을 측정할 수 없다.

배치 크기는 모든 측정에서 1이다.

---

## 2. Raspberry Pi 5 + DX-M1

### 도구

DXRT에 포함된 `dxbenchmark`를 사용한다.

```bash
dxbenchmark --dir <모델_디렉토리> --loops 300 --warmup 50 -v --use-ort
```

| 옵션 | 의미 |
|---|---|
| `--dir` | 모델 파일이 있는 디렉토리. 파일 단위 지정은 지원하지 않는다 |
| `--loops` | 반복 횟수 |
| `--warmup` | 워밍업 시간 |
| `-v` | NPU 처리 시간과 지연을 출력 |
| `--use-ort` | 그래프 내 CPU 태스크를 ONNX Runtime으로 실행 |

### 주의 사항

**모델은 하나씩 측정한다.** 여러 모델을 한 디렉토리에 넣으면 모든 모델이 로드되지만 프로파일러 결과는 마지막 모델의 것만 출력된다. 모델별로 디렉토리를 분리해야 한다.

**`--use-ort`를 반드시 지정한다.** 그래프에 CPU 태스크가 포함된 모델에서 이 옵션이 없으면 태스크 그래프 구성 오류가 발생하고 NPU 구간만 측정된다.

**`DXRT_DYNAMIC_CPU_THREAD` 환경변수는 기본값(미설정)으로 둔다.** 이 옵션을 켜면 CPU 태스크의 대기 시간이 감소하지만 실제 작업 시간은 변하지 않는다. Depth Anything V2 ViT-S에서 확인한 변화는 다음과 같다.

| 항목 | 미설정 | ON |
|---|---|---|
| CPU 태스크 입력 큐 부하 | 72.22% | 45.20% |
| CPU 태스크 소요 시간 | 47.27 ms | 49.18 ms |
| CPU 디스패치 대기 | 188.69 ms | 63.94 ms |
| NPU 추론 | 17.99 ms | 18.77 ms |

연속 프레임 처리량에는 영향이 있으나 단일 프레임 지연은 개선되지 않는다.

**NPU 코어는 3개 모두 사용한다.** `-n`, `-d` 옵션으로 사용 코어를 제한할 수 있으나 이번 측정은 모두 기본값(`all`)이다.

### 출력 해석

`npu_0` 태스크 표의 항목은 다음과 같다.

| 항목 | 의미 |
|---|---|
| `Inference` | 순수 추론 시간. 플랫폼 간 대조에 사용 |
| `NPU Input Format Handler` | 입력 텐서 형식 변환 |
| `H2D` / `D2H` | 호스트-장치 전송 |
| `NPU Output Format Handler` | 출력 텐서 형식 변환 |
| `NPU Task (total)` | 위 항목의 합계 |
| `Buffer Pool Wait` | 버퍼 대기. 파이프라인 상태에 따라 변동이 크다 |

`cpu_0`, `cpu_1` 태스크는 별도 표로 출력되며 `CPU Task (total)`이 실제 작업 시간이다.

---

## 3. Jetson AGX Xavier

### 엔진 빌드

```bash
/usr/src/tensorrt/bin/trtexec \
  --onnx=<모델>.onnx \
  --saveEngine=<출력>.engine \
  --fp16
```

동적 입력 차원을 가진 모델은 shape을 명시해야 한다.

```bash
  --shapes=<입력_텐서명>:1x3x224x224
```

**빌드 후 입력 크기를 반드시 확인한다.**

```bash
grep -i "input binding" build.log
```

`Created input binding for <이름> with dimensions 1x3x224x224` 형태로 출력되어야 한다. 의도한 해상도와 다르면 해당 측정값은 무효다.

정적 shape 모델에 `--shapes`를 지정하면 빌드가 실패한다. 이 경우 옵션을 제거한다.

### 측정

```bash
/usr/src/tensorrt/bin/trtexec \
  --loadEngine=<엔진>.engine \
  --iterations=<횟수> --avgRuns=100
```

`Performance summary` 항목에서 사용하는 값은 다음과 같다.

| 항목 | 의미 |
|---|---|
| `GPU Compute Time` | 순수 연산 시간. 플랫폼 간 대조에 사용 |
| `Latency` | 전송을 포함한 전체 지연 |
| `H2D Latency` / `D2H Latency` | 호스트-장치 전송 |
| `Throughput` | 처리량 |

각 항목에 min/max/mean/median/p90/p95/p99가 함께 제공된다.

---

## 4. 전력 측정 (Jetson)

INA3221 전력 모니터가 sysfs에 노출되어 있다. 파일 권한이 root 전용이므로 관리자 권한이 필요하다.

```bash
ls -l /sys/class/hwmon/hwmon4/curr1_input
# -r-------- 1 root root
```

레일 명칭은 노출되지 않는다. 채널별 값은 다음과 같으며, `curr1`은 양쪽 모두 0이므로 미사용 채널로 판단했다.

| | curr1 | curr2 | curr3 | in1 |
|---|---|---|---|---|
| hwmon4 | 0 mA | 24 mA | 40 mA | 19,448 mV |
| hwmon5 | 0 mA | 16 mA | 344 mA | 19,456 mV |

유휴 상태 총 전류는 424 mA, 전압 약 19.45 V로 8.23 W다.

### 측정 스크립트

벤치마크를 백그라운드로 실행하고, 그 프로세스가 살아 있는 동안 전류를 주기적으로 기록한다.

```bash
#!/bin/bash
LOG=/root/power_samples.csv
echo "t,h4c2,h4c3,h5c2,h5c3,v" > $LOG
/usr/src/tensorrt/bin/trtexec --loadEngine=$1 --iterations=2000 --avgRuns=100 > /root/bench_out.txt 2>&1 &
BPID=$!
while kill -0 $BPID 2>/dev/null; do
  a=$(cat /sys/class/hwmon/hwmon4/curr2_input)
  b=$(cat /sys/class/hwmon/hwmon4/curr3_input)
  c=$(cat /sys/class/hwmon/hwmon5/curr2_input)
  d=$(cat /sys/class/hwmon/hwmon5/curr3_input)
  v=$(cat /sys/class/hwmon/hwmon4/in1_input)
  echo "$(date +%s.%N),$a,$b,$c,$d,$v" >> $LOG
  sleep 0.2
done
wait $BPID
```

집계는 다음과 같이 수행한다.

```bash
awk -F, 'NR>1{s2+=$2;s3+=$3;s4+=$4;s5+=$5;n++} \
  END{printf "avg total mA = %.1f\n", (s2+s3+s4+s5)/n}' /root/power_samples.csv
```

전력은 총 전류에 입력 전압을 곱해 산출한다. 이는 시스템 전체 소비 전력이며 가속기 단독 소비가 아니다.

### `tegrastats`의 한계

`tegrastats`는 이 환경에서 전력 항목을 출력하지 않는다. RAM, CPU 사용률, GPU 사용률(`GR3D_FREQ`), 온도만 표시된다. 부하 확인과 스로틀링 판정에는 사용할 수 있다.

로깅을 벤치마크보다 먼저 시작해야 부하 구간이 기록된다.

---

## 5. 비교 시 대응 관계

| DX-M1 | Xavier | 대응 |
|---|---|---|
| `Inference` | `GPU Compute Time` | 대응 |
| `H2D` / `D2H` | `H2D Latency` / `D2H Latency` | 대응하나 인터페이스가 다르다 |
| `NPU Output Format Handler` | 해당 없음 | 비대응 |
| `CPU Task (total)` | 해당 없음 | 비대응 |
| `NPU Task (total)` | `Latency` | **비대응** |

`NPU Task (total)`은 형식 변환을 포함하고 `Latency`는 포함하지 않는다. 이 둘을 비교하면 안 된다.

비교 이전에 확인할 조건은 [models.md](models.md)에 정리했다.
