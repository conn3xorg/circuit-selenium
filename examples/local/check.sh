#!/usr/bin/env sh
# Runs on the host: asks the Grid for a real browser session through its
# published address, loads a page served only inside the node, and reads the
# page's title back. Then checks that the Grid's port is on loopback and the
# event bus isn't on the host at all. CI pipes it in with podman exec.
# Usage: sh check.sh [chromium|firefox]...  (default chromium)
set -eu
[ $# -gt 0 ] || set -- chromium

ports=$(podman port selenium-hub)
echo "selenium-hub publishes: $ports"
[ "$ports" = "4444/tcp -> 127.0.0.1:4444" ] || { echo "Expected only 4444 on loopback." >&2; exit 1; }

# The hub's image brings curl, and the host network means this goes through
# the published port as a client on the host would. Some hosts have no curl.
image=$(podman inspect selenium-hub --format '{{.ImageName}}')
client() {
  podman run --rm -i --network=host --entrypoint sh "$image" -s "$@"
}

for browser in "$@"; do
  node=selenium-node-$browser
  case "$browser" in
    chromium) name=chrome ;;
    firefox) name=firefox ;;
    *) echo "Unknown browser $browser" >&2; exit 1 ;;
  esac
  title="conn3x-check-$browser-$$"
  # timeout ends the page's server even if the check fails partway.
  podman exec -d "$node" sh -c "mkdir -p /tmp/page && echo '<!doctype html><title>$title</title><h1>hello</h1>' > /tmp/page/index.html && cd /tmp/page && exec timeout 180 python3 -m http.server 8099 --bind 127.0.0.1"
  sleep 2

  client "$name" "$title" <<'SCRIPT'
set -eu
grid=http://127.0.0.1:4444
for _ in $(seq 60); do
  curl -sf "$grid/status" | grep -q '"ready": *true' && break
  sleep 2
done
caps="{\"capabilities\":{\"alwaysMatch\":{\"browserName\":\"$1\"}}}"
session=$(curl -sf --max-time 120 -H 'Content-Type: application/json' -d "$caps" "$grid/session")
id=$(printf '%s' "$session" | sed -n 's/.*"sessionId": *"\([^"]*\)".*/\1/p')
[ -n "$id" ] || { echo "No session: $session" >&2; exit 1; }
curl -sf --max-time 60 -H 'Content-Type: application/json' -d '{"url":"http://127.0.0.1:8099/"}' "$grid/session/$id/url" >/dev/null
got=$(curl -sf --max-time 30 "$grid/session/$id/title")
curl -sf -X DELETE "$grid/session/$id" >/dev/null
echo "$1 read: $got"
case "$got" in
  *"\"$2\""*) ;;
  *) echo "Expected the title $2." >&2; exit 1 ;;
esac
SCRIPT
done
echo "All checks passed."
