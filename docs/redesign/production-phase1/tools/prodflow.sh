S=${S:?set S to a working directory}; TOOLS=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../../check-in-preview/tools" && pwd)
# Real production entry: Splash > Onboarding (2x Continue, Get Started) > Consent (Continue to SENSE) > Home
INTRO='{"click":"Continue"},{"click":"Continue"},{"click":"Get Started","after":1200},{"scroll":4000},{"scroll":4000},{"scroll":4000},{"click":"Continue to SENSE","after":2500}'
prod() { # name width height dpr scale extra-actions
  node $TOOLS/cdp.mjs "{\"url\":\"http://localhost:8813/\",\"width\":$2,\"height\":$3,\"dpr\":$4,\"textScale\":$5,\"boot\":8000,\"out\":\"$S/shots\",\"actions\":[$INTRO,$6]}" > $S/shots/$1.log 2>&1
  echo "== $1 shots=$(grep -c '^shot' $S/shots/$1.log) missing=$(grep -c MISSING $S/shots/$1.log) err=$(grep -c -E 'ERROR|EXC' $S/shots/$1.log)"; grep -E "MISSING|ERROR|EXC" $S/shots/$1.log | head -3
}
