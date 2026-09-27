#!/bin/bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/ensure-toolchain.sh
swift test ${TESTING_FLAGS[@]+"${TESTING_FLAGS[@]}"} "$@"
