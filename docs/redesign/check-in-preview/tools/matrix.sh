# Browser QA for the check-in prototype (real Chrome via the DevTools protocol).
# 1. flutter build web -t lib/main_redesign_preview.dart -o <dir>; serve <dir> on :8811
# 2. S=<work dir> . docs/redesign/check-in-preview/tools/matrix.sh; run 360 1500 2 1
#    (width, height, device pixel ratio, browser text scale); screenshots in $S/shots
S=${S:?set S to a working directory}
TOOLS=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
mkdir -p "$S/shots"
run() { # width height dpr scale
  local n="w$1_t$4"
  node $TOOLS/cdp.mjs "{\"url\":\"http://localhost:8811/\",\"width\":$1,\"height\":$2,\"dpr\":$3,\"textScale\":$4,\"out\":\"$S/shots\",\"actions\":[
   {\"click\":\"Begin today's check-in\",\"after\":1500},{\"metrics\":true},{\"state\":\"Mood\"},{\"shot\":\"${n}_step1\"},
   {\"click\":\"Mood: Good\",\"after\":600},{\"state\":\"Mood\"},
   {\"click\":\"Continue to stress rating\",\"after\":1000},{\"metrics\":true},{\"shot\":\"${n}_step2\"},
   {\"click\":\"Finish check-in\",\"after\":1000},{\"metrics\":true},{\"shot\":\"${n}_done\"}]}" > $S/shots/$n.log 2>&1
  echo "== $n"; grep -v -E "Injecting|WARNING" $S/shots/$n.log
}
