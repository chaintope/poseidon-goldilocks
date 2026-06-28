#!/usr/bin/env bash
# Build the hand-written Yul stage(s) to deployable bytecode.
#
#   yul/build.sh 1     -> Stage1.yul -> Stage1.hex
#   yul/build.sh 2     -> Stage2.yul -> Stage2.hex
#   yul/build.sh       -> both (default)
#
# IMPORTANT: the explicit --yul-optimizations step string is REQUIRED. solc's DEFAULT
# Yul optimizer driver bloats these past EIP-170 (StackLimitEvader runaway, ~60KB > 24KB).
# The fixed single-pass step list keeps them small (Stage2 ~8.4KB < the solc PGStage2, 10.7KB).
#
# OUT overrides the output path for a SINGLE stage so the drift-check tests
# (test_Stage{1,2}HexMatchesYulSource) can compile to a temp file and diff against the
# committed hex without mutating it. OUT is ignored when building both stages.
set -euo pipefail
SOLC="${SOLC:-$HOME/.local/share/svm/0.8.24/solc-0.8.24}"
DIR="$(dirname "$0")"

build_one() {
  local src="$1" out="$2"
  local bin
  bin=$("$SOLC" --strict-assembly --optimize --yul-optimizations "dhfoDgvulfnTUtnIf" --bin "$src" \
        | grep -vE '=======|Binary|^$' | tail -1)
  echo "0x$bin" > "$out"
  echo "wrote $out  (creation bytecode: $(( ${#bin}/2 )) bytes)"
}

case "${1:-all}" in
  1) build_one "$DIR/Stage1.yul" "${OUT:-$DIR/Stage1.hex}" ;;
  2) build_one "$DIR/Stage2.yul" "${OUT:-$DIR/Stage2.hex}" ;;
  all)
    build_one "$DIR/Stage1.yul" "$DIR/Stage1.hex"
    build_one "$DIR/Stage2.yul" "$DIR/Stage2.hex"
    ;;
  *) echo "usage: $0 [1|2|all]" >&2; exit 1 ;;
esac
