#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

export PATH="$WINE_BIN_DIR:$PATH"
export LD_LIBRARY_PATH="${WINE_LIB_DIR}:${WINE_LIB64_DIR}:${LD_LIBRARY_PATH:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[X]${NC} $1"; exit 1; }

WOW_BASE="$WINEPREFIX/drive_c/Program Files (x86)/World of Warcraft"

show_help() {
    echo -e "${CYAN}Battle.net Linux Launcher${NC}"
    echo ""
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  --battlenet      Launch Battle.net (default)"
    echo "  --wow-forever    Launch WoW Forever directly"
    echo "  --wow-retail     Launch WoW Retail directly"
    echo "  --wow-classic    Launch WoW Classic/Anniversary directly"
    echo "  --wow-beta       Launch the WoW Classic beta (_classic_beta_) directly"
    echo "  --fix-forever    Apply the WoW Forever freeze fix now (done on every launch anyway)"
    echo "  --winecfg        Open Wine configuration"
    echo "  --winetricks     Open winetricks"
    echo "  --kill           Kill all Wine processes"
    echo "  --flush-cache    Move WoW and shader caches aside (settings untouched)"
    echo "  --prefix         Open the prefix in the file manager"
    echo "  --log            Show the latest log"
    echo "  --help           Show this help"
}

kill_wine() {
    log "Killing Wine processes..."
    "$WINESERVER" --kill 2>/dev/null || true
    sleep 1
    log "Done"
}

flush_cache() {
    if pgrep -f "[W]owB\.exe|[W]owClassic\.exe|[W]ow\.exe" >/dev/null; then
        err "Close WoW before flushing the caches."
    fi
    local TS; TS=$(date +%Y%m%d_%H%M%S)
    log "Moving caches aside (suffix $TS). Config.wtf and WTF/ are untouched."
    for c in "$WOW_BASE"/_*_; do
        [ -d "$c/Cache" ] && mv "$c/Cache" "$c/Cache.bak-$TS" && log "  $(basename "$c")/Cache"
    done
    mkdir -p "$WOW_LAUNCHER_DIR/cache-bak-$TS"
    for d in dxvk vkd3d nvidia; do
        [ -d "$WOW_LAUNCHER_DIR/cache/$d" ] && mv "$WOW_LAUNCHER_DIR/cache/$d" "$WOW_LAUNCHER_DIR/cache-bak-$TS/$d"
        mkdir -p "$WOW_LAUNCHER_DIR/cache/$d"
    done
    log "  shader caches (dxvk, vkd3d, nvidia)"
    [ -d "$HOME/.cache/nvidia" ] && mv "$HOME/.cache/nvidia" "$HOME/.cache/nvidia.bak-$TS" && log "  ~/.cache/nvidia"
    log "Done. The first launch compiles shaders again and takes longer."
}

# Set one CVar in a Config.wtf, keeping the file's line endings (the game writes CRLF).
set_cvar() {
    local file="$1" name="$2" value="$3" eol=""
    grep -q $'\r' "$file" && eol=$'\r'
    if grep -qi "^SET $name \"" "$file"; then
        sed -i "s/^SET $name \"[^\"]*\"/SET $name \"$value\"/I" "$file"
    else
        printf 'SET %s "%s"%s\n' "$name" "$value" "$eol" >> "$file"
    fi
}

# WoW Forever freeze fix. On a fresh install the client autodetects the
# hardware (hwDetect) and picks graphics settings that hang its DX12 renderer
# under Wine: the game freezes on the photosensitivity warning and the desktop
# reports it as not responding. Turning autodetect off and starting from a low
# preset lets it load; quality can be raised in game afterwards (keep
# Secondary Lighting low). Applied once per install; never while Forever runs,
# because the game rewrites Config.wtf when it exits.
fix_forever() {
    local dir="$WOW_BASE/_forever_"
    [ -d "$dir" ] || return 0
    local cfg="$dir/WTF/Config.wtf"
    if [ -f "$cfg" ] && grep -qi '^SET hwDetect "0"' "$cfg"; then
        return 0
    fi
    if pgrep -f "[_]forever_.Wow\.exe" >/dev/null; then
        warn "WoW Forever is running: close it, then run ./launch.sh --fix-forever"
        return 0
    fi
    mkdir -p "$dir/WTF"
    if [ -s "$cfg" ]; then
        cp -p "$cfg" "$cfg.bak-$(date +%Y%m%d_%H%M%S)"
    else
        : > "$cfg"
    fi
    set_cvar "$cfg" hwDetect 0
    set_cvar "$cfg" graphicsQuality 3
    set_cvar "$cfg" RAIDgraphicsQuality 3
    log "WoW Forever: hardware autodetect off, low graphics preset (raise it in game)"
}

# Battle.net may install Forever after this launcher started: while Battle.net
# runs, wait for the _forever_ folder and apply the fix before the first launch.
# Ends with Battle.net or once the fix is applied.
watch_forever() {
    local bnet_pid="$1"
    while kill -0 "$bnet_pid" 2>/dev/null; do
        if [ -d "$WOW_BASE/_forever_" ]; then
            fix_forever
            return 0
        fi
        sleep 15
    done
}

launch_battlenet() {
    if [ ! -f "$BATTLENET_EXE" ]; then
        ALT_EXE="$WINEPREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
        if [ -f "$ALT_EXE" ]; then
            BATTLENET_EXE="$ALT_EXE"
        else
            err "Battle.net not found. Run ./setup.sh first."
        fi
    fi

    fix_forever
    log "Launching Battle.net..."
    log "GPU: NVIDIA (forced via PRIME)"
    log "DXVK $DXVK_VERSION + vkd3d-proton $VKD3D_PROTON_VERSION | Esync | Fsync"
    echo ""

    "$WINE" "$BATTLENET_EXE" \
        --disable-gpu \
        --disable-software-rasterizer \
        --disable-gpu-compositing \
        --no-sandbox \
        2>"$WOW_LAUNCHER_DIR/logs/battlenet-$(date +%Y%m%d_%H%M%S).log" &

    local bnet_pid=$!
    log "Battle.net launched (PID: $bnet_pid)"
    log "Logs in: $WOW_LAUNCHER_DIR/logs/"
    [ -d "$WOW_BASE/_forever_" ] || { watch_forever "$bnet_pid" & }
}

find_wow_exe() {
    local mode="$1"

    case "$mode" in
        retail)
            local DIRS=("$WOW_BASE/_retail_")
            local EXES=("Wow.exe" "WoW.exe")
            ;;
        forever)
            local DIRS=("$WOW_BASE/_forever_")
            local EXES=("Wow.exe" "WoW.exe")
            ;;
        classic)
            local DIRS=(
                "$WOW_BASE/_anniversary_"
                "$WOW_BASE/_classic_"
                "$WOW_BASE/_classic_era_"
                "$WOW_BASE/_classic_anniversary_"
            )
            local EXES=("WowClassic.exe" "Wow.exe" "WoW.exe")
            ;;
        beta)
            local DIRS=("$WOW_BASE/_classic_beta_")
            local EXES=("WowB.exe" "WowClassic.exe" "Wow.exe")
            ;;
    esac

    for dir in "${DIRS[@]}"; do
        for exe in "${EXES[@]}"; do
            if [ -f "$dir/$exe" ]; then
                echo "$dir/$exe"
                return 0
            fi
        done
    done
    return 1
}

launch_wow() {
    local mode="$1"
    local label="${mode^}"

    WOW_EXE=$(find_wow_exe "$mode") || {
        warn "WoW $label not found. Launching Battle.net to install it..."
        launch_battlenet
        return
    }

    [ "$mode" = "forever" ] && fix_forever
    log "Launching WoW $label..."
    log "Executable: $WOW_EXE"
    log "GPU: NVIDIA (forced via PRIME)"
    echo ""

    ${GAMEMODE_CMD:-} "$WINE" "$WOW_EXE" \
        2>"$WOW_LAUNCHER_DIR/logs/wow-${mode}-$(date +%Y%m%d_%H%M%S).log" &

    log "WoW $label launched (PID: $!)"
}

# Parse arguments
case "${1:-}" in
    --wow-forever)
        launch_wow forever
        ;;
    --wow-retail)
        launch_wow retail
        ;;
    --wow-classic|--wow)
        launch_wow classic
        ;;
    --wow-beta)
        launch_wow beta
        ;;
    --fix-forever)
        [ -d "$WOW_BASE/_forever_" ] || err "WoW Forever is not installed yet (no _forever_ folder)."
        fix_forever
        ;;
    --winecfg)
        log "Opening Wine configuration..."
        "$WINE" winecfg &
        ;;
    --winetricks)
        log "Opening winetricks..."
        winetricks &
        ;;
    --kill)
        kill_wine
        ;;
    --flush-cache)
        flush_cache
        ;;
    --prefix)
        xdg-open "$WINEPREFIX/drive_c/" 2>/dev/null &
        log "Opened the prefix in the file manager"
        ;;
    --log)
        LATEST_LOG=$(ls -t "$WOW_LAUNCHER_DIR/logs/"*.log 2>/dev/null | head -1)
        if [ -n "$LATEST_LOG" ]; then
            less "$LATEST_LOG"
        else
            warn "No logs yet"
        fi
        ;;
    --help|-h)
        show_help
        ;;
    --battlenet|"")
        launch_battlenet
        ;;
    *)
        warn "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
