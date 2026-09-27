#!/usr/bin/env bash
# ケースが共有する準備。空の作業場所へ、お題の要件と業務の分け方を置く。
# 各ケースの scaffold.sh が、お題のディレクトリを渡して呼ぶ。
set -euo pipefail

[ $# -eq 1 ] || { echo "使い方: bash scaffold.sh <お題のディレクトリ>" >&2; exit 2; }
TOPIC_DIR=$(cd "$1" && pwd)

mkdir -p input out grill-log
cp "$TOPIC_DIR"/materials/input/*.md input/
cp "$TOPIC_DIR/materials/split.md" split.md
