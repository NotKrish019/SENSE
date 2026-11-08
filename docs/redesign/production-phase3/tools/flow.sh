#!/bin/bash
# Real-Chrome QA for the Phase 3 production screens (Journal, Sleep, Workload).
# 1. cd mobile && flutter build web; serve build/web (e.g. python3 -m http.server 8815)
# 2. S=<work dir> PORT=8815 bash flow.sh   (screenshots and logs go to $S/shots)
S=${S:?set S to a working directory}; TOOLS=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../check-in-preview/tools" && pwd)
mkdir -p "$S/shots"
INTRO='{"click":"Continue"},{"click":"Continue"},{"click":"Get Started","after":1200},{"scroll":4000},{"scroll":4000},{"scroll":4000},{"click":"Continue to SENSE","after":2500}'
p3() { # name port width height dpr scale actions
  node $TOOLS/cdp.mjs "{\"url\":\"http://localhost:$2/\",\"width\":$3,\"height\":$4,\"dpr\":$5,\"textScale\":$6,\"reducedMotion\":true,\"boot\":8000,\"out\":\"$S/shots\",\"actions\":[$INTRO,$7]}" > $S/shots/$1.log 2>&1
  echo "== $1 shots=$(grep -c '^shot' $S/shots/$1.log) missing=$(grep -c MISSING $S/shots/$1.log) err=$(grep -c -E 'ERROR|EXC' $S/shots/$1.log) hscroll_ok=$(grep metrics $S/shots/$1.log | python3 -c 'import sys,json;print(all(json.loads(l.split("metrics: ")[1])["scrollW"]==json.loads(l.split("metrics: ")[1])["innerW"] for l in sys.stdin))')"
  grep -E "MISSING|ERROR|EXC" $S/shots/$1.log | head -3
}
# Home > Journal / Sleep / Workload (from "Ways to reflect"), Back after each.
VISIT='{"scroll":1400},{"click":"SCREEN","after":1500},{"metrics":true},{"shot":"NAME_KEY"},{"click":"Back","after":1200},{"state":"Home tab"}'
visit() { local v=${VISIT//SCREEN/$1}; echo "${v//KEY/$2}"; }
ALL="$(visit Journal journal),$(visit Sleep sleep),$(visit Workload workload)"
# Journal with text (and the support notice), then Save.
JOURNAL_TEXT='{"scroll":1400},{"click":"Journal","after":1500},{"click":"Journal reflection","after":500},{"type":"A long week with several deadlines and late nights. Sometimes I want to die."},{"wait":600},{"metrics":true},{"shot":"NAME_journal_text"},{"click":"Save Reflection","after":900},{"shot":"NAME_journal_saved"},{"click":"Back","after":1200}'
