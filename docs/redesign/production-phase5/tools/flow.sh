#!/bin/bash
# Real-Chrome QA for the Phase 5 production screens (Splash, Onboarding, Consent).
# 1. cd mobile && flutter build web; serve build/web (e.g. python3 -m http.server 8815)
# 2. S=<work dir> bash flow.sh   (defines p5 and the action lists; see matrix.sh)
S=${S:?set S to a working directory}; TOOLS=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../check-in-preview/tools" && pwd)
mkdir -p "$S/shots"
p5() { # name port width height dpr scale boot-ms actions
  node $TOOLS/cdp.mjs "{\"url\":\"http://localhost:$2/\",\"width\":$3,\"height\":$4,\"dpr\":$5,\"textScale\":$6,\"reducedMotion\":true,\"boot\":$7,\"out\":\"$S/shots\",\"actions\":[$8]}" > $S/shots/$1.log 2>&1
  echo "== $1 shots=$(grep -c '^shot' $S/shots/$1.log) missing=$(grep -c MISSING $S/shots/$1.log) err=$(grep -c -E 'ERROR|EXC' $S/shots/$1.log) hscroll_ok=$(grep metrics $S/shots/$1.log | python3 -c 'import sys,json;print(all(json.loads(l.split("metrics: ")[1])["scrollW"]==json.loads(l.split("metrics: ")[1])["innerW"] for l in sys.stdin))') home=$(grep -c 'Home tab \[current\]' $S/shots/$1.log)"
  grep -E "MISSING|ERROR|EXC" $S/shots/$1.log | head -3
}
# Splash is on screen for 1.8 s once the app starts: take a burst early (short boot).
SPLASH='{"shot":"NAME_splash_1"},{"wait":350},{"shot":"NAME_splash_2"},{"wait":350},{"shot":"NAME_splash_3"},{"wait":350},{"shot":"NAME_splash_4"}'
# The real first-launch route, with consent changes and the Profile review path.
FLOW='{"metrics":true},{"shot":"NAME_onboarding_1"},{"click":"Continue","after":900},{"state":"Step"},{"shot":"NAME_onboarding_2"},{"click":"Continue","after":900},{"shot":"NAME_onboarding_3"},{"click":"Get Started","after":1500},{"metrics":true},{"shot":"NAME_consent_default"},{"click":"M2 · Journal","after":600},{"click":"M5 · Voice","after":600},{"shot":"NAME_consent_changed"},{"click":"Continue to SENSE","after":2500},{"state":"Home tab"},{"click":"Profile tab","after":1200},{"click":"Review data and consent preferences","after":1500},{"shot":"NAME_consent_review"},{"click":"Done","after":1200},{"state":"Profile tab"}'
# Lighter route for the width x text-size matrix.
MATRIX='{"metrics":true},{"shot":"NAME_onboarding"},{"click":"Continue","after":900},{"click":"Continue","after":900},{"click":"Get Started","after":1500},{"metrics":true},{"shot":"NAME_consent"},{"click":"Continue to SENSE","after":2500},{"state":"Home tab"}'
