#!/bin/bash
# Real-Chrome QA for the Phase 4 production screens (Voice, Activity).
# 1. cd mobile && flutter build web; serve build/web (e.g. python3 -m http.server 8815)
# 2. S=<work dir> bash flow.sh   (defines p4 and the action lists; see matrix.sh)
S=${S:?set S to a working directory}; TOOLS=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../check-in-preview/tools" && pwd)
mkdir -p "$S/shots"
INTRO='{"click":"Continue"},{"click":"Continue"},{"click":"Get Started","after":1200},{"scroll":4000},{"scroll":4000},{"scroll":4000},{"click":"Continue to SENSE","after":2500}'
p4() { # name port width height dpr scale actions
  node $TOOLS/cdp.mjs "{\"url\":\"http://localhost:$2/\",\"width\":$3,\"height\":$4,\"dpr\":$5,\"textScale\":$6,\"reducedMotion\":true,\"boot\":9000,\"out\":\"$S/shots\",\"actions\":[$INTRO,$7]}" > $S/shots/$1.log 2>&1
  echo "== $1 shots=$(grep -c '^shot' $S/shots/$1.log) missing=$(grep -c MISSING $S/shots/$1.log) err=$(grep -c -E 'ERROR|EXC' $S/shots/$1.log) hscroll_ok=$(grep metrics $S/shots/$1.log | python3 -c 'import sys,json;print(all(json.loads(l.split("metrics: ")[1])["scrollW"]==json.loads(l.split("metrics: ")[1])["innerW"] for l in sys.stdin))') home=$(grep -c 'Home tab \[current\]' $S/shots/$1.log)"
  grep -E "MISSING|ERROR|EXC" $S/shots/$1.log | head -3
}
# Home > Voice / Activity (from "Ways to reflect"), Back after each.
VISIT='{"scroll":1600},{"click":"SCREEN","after":1500},{"metrics":true},{"shot":"NAME_KEY"},{"click":"Back","after":1200},{"state":"Home tab"}'
visit() { local v=${VISIT//SCREEN/$1}; echo "${v//KEY/$2}"; }
ALL="$(visit Voice voice),$(visit Activity activity)"
# Interaction states: Voice consent link; Activity Save (use a phone-height window).
STATES='{"scroll":1600},{"click":"Voice","after":1500},{"click":"Review data and consent preferences","after":1500},{"shot":"NAME_voice_consent"},{"click":"Back","after":1200},{"scroll":-6000},{"click":"Back","after":1200},{"scroll":1600},{"click":"Activity","after":1500},{"click":"Save Activity Entry","after":900},{"shot":"NAME_activity_saved"},{"click":"Back","after":1200},{"state":"Home tab"}'
