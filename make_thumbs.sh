#!/bin/bash
# 영상 썸네일 생성 — 저장소 루트에서 실행
# media/ 에 영상 4개를 넣은 뒤 이 스크립트를 돌리면 assets/ 에 썸네일이 생성된다.
set -e
mkdir -p assets
T=7          # 추출 시각(초). 장면이 잘 드러나는 지점으로 조정 가능
declare -A M=(
  [input]=media/input_scene.mp4
  [dxm1]=media/dxm1_int8.mp4
  [xavier]=media/xavier_int8.mp4
  [thor]=media/thor_int8.mp4
)
for k in "${!M[@]}"; do
  f="${M[$k]}"
  if [ -f "$f" ]; then
    ffmpeg -y -loglevel error -ss "$T" -i "$f" -frames:v 1 -vf "scale=480:-2" "assets/thumb-$k.png"
    echo "assets/thumb-$k.png"
  else
    echo "SKIP (없음): $f"
  fi
done
