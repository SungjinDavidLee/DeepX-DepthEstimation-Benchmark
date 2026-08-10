# Raspberry Pi 5 + DX-M1 + RealSense D405 환경 구축

Debian 13(trixie)에서 RealSense SDK를 빌드하고 DX-M1 추론 파이프라인에 카메라를 연결하기까지의 절차다. Debian 13은 RealSense SDK가 공식 검증한 환경이 아니며, 설치 과정에서 세 개의 장애물을 만났다. 그 해결 과정도 함께 기록한다.

---

## 1. 환경

### 하드웨어

| 항목 | 사양 |
|---|---|
| 호스트 | Raspberry Pi 5 (8GB) |
| NPU | DEEPX DX-M1 (M.2 2280, PCIe Gen3 x1) |
| 카메라 | Intel RealSense D405 (Firmware 5.15.1.55) |
| 연결 | 카메라 USB 3.2 직결 |

### 소프트웨어

| 항목 | 버전 |
|---|---|
| OS | Debian GNU/Linux 13 (trixie), aarch64 |
| 커널 | 6.18.39+rpt-rpi-2712 |
| Python | 3.13.5 (시스템 기본) |
| librealsense | 소스 빌드 (master) |
| DX-RT | DX-AllSuite 배포판 |

D405는 RGB 센서를 별도로 갖지 않고 스테레오 적외선 모듈에서 컬러 스트림을 생성한다. 이 때문에 V4L2 노드 구성이 D435 계열과 다르며, 아래 3-3에서 문제가 된다.

---

## 2. 목적

두 가지를 확인하는 것이 목표였다.

1. 카메라 실시간 입력이 DX-M1까지 도달하는 파이프라인이 성립하는가
2. 성립한다면 각 구간이 얼마의 지연을 차지하는가

정확도(depth 오차, mAP)는 이번 범위가 아니다. 지연과 처리량만 측정했다.

---

## 3. librealsense 설치

### 3-1. 배포판 패키지 없음

Intel은 Ubuntu용 apt 저장소만 제공한다. Debian/Raspberry Pi OS 저장소에는 해당 패키지가 없다.

```bash
sudo apt install librealsense2-utils librealsense2-dev
# Error: Unable to locate package librealsense2-utils
```

소스 빌드로 진행했다.

```bash
sudo apt install -y git cmake build-essential libssl-dev libusb-1.0-0-dev libudev-dev pkg-config

git clone --depth=1 https://github.com/IntelRealSense/librealsense.git
cd librealsense && mkdir build && cd build
```

### 3-2. OpenGL 의존성으로 인한 빌드 실패

첫 시도에서 라이브러리 본체는 빌드되었으나(88%) 예제 프로그램 링크 단계에서 중단되었다.

```
CMake Error at examples/hello-realsense/CMakeLists.txt:9 (target_link_libraries):
  Target "rs-hello-realsense" links to: OpenGL::GL
  but the target was not found.
```

`-DBUILD_GRAPHICAL_EXAMPLES=FALSE`를 지정했음에도 일부 예제가 OpenGL 타깃을 참조한다. 헤드리스 환경에서는 예제 자체가 불필요하므로 전체를 비활성화했다.

```bash
cmake .. \
  -DFORCE_RSUSB_BACKEND=ON \
  -DBUILD_EXAMPLES=FALSE \
  -DBUILD_GRAPHICAL_EXAMPLES=FALSE \
  -DBUILD_PYTHON_BINDINGS=FALSE \
  -DCMAKE_BUILD_TYPE=Release

make -j3
sudo make install
sudo ldconfig
```

각 플래그의 이유:

- `FORCE_RSUSB_BACKEND=ON` — libuvc 백엔드를 사용하여 커널 모듈 패치를 회피한다.
- `BUILD_EXAMPLES=FALSE` — 위 OpenGL 링크 오류를 우회한다.
- `BUILD_PYTHON_BINDINGS=FALSE` — 시스템 Python이 3.13이며 `pyrealsense2`의 해당 버전 지원이 불확실하다. 파이썬 연동은 분리하여 별도로 다룬다.
- `-j3` — 8GB 환경에서 빌드 중 OOM을 피하기 위한 보수적 설정.

### 3-3. USB 접근 권한

빌드 후 `rs-enumerate-devices`가 일반 사용자 권한에서 실패했다.

```
ERROR (handle-libusb.h:53) failed to open usb interface: 0, error: RS2_USB_STATUS_ACCESS
ERROR (uvc-sensor.cpp:431) acquire_power failed: failed to set power state
No device detected. Is it plugged in?
```

`sudo`로는 정상 동작했으므로 권한 문제로 판단하고 udev 규칙을 설치했다.

```bash
sudo cp config/99-realsense-libusb.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

udev 규칙은 장치가 연결되는 시점에 적용된다. 이미 연결된 장치에는 소급되지 않으므로 **USB 케이블을 물리적으로 재연결해야 한다.** 적용 여부는 장치 파일 소유권으로 확인할 수 있다.

```bash
ls -l /dev/bus/usb/002/
# 적용 전: crw-rw-r--  1 root root
# 적용 후: crw-rw-rw-  1 root plugdev
```

---

## 4. 카메라 인덱스 식별

D405는 6개의 V4L2 노드(`/dev/video0` ~ `/dev/video5`)로 열거되지만, DX-RT 예제가 사용하는 OpenCV 캡처가 열 수 있는 노드는 하나뿐이다.

```bash
v4l2-ctl --list-devices
# Intel(R) RealSense(TM) Depth Ca (usb-xhci-hcd.0-1):
#     /dev/video0 ~ /dev/video5, /dev/media3
```

`v4l2-ctl --list-formats`는 이 노드들에 대해 빈 결과를 반환했다. RealSense 노드가 표준 V4L2 포맷 조회에 응답하지 않는 경우가 있다. 따라서 순차 시도로 판별했다.

```bash
for n in 0 1 2 3 4 5; do
  echo "=== camera $n ==="
  timeout 8 ./depth_anything_v2_vitb_sync \
    -m ../assets/models/depthanythingv2-vitb_224x224.dxnn \
    -c $n --no-display 2>&1 | tail -3
done
```

결과:

| 인덱스 | 결과 |
|---|---|
| 0, 1, 3, 5 | `can't open camera by index` |
| 2 | 열리지만 채널 수 불일치로 연산 오류 (depth 또는 IR 노드로 추정) |
| **4** | **정상 동작 (timeout에 의해 종료)** |

`timeout`에 의한 종료는 실패가 아니라 정상 동작 중이었다는 신호다. 이 방법은 `--list-formats`가 응답하지 않는 상황에서 유효했다.

---

## 5. 실행

DX-AllSuite에 사전 빌드된 C++ 예제를 사용했다. 모델 컴파일은 필요하지 않았으며, 배포판의 Model Zoo에 해당 모델이 이미 `.dxnn` 형태로 포함되어 있다.

```bash
cd dx_app/bin

# 깊이 추정
./depth_anything_v2_vitb_sync \
  -m ../assets/models/depthanythingv2-vitb_224x224.dxnn \
  -c 4 --no-display

# 인스턴스 분할
./yolov8n_seg_sync \
  -m ../assets/models/yolov8-n-seg_640x640.dxnn \
  -c 4 --no-display
```

SSH 환경이므로 `--no-display`로 렌더링을 비활성화했다. 실행 파일은 기본적으로 무한 반복하며, `Ctrl+C` 또는 `timeout`으로 종료할 때 구간별 요약을 출력한다.

---

## 6. 측정 결과

측정 조건: 카메라 실시간 입력, `--no-display`, sync 모드, 배치 1.

### 6-1. 종합

| 모델 | 입력 해상도 | Inference | Overall FPS | 표본 |
|---|---|---|---|---|
| depthanythingv2-vitb | 224×224 | 162.37 ms | 6.0 | 3,483 프레임 / 579.4 s |
| depthanythingv2-vits | 224×224 | 76.63 ms | 12.4 | 353 프레임 / 28.5 s |
| yolov8-n-seg | 640×640 | 63.45 ms | 15.2 | 440 프레임 / 29.0 s |

### 6-2. 구간 분해

**depthanythingv2-vitb_224x224**

| 구간 | 평균 지연 | 처리량 |
|---|---|---|
| Read | 0.32 ms | 3133.3 FPS |
| Preprocess | 0.90 ms | 1110.1 FPS |
| Inference | 162.37 ms | 6.2 FPS |
| Postprocess | 0.09 ms | 10935.3 FPS |

**depthanythingv2-vits_224x224**

| 구간 | 평균 지연 | 처리량 |
|---|---|---|
| Read | 0.38 ms | 2654.0 FPS |
| Preprocess | 0.93 ms | 1077.8 FPS |
| Inference | 76.63 ms | 13.1 FPS |
| Postprocess | 0.09 ms | 11010.1 FPS |

**yolov8-n-seg_640x640**

| 구간 | 평균 지연 | 처리량 |
|---|---|---|
| Read | 0.32 ms | 3097.9 FPS |
| Preprocess | 1.02 ms | 976.2 FPS |
| Inference | 63.45 ms | 15.8 FPS |
| Postprocess | 0.68 ms | 1467.8 FPS |

---

## 7. 관찰

### 7-1. 병목은 전적으로 NPU 추론이다

세 경우 모두 Read + Preprocess + Postprocess의 합이 2 ms 미만이며, 전체 지연의 99% 이상을 추론이 차지한다. 호스트 CPU는 대부분의 시간을 대기에 사용하고 있다.

이는 sync 모드의 특성이다. 추론이 완료될 때까지 다음 프레임 처리가 시작되지 않으므로, async 모드로 전환하면 처리량 개선의 여지가 있다. 다만 이번 측정에는 포함하지 않았다.

### 7-2. 동일 입력에서 모델 크기가 2.1배의 차이를 만든다

vitb와 vits는 입력 해상도가 224×224로 동일하다. 전처리·후처리 비용도 사실상 같다. 따라서 162.37 ms와 76.63 ms의 차이는 모델 규모에서만 기인한다.

### 7-3. 입력 픽셀 수와 추론 시간이 비례하지 않는다

yolov8-n-seg는 depthanythingv2-vits보다 입력 픽셀이 약 8배 많음에도(640² vs 224²) 추론 시간이 더 짧다(63.45 ms vs 76.63 ms).

**가설:** DX-M1이 convolution 계열 연산에 최적화되어 있고, ViT 기반 모델의 attention 연산은 상대적으로 메모리 대역폭 제약을 받는다.

이는 이번 측정만으로 확정할 수 없다. 검증하려면 동일 계열 내에서 입력 해상도를 변화시킨 측정, 또는 연산자 단위 프로파일링이 필요하다.

---

## 8. 한계

측정값을 인용할 때 아래를 함께 고려해야 한다.

- **표본 크기가 불균등하다.** vitb는 579초에 걸쳐 3,483 프레임을 수집한 반면 나머지 둘은 약 30초, 350~440 프레임이다. 후자는 신뢰구간이 넓다.
- **분포 정보가 없다.** 실행 파일이 평균값만 출력하므로 p95·p99 등 꼬리 지연을 알 수 없다. 실시간성 판정에는 평균보다 꼬리 지연이 중요하다.
- **열 조건을 통제하지 않았다.** CPU governor, 주변 온도, 방열 상태를 기록하지 않았다. 장시간 실행 시 스로틀링 영향을 배제할 수 없다.
- **정확도를 측정하지 않았다.** depth 오차나 분할 품질은 이번 범위 밖이다.
- **NPU 추정 깊이와 카메라 하드웨어 깊이를 비교하지 않았다.** D405는 스테레오 방식으로 깊이를 직접 출력하므로, 단안 추정 모델의 출력과 대조하는 것이 자연스러운 다음 단계이지만 이번에는 수행하지 않았다.

---

## 9. 재현 시 참고

- Debian 13은 RealSense SDK의 검증 대상이 아니다. 위 절차는 이 환경에서 동작했으나 일반적으로 보장되지 않는다. 검증된 조합을 원한다면 Raspberry Pi OS Bookworm 또는 Ubuntu를 고려할 수 있다.
- 카메라 노드 인덱스는 환경마다 다르다. 4절의 순차 시도 방법으로 직접 확인하는 것이 확실하다.
- Python 바인딩은 이번 빌드에서 제외했다. 시스템 Python 3.13에서 `pyrealsense2`를 사용하려면 별도 검증이 필요하며, 가상환경으로 3.10~3.11을 구성하는 편이 안전할 수 있다.
- DX-M1 Model Zoo에는 깊이 추정(`depthanythingv2`, `fastdepth`, `scdepthv3`)과 분할(`yolo11-*-seg`, `yolov8-*-seg`, `deeplabv3plus-*`, `segformer`, `fastsam`) 계열 모델이 사전 컴파일되어 포함되어 있다. 표준 모델을 사용하는 경우 별도 컴파일 없이 즉시 실행 가능하다.

---

## 10. 다음 단계

- async 모드 측정 및 sync 대비 비교
- 동일 표본 크기로 재측정, 지연 분포(p50/p95/p99) 확보
- NPU 단안 깊이 추정 결과와 D405 스테레오 깊이의 정량 비교
- 측정 조건(governor, 온도) 기록을 포함한 자동화 스크립트 작성
