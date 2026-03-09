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

show_help() {
    echo -e "${CYAN}Battle.net Linux Launcher${NC}"
    echo ""
    echo "Uso: $0 [opciones]"
    echo ""
    echo "Opciones:"
    echo "  --battlenet      Lanzar Battle.net (por defecto)"
    echo "  --wow-retail     Lanzar WoW Retail directamente"
    echo "  --wow-classic    Lanzar WoW Classic directamente"
    echo "  --winecfg        Abrir Wine configuration"
    echo "  --winetricks     Abrir winetricks"
    echo "  --kill           Matar todos los procesos de Wine"
    echo "  --prefix         Abrir el prefix en el explorador de archivos"
    echo "  --log            Ver logs del ultimo lanzamiento"
    echo "  --help           Mostrar esta ayuda"
}

kill_wine() {
    log "Matando procesos de Wine..."
    "$WINESERVER" --kill 2>/dev/null || true
    sleep 1
    log "Procesos eliminados"
}

launch_battlenet() {
    if [ ! -f "$BATTLENET_EXE" ]; then
        ALT_EXE="$WINEPREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
        if [ -f "$ALT_EXE" ]; then
            BATTLENET_EXE="$ALT_EXE"
        else
            err "Battle.net no encontrado. Ejecuta ./setup.sh primero."
        fi
    fi

    log "Lanzando Battle.net..."
    log "GPU: NVIDIA RTX (forzado via PRIME)"
    log "DXVK: activo | Esync: activo | Fsync: activo"
    echo ""

    "$WINE" "$BATTLENET_EXE" \
        --disable-gpu \
        --disable-software-rasterizer \
        --disable-gpu-compositing \
        --no-sandbox \
        2>"$WOW_LAUNCHER_DIR/logs/battlenet-$(date +%Y%m%d_%H%M%S).log" &

    log "Battle.net lanzado (PID: $!)"
    log "Logs en: $WOW_LAUNCHER_DIR/logs/"
}

find_wow_exe() {
    local mode="$1"
    local WOW_BASE="$WINEPREFIX/drive_c/Program Files (x86)/World of Warcraft"

    case "$mode" in
        retail)
            local DIRS=("$WOW_BASE/_retail_")
            local EXES=("Wow.exe" "WoW.exe")
            ;;
        classic)
            local DIRS=(
                "$WOW_BASE/_classic_"
                "$WOW_BASE/_classic_era_"
                "$WOW_BASE/_classic_anniversary_"
            )
            local EXES=("WowClassic.exe" "Wow.exe" "WoW.exe")
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
        warn "No se encontro WoW $label. Lanzando Battle.net para instalarlo..."
        launch_battlenet
        return
    }

    log "Lanzando WoW $label..."
    log "Ejecutable: $WOW_EXE"
    log "GPU: NVIDIA RTX (forzado via PRIME)"
    echo ""

    "$WINE" "$WOW_EXE" \
        2>"$WOW_LAUNCHER_DIR/logs/wow-${mode}-$(date +%Y%m%d_%H%M%S).log" &

    log "WoW $label lanzado (PID: $!)"
}

# Parse arguments
case "${1:-}" in
    --wow-retail)
        launch_wow retail
        ;;
    --wow-classic|--wow)
        launch_wow classic
        ;;
    --winecfg)
        log "Abriendo Wine Configuration..."
        "$WINE" winecfg &
        ;;
    --winetricks)
        log "Abriendo Winetricks..."
        winetricks &
        ;;
    --kill)
        kill_wine
        ;;
    --prefix)
        xdg-open "$WINEPREFIX/drive_c/" 2>/dev/null &
        log "Abierto explorador en el prefix"
        ;;
    --log)
        LATEST_LOG=$(ls -t "$WOW_LAUNCHER_DIR/logs/"*.log 2>/dev/null | head -1)
        if [ -n "$LATEST_LOG" ]; then
            less "$LATEST_LOG"
        else
            warn "No hay logs disponibles"
        fi
        ;;
    --help|-h)
        show_help
        ;;
    --battlenet|"")
        launch_battlenet
        ;;
    *)
        warn "Opcion desconocida: $1"
        show_help
        exit 1
        ;;
esac
