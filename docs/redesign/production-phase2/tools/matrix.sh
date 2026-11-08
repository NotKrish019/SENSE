#!/bin/bash
S=${S:?set S to a working directory}; TOOLS=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../check-in-preview/tools" && pwd)
. "$(dirname "${BASH_SOURCE[0]}")/flow.sh"
M='{"click":"Insights tab","after":1200},{"metrics":true},{"shot":"NAME_insights"},{"click":"Profile tab","after":1200},{"metrics":true},{"shot":"NAME_profile"},{"click":"Home tab","after":1200},{"scroll":2500},{"scroll":2500},{"click":"View example details","after":1500},{"metrics":true},{"shot":"NAME_detail"},{"click":"Back","after":1200},{"state":"Home tab"}'
for cfg in "320 1700 2" "360 1700 2" "412 1700 2" "768 1400 1" "1024 1000 1" "1280 1000 1" "1440 1000 1"; do
  set -- $cfg
  for ts in 1 2; do
    h=$2; if [ $ts = 2 ]; then h=$(( $2 * 2 > 2800 ? 2800 : $2 * 2 )); fi
    n=m_${1}_t${ts}
    p2 $n 8814 $1 $h $3 $ts "${M//NAME/$n}" &
  done
  wait
done
