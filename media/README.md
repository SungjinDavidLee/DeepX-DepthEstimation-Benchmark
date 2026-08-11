# Media

정성 비교용 영상 파일을 보관한다.
상세 설명은 [../docs/qualitative.md](../docs/qualitative.md)에 있다.

## 파일 목록

| 파일                | 내용                       | 정밀도              |
| ----------------- | ------------------------ | ---------------- |
| `input_scene.mp4` | 입력 영상. 세 플랫폼 공통          | —                |
| `dxm1_int8.mp4`   | Raspberry Pi 5 + DX-M1   | INT8 (벤더 컴파일)    |
| `xavier_int8.mp4` | Jetson AGX Xavier · 15 W | INT8 (캘리브레이션 적용) |
| `thor_int8.mp4`   | Jetson AGX Thor · 120 W  | INT8 (캘리브레이션 적용) |

모델은 전 플랫폼 동일하게 **Depth Anything V2 ViT-S (224×224)**를 사용했다.

각 영상 좌상단에 플랫폼명과 실시간 처리량이 표시된다.
이 값은 **영상 디코딩 → 전처리 → 추론 → 후처리 → 인코딩**을 포함한 파이프라인 전체 처리량이며, 벤치마크의 가속기 연산 시간과는 다르다.

## Qualitative Comparison

### Input Scene / DX-M1

<table>
  <tr>
    <th>Input Scene</th>
    <th>Raspberry Pi 5 + DX-M1</th>
  </tr>
  <tr>
    <td align="center">
      <video src="https://github.com/user-attachments/assets/68399634-362c-4de6-b713-28a0f80fd2a0" width="400" controls></video>
    </td>
    <td align="center">
      <video src="https://github.com/user-attachments/assets/1a9a9362-d7e4-414a-8f29-2a53a2b40882" width="400" controls></video>
    </td>
  </tr>
</table>

### Jetson AGX Xavier / Jetson AGX Thor

<table>
  <tr>
    <th>Jetson AGX Xavier · 15 W</th>
    <th>Jetson AGX Thor · 120 W</th>
  </tr>
  <tr>
    <td align="center">
      <video src="https://github.com/user-attachments/assets/488c422d-9428-4bd1-a837-6ee93866b8ac" width="400" controls></video>
    </td>
    <td align="center">
      <video src="https://github.com/user-attachments/assets/4306de66-ffda-47a7-9423-78629c6f7554" width="400" controls></video>
    </td>
  </tr>
</table>

## Thumbnail Generation

루트 README의 영상 비교 표는 `assets/thumb-*.png`를 참조한다.

영상을 추가한 뒤 저장소 루트에서 다음 명령을 실행한다.

```bash
./make_thumbs.sh
```

`ffmpeg`이 필요하다.

썸네일 추출 시각은 스크립트 상단의 `T` 값을 수정하여 조정할 수 있다.

## Notes

* 무보정 INT8 엔진으로 생성한 영상은 출력이 붕괴하여 포함하지 않았다. 상세 내용은 [../docs/qualitative.md](../docs/qualitative.md) 4장을 참조한다.
* 저장소 용량을 고려하여 영상은 15초 길이로 제한했다.
* 일부 플레이어에서 재생 길이가 0으로 표시되는 경우 컨테이너 메타데이터 문제일 수 있다. 다음과 같이 재인코딩한다.

```bash
ffmpeg -y -i <입력>.mp4 -c:v libx264 -pix_fmt yuv420p <출력>.mp4
```
