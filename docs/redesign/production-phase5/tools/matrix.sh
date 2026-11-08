#!/bin/bash
# Every width at text 1x, 1.5x and 2x: Onboarding > Consent > Home.
# S=<work dir> PORT=8815 bash matrix.sh
S=${S:?set S to a working directory}; PORT=${PORT:-8815}
. "$(dirname "${BASH_SOURCE[0]}")/flow.sh"
for cfg in "320 1800 2" "360 1800 2" "412 1800 2" "768 1500 1" "1024 1100 1" "1280 1100 1" "1440 1100 1"; do
  set -- $cfg
  for ts in 1 1.5 2; do
    h=$(python3 -c "print(min(4000, int($2 * $ts)))")
    n=m_${1}_t${ts/./_}
    p5 $n $PORT $1 $h $3 $ts 9000 "${MATRIX//NAME/$n}"
  done
done
