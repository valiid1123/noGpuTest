#!/usr/bin/env bash
set -euo pipefail
#works
DISPLAY_NUM="${DISPLAY_NUM:-1}"
SCREEN="${SCREEN:-1024x720x24}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[1;32m[ OK ]\033[0m  %s\n' "$*"; }
die()   { printf '\033[1;31m[FAIL]\033[0m  %s\n' "$*" >&2; exit 1; }

PIDS=()
cleanup() {
    info "Shutting down..."
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

info "Installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
    curl \
    xvfb \
    x11vnc \
    fluxbox \
    websockify \
    novnc \
    libgl1-mesa-dri \
    mesa-utils \
    libegl1-mesa-dev \
    x11-xserver-utils \
    terminator \
    thunar \
    codelite \
    synaptic

info "Adding Brave Browser repository..."
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
    https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends brave-browser

ok "Dependencies installed."

info "Starting Xvfb on :${DISPLAY_NUM} (${SCREEN}) with GLX..."
Xvfb ":${DISPLAY_NUM}" \
    -screen 0 "${SCREEN}" \
    +extension GLX \
    +render \
    -noreset \
    -ac &
PIDS+=($!)
export DISPLAY=":${DISPLAY_NUM}"
export LIBGL_ALWAYS_SOFTWARE=1

for i in $(seq 1 10); do
    [[ -e "/tmp/.X11-unix/X${DISPLAY_NUM}" ]] && break
    sleep 0.5
done
[[ -e "/tmp/.X11-unix/X${DISPLAY_NUM}" ]] || die "Xvfb did not start"
ok "Virtual display ready."

fluxbox &
PIDS+=($!)

info "Starting x11vnc on port ${VNC_PORT}..."
x11vnc -display ":${DISPLAY_NUM}" -nopw -forever -shared -rfbport "${VNC_PORT}" &
PIDS+=($!)

info "Starting noVNC on port ${NOVNC_PORT}..."
websockify --web=/usr/share/novnc "${NOVNC_PORT}" "localhost:${VNC_PORT}" &
PIDS+=($!)

info "enabling dbus"
sudo service dbus start
PIDS+=($!)

info "Launching Brave Browser with WebGL (SwiftShader)..."
brave-browser \
    --no-sandbox \
    --disable-gpu-sandbox \
    --use-gl=angle \
    --use-angle=swiftshader \
    --enable-unsafe-swiftshader \
    --enable-webgl \
    --no-first-run \
    --start-maximized \
    --window-size=1280,720 \
    about:blank &
PIDS+=($!)

ok "GUI environment is ready!"
echo ""
echo "  VNC:      localhost:${VNC_PORT}"
echo "  noVNC:    localhost:${NOVNC_PORT}"
echo "  GL:       software (llvmpipe via Mesa)"
echo "  WebGL:    SwiftShader (software)"
echo ""
echo "  To verify WebGL: open https://webglreport.com in the noVNC browser"
echo ""
info "Press Ctrl+C to stop everything."
wait   
 
