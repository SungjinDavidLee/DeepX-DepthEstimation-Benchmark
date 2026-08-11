# media

정성 비교용 영상 파일을 보관한다. 상세 설명은 [docs/qualitative.md](../docs/qualitative.md)에 있다.

## 파일 목록

| 파일 | 내용 |
|---|---|
| `input_scene.mp4` | 입력 영상. 세 플랫폼 공통 |
| `dxm1_int8.mp4` | Raspberry Pi 5 + DX-M1, INT8 |
| `thor_int8.mp4` | Jetson AGX Thor, INT8 (캘리브레이션 적용) |
| `thor_fp16.mp4` | Jetson AGX Thor, FP16 |
| `xavier_int8.mp4` | Jetson AGX Xavier, INT8 (캘리브레이션 적용) |

모델은 전 플랫폼 동일하게 Depth Anything V2 ViT-S (224×224)를 사용했다.

각 영상 좌상단에 플랫폼명과 실시간 처리량이 표시된다. 이 값은 영상 디코딩·전처리·추론·후처리·인코딩을 포함한 파이프라인 전체 처리량이며, 벤치마크의 가속기 연산 시간과 다르다.

## 참고

- 무보정 INT8 엔진으로 생성한 영상은 출력이 붕괴하여 포함하지 않았다. 상세는 [docs/qualitative.md](../docs/qualitative.md) 4장 참조
- 저장소 용량을 고려하여 영상은 15초 길이로 제한했다
