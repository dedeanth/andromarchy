#!/bin/bash
# Root side of Andromarchy, run through pkexec. It only does what a user cannot:
# start or stop the Waydroid container, look inside Android, and reinstall
# libhoudini into the Waydroid images.
set -u

netcheck() {
  if ! waydroid shell -- true >/dev/null 2>&1; then
    echo '{"reachable":false}'
    return
  fi
  local network=false internet=false dns=false
  waydroid shell -- dumpsys connectivity 2>/dev/null | grep -m1 'Active default network' | grep -qv 'none' && network=true
  waydroid shell -- ping -c1 -W3 1.1.1.1 >/dev/null 2>&1 && internet=true
  waydroid shell -- ping -c1 -W3 google.com >/dev/null 2>&1 && dns=true
  echo "{\"reachable\":true,\"network\":$network,\"internet\":$internet,\"dns\":$dns}"
}

# waydroid_script only ships libhoudini for the Android versions Waydroid images use.
houdini() {
  local dir="$1" version="$2"
  case "$version" in 11|13) ;; *) echo "libhoudini needs Android 11 or 13, this image runs Android ${version:-unknown}" >&2; exit 1 ;; esac
  [ -f "$dir/main.py" ] && [ -x "$dir/venv/bin/python" ] || { echo "waydroid_script not found in $dir" >&2; exit 1; }
  cd "$dir" && "$dir/venv/bin/python" -W ignore main.py -a "$version" install libhoudini
}

# The container can be left disabled at boot (its binder module can spin kswapd),
# so the widget starts it on demand and can stop it once Android is shut down.
container() {
  case "$1" in
    start|stop) systemctl "$1" waydroid-container.service ;;
    *) echo "container takes start or stop" >&2; exit 2 ;;
  esac
}

case "${1:-}" in
  container) container "${2:-}" ;;
  netcheck) netcheck ;;
  houdini)  houdini "${2:?waydroid_script directory}" "${3:?Android version}" ;;
  *) echo "usage: $0 container start|stop|netcheck|houdini <waydroid_script dir> <android version>" >&2; exit 2 ;;
esac
