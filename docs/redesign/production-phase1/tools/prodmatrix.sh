#!/bin/bash
S=${S:?set S to a working directory}; TOOLS=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../check-in-preview/tools" && pwd)
. "$(dirname "${BASH_SOURCE[0]}")/prodflow.sh"
FLOW='{"metrics":true},{"shot":"NAME_home"},{"click":"Insights tab","after":900},{"shot":"NAME_insights"},{"metrics":true},{"click":"Home tab","after":900},{"click":"New daily check-in","after":1500},{"metrics":true},{"shot":"NAME_ci1"},{"click":"Mood: Good","after":600},{"state":"Mood"},{"click":"Continue to stress rating","after":1000},{"shot":"NAME_ci2"},{"click":"Finish check-in","after":1000},{"shot":"NAME_done"},{"click":"Return to Home","after":1500},{"state":"Home tab"}'
for cfg in "320 1500 2" "360 1500 2" "412 1500 2" "768 1300 1" "1024 900 1" "1280 900 1" "1440 900 1"; do
  set -- $cfg
  for ts in 1 2; do
    h=$2; if [ $ts = 2 ]; then h=$(( $2 * 2 > 2600 ? 2600 : $2 * 2 )); fi
    n=pm_${1}_t${ts}
    prod $n $1 $h $3 $ts "${FLOW//NAME/$n}" &
  done
  wait
done
