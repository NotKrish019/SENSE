#!/bin/bash
S=${S:?set S to a working directory}; TOOLS=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../check-in-preview/tools" && pwd)
INTRO='{"click":"Continue"},{"click":"Continue"},{"click":"Get Started","after":1200},{"scroll":4000},{"scroll":4000},{"scroll":4000},{"click":"Continue to SENSE","after":2500}'
p2() { # name port width height dpr scale actions [extra-json]
  node $TOOLS/cdp.mjs "{\"url\":\"http://localhost:$2/\",\"width\":$3,\"height\":$4,\"dpr\":$5,\"textScale\":$6,\"reducedMotion\":true,\"boot\":8000,\"out\":\"$S/shots\"$8,\"actions\":[$INTRO,$7]}" > $S/shots/$1.log 2>&1
  echo "== $1 shots=$(grep -c '^shot' $S/shots/$1.log) missing=$(grep -c MISSING $S/shots/$1.log) err=$(grep -c -E 'ERROR|EXC' $S/shots/$1.log) hscroll_ok=$(grep metrics $S/shots/$1.log | python3 -c 'import sys,json;print(all(json.loads(l.split("metrics: ")[1])["scrollW"]==json.loads(l.split("metrics: ")[1])["innerW"] for l in sys.stdin))')"
  grep -E "MISSING|ERROR|EXC" $S/shots/$1.log | head -3
}
FLOW='{"click":"Insights tab","after":1200},{"metrics":true},{"shot":"NAME_insights"},{"state":"Week view"},{"click":"Month view","after":600},{"state":"Month view"},{"click":"Profile tab","after":1200},{"metrics":true},{"shot":"NAME_profile"},{"scroll":1800},{"click":"Export my data","after":900},{"shot":"NAME_export"},{"click":"OK","after":700},{"click":"Home tab","after":1200},{"scroll":2500},{"click":"View example details","after":1500},{"metrics":true},{"shot":"NAME_detail"},{"click":"Back","after":1200},{"state":"Home tab"}'
