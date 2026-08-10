# 모델 출처와 조건

두 플랫폼은 서로 다른 경로로 모델을 확보했다. 같은 이름의 모델이라도 export 설정과 그래프 범위가 다를 수 있으므로, 측정값을 인용할 때 이 문서를 함께 참조해야 한다.

---

## 1. Raspberry Pi 5 + DX-M1

DX-AllSuite 배포판의 Model Zoo에 포함된 사전 컴파일 파일을 그대로 사용했다. 별도 변환 과정은 없다.

| 작업 | 파일명 | 입력 |
|---|---|---|
| 객체 검출 | `yolov8-n_640x640.dxnn` | 640×640, UINT8 |
| 인스턴스 분할 | `yolov8-n-seg_640x640.dxnn` | 640×640, UINT8 |
| 깊이 추정 | `depthanythingv2-vits_224x224.dxnn` | 224×224, FLOAT |
| 깊이 추정 | `depthanythingv2-vitb_224x224.dxnn` | 224×224, FLOAT |
| 클래스 무관 분할 | `fastsam-s_1024x1024.dxnn` | 1024×1024, UINT8 |

컴파일 시 사용된 원본 ONNX의 버전과 export 설정은 공개되어 있지 않다.

### 그래프 분할 구조

`.dxnn` 파일은 NPU 태스크와 CPU 태스크로 분할되어 있으며, 모델마다 구조가 다르다.

**검출·분할 계열** — NPU에서 시작하여 CPU 후처리로 끝난다.

```
input → npu_0 → cpu_0 → output
```

**깊이 추정 계열** — CPU 전처리가 앞에 붙는다.

```
input → cpu_0 (patch embedding) → npu_0 → cpu_1 (출력 처리) → output
```

CPU 태스크를 실행하려면 `dxbenchmark`에 `--use-ort` 옵션이 필요하다. 이 옵션 없이 실행하면 다음 오류가 발생하며 NPU 태스크만 측정된다.

```
[DXRT][Error] [buildTaskGraph] Owner task 'cpu_0' not found for tensor '...'
```

이 상태의 측정값은 모델 전체가 아닌 일부만 반영하므로 사용할 수 없다.

---

## 2. Jetson AGX Xavier

공개된 ONNX 파일을 내려받아 TensorRT 엔진으로 빌드했다. 파일마다 출처가 다르다.

| 작업 | 출처 | 파일 | 크기 | 실제 입력 |
|---|---|---|---|---|
| 객체 검출 | HuggingFace `SpotLab/YOLOv8Detection` | `yolov8n.onnx` | 12.2 MB | 640×640 |
| 인스턴스 분할 | HuggingFace `Kalray/yolov8n-seg` | `yolov8n-seg.optimized.onnx` | 13.1 MB | 640×640 |
| 깊이 추정 | HuggingFace `onnx-community/depth-anything-v2-small` | `model.onnx` | 94.5 MB | 동적 |
| 깊이 추정 | HuggingFace `onnx-community/depth-anything-v2-base` | `model.onnx` | 371 MB | 동적 |
| 클래스 무관 분할 | HuggingFace `qualcomm/FastSam-S` | `FastSam-S.onnx` | 45.1 MB | 640×640 |

### 확인된 사항

**객체 검출** — export 시점과 설정이 공개되어 있지 않다.

**인스턴스 분할** — ONNX 메타데이터의 producer가 `onnx.utils.extract_model`, opset 12로 기록되어 있다. 원본 그래프에서 일부 구간을 추출한 파일이며, 어느 범위가 제외되었는지는 확인하지 못했다. 파일명의 `optimized` 표기도 배포자가 자체 하드웨어를 위해 그래프를 수정했을 가능성을 시사한다.

**깊이 추정** — 입력이 동적 차원(`pixel_values`)으로 정의되어 있다. shape을 지정하지 않으면 TensorRT가 자동으로 `1x3x1x1`로 축소하며, 이 상태에서는 유효하지 않은 측정값이 나온다. 실제로 지정 없이 빌드했을 때 GPU 연산 시간이 0.018 ms, 처리량 20,126 qps로 기록되었고 출력 바인딩은 `1x0x0`이었다. 반드시 `--shapes=pixel_values:1x3x224x224` 형태로 명시해야 한다.

**클래스 무관 분할** — 정적 shape 640×640으로 고정되어 있다. `--shapes` 지정 시 다음 오류가 발생한다.

```
Static model does not take explicit shapes since the shape of
inference tensors will be determined by the model itself
```

Raspberry Pi 측정에 사용한 DX-M1 모델은 1024×1024이므로 입력 해상도가 일치하지 않는다.

---

## 3. 조건 일치 여부 정리

| 작업 | 모델 계열 | 입력 해상도 | 그래프 범위 |
|---|---|---|---|
| 객체 검출 | 일치 (yolov8n) | 일치 (640×640) | 미확인 |
| 인스턴스 분할 | 일치 (yolov8n-seg) | 일치 (640×640) | **불일치 가능성** |
| 깊이 추정 ViT-S | 일치 | 일치 (224×224) | 미확인 |
| 깊이 추정 ViT-B | 일치 | 일치 (224×224) | 미확인 |
| 클래스 무관 분할 | 일치 (FastSAM-s) | **불일치** (1024 대 640) | 미확인 |

"미확인"은 두 파일의 그래프를 직접 대조하지 않았다는 뜻이다. 양쪽 모두 원본에서 일부 구간이 제외되었을 수 있으며, 특히 DX-M1 모델은 후처리가 CPU 태스크로 분리되어 있다.

측정값을 인용할 때 이 표를 함께 제시하는 것이 정확하다.
