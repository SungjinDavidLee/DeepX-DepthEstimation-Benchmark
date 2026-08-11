# 환경 구축

---

## 1. Raspberry Pi 5 + DX-M1

### 1-1. 모델 준비

DX-AllSuite 배포판 Model Zoo에 사전 컴파일된 `.dxnn` 파일이 포함되어 있다. 표준 모델을 사용하는 경우 별도 컴파일이 필요하지 않다.

```
dx_app/assets/models/
```

깊이 추정(`depthanythingv2-*`, `fastdepth`, `scdepthv3`), 검출(`yolov8-*`, `yolo11-*`, `yolo26-*`), 분할(`*-seg`, `deeplabv3plus-*`, `segformer`, `bisenetv2`, `pidnet-s`, `fastsam-s`) 계열이 포함되어 있다.

### 1-2. 측정용 디렉토리 구성

`dxbenchmark`는 디렉토리 단위로 동작하며 여러 모델을 넣으면 마지막 모델의 프로파일만 출력한다. 모델별로 디렉토리를 분리한다.

```bash
mkdir -p ~/bench_yolo ~/bench_seg ~/bench_sam
cd <model_zoo_경로>
cp yolov8-n_640x640.dxnn ~/bench_yolo/
cp yolov8-n-seg_640x640.dxnn ~/bench_seg/
cp fastsam-s_1024x1024.dxnn ~/bench_sam/
```

### 1-3. 실행

```bash
dxbenchmark --dir ~/bench_yolo --loops 300 --warmup 50 -v --use-ort
```

### 1-4. 장치 상태 확인

```bash
dxrt-cli --status
```

드라이버 버전, 펌웨어 버전, PCIe 링크 폭, NPU 코어별 전압·클럭·온도를 출력한다.

---

## 2. Jetson 공통

### 2-1. ONNX 확보

Xavier에는 `pip`이 설치되어 있지 않아 ONNX export를 수행할 수 없다. 두 Jetson 모두 외부 배포본을 내려받아 사용했다. 출처는 [models.md](models.md)에 있다.

동일 파일을 두 장비에 사용하여 모델 변수를 통제했다.

### 2-2. `trtexec` 경로

| 플랫폼 | 경로 |
|---|---|
| Xavier | `/usr/src/tensorrt/bin/trtexec` (PATH 미포함) |
| Thor | `/usr/bin/trtexec` (PATH 포함) |

스크립트 작성 시 `TX=$(which trtexec)` 또는 전체 경로를 사용한다.

### 2-3. 빌드 및 측정

[methodology.md](methodology.md)를 참조한다.

---

## 3. RealSense D405 연결 (선택)

카메라 입력을 사용하는 실사용 측정에만 필요하다. 본 벤치마크에는 사용하지 않았다.

Debian 13은 RealSense SDK가 공식 검증한 환경이 아니다. 아래 절차로 동작을 확인했으나 일반적으로 보장되지 않는다.

### 3-1. 배포판 패키지 부재

Intel은 Ubuntu용 apt 저장소만 제공한다.

```bash
sudo apt install librealsense2-utils librealsense2-dev
# Error: Unable to locate package librealsense2-utils
```

### 3-2. 소스 빌드

```bash
sudo apt install -y git cmake build-essential libssl-dev libusb-1.0-0-dev libudev-dev pkg-config

git clone --depth=1 https://github.com/IntelRealSense/librealsense.git
cd librealsense && mkdir build && cd build

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

| 플래그 | 이유 |
|---|---|
| `FORCE_RSUSB_BACKEND=ON` | libuvc 백엔드 사용, 커널 모듈 패치 회피 |
| `BUILD_EXAMPLES=FALSE` | 일부 예제가 OpenGL 타깃을 참조하여 링크 실패 |
| `BUILD_PYTHON_BINDINGS=FALSE` | 시스템 Python 3.13에서 바인딩 빌드 미검증 |

`BUILD_GRAPHICAL_EXAMPLES=FALSE`만으로는 링크 오류가 해결되지 않는다.

```
CMake Error at examples/hello-realsense/CMakeLists.txt:9 (target_link_libraries):
  Target "rs-hello-realsense" links to: OpenGL::GL but the target was not found.
```

### 3-3. USB 접근 권한

빌드 직후 일반 사용자 권한으로 실행하면 실패한다.

```
ERROR (handle-libusb.h:53) failed to open usb interface: 0, error: RS2_USB_STATUS_ACCESS
```

udev 규칙을 설치한다.

```bash
sudo cp config/99-realsense-libusb.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

**규칙은 장치 연결 시점에 적용되므로 USB 케이블을 재연결해야 한다.** 적용 여부는 소유권으로 확인한다.

```bash
ls -l /dev/bus/usb/<bus>/
# 적용 전: crw-rw-r--  1 root root
# 적용 후: crw-rw-rw-  1 root plugdev
```

### 3-4. 카메라 노드 식별

D405는 6개의 V4L2 노드로 열거되지만 OpenCV 캡처가 열 수 있는 노드는 하나다. `v4l2-ctl --list-formats`는 이 장치에 대해 빈 결과를 반환하므로 순차 시도로 판별한다.

```bash
for n in 0 1 2 3 4 5; do
  echo "=== camera $n ==="
  timeout 8 <실행파일> -m <모델> -c $n --no-display 2>&1 | tail -3
done
```

`timeout`에 의해 종료되는 인덱스가 정상 동작하는 노드다. 나머지는 즉시 오류로 종료된다.
