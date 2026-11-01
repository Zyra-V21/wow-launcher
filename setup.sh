#!/bin/bash
# One-time setup: Wine, the Direct3D translators, the Wine prefix and Battle.net.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

log() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[X]${NC} $1"; exit 1; }
step() { echo -e "\n${CYAN}=== $1 ===${NC}"; }

# Download a file once into downloads/.
fetch() {
    local url="$1" out="$2"
    if [ -s "$out" ]; then
        log "  already downloaded: $(basename "$out")"
    else
        log "  downloading $(basename "$out")"
        curl -fL --progress-bar -o "$out.part" "$url" && mv "$out.part" "$out"
    fi
}

check_requirements() {
    step "Checking system requirements"

    nvidia-smi &>/dev/null || err "No NVIDIA driver found. Install the proprietary NVIDIA driver first."
    local driver major
    driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
    major=${driver%%.*}
    log "NVIDIA driver: $driver"

    [ -f /usr/share/vulkan/icd.d/nvidia_icd.json ] || err "nvidia_icd.json not found. Install: sudo apt install libnvidia-gl-$major"
    log "Vulkan NVIDIA ICD found"

    if ! dpkg -l "libnvidia-gl-$major:i386" 2>/dev/null | grep -q '^ii'; then
        warn "32-bit NVIDIA libraries missing. Installing..."
        sudo apt install -y "libnvidia-gl-$major:i386" "libnvidia-compute-$major:i386"
    fi
    log "32-bit NVIDIA libraries OK"

    local missing=""
    for pkg in cabextract p7zip-full vulkan-tools winetricks zstd curl; do
        dpkg -l "$pkg" 2>/dev/null | grep -q '^ii' || missing="$missing $pkg"
    done
    if [ -n "$missing" ]; then
        log "Installing required packages:$missing"
        # shellcheck disable=SC2086
        sudo apt install -y $missing
    fi
    log "System packages OK"
}

install_wine() {
    step "Wine $WINE_VERSION Staging"
    mkdir -p "$WOW_LAUNCHER_DIR"/{wine-staging,dxvk,downloads,logs,cache/dxvk,cache/vkd3d,cache/nvidia}
    if [ -x "$WINE" ]; then
        log "Wine already installed"
    else
        local archive="$WOW_LAUNCHER_DIR/downloads/wine-${WINE_VERSION}-staging-amd64.tar.xz"
        fetch "$WINE_URL" "$archive"
        tar -xf "$archive" -C "$WOW_LAUNCHER_DIR/wine-staging/"
        [ -x "$WINE" ] || err "Wine binary not found at $WINE after extracting"
    fi
    "$WINE" --version >/dev/null 2>&1 || err "Wine does not run. Check $WINE"
    log "Wine: $("$WINE" --version 2>/dev/null)"
}

# DXVK, vkd3d-proton and dxvk-nvapi, unpacked under dxvk/.
download_translators() {
    step "Downloading DXVK $DXVK_VERSION, vkd3d-proton $VKD3D_PROTON_VERSION, dxvk-nvapi $DXVK_NVAPI_VERSION"
    local dl="$WOW_LAUNCHER_DIR/downloads"
    mkdir -p "$dl" "$DXVK_DIR"
    fetch "$DXVK_URL" "$dl/dxvk-${DXVK_VERSION}.tar.gz"
    fetch "$VKD3D_PROTON_URL" "$dl/vkd3d-proton-${VKD3D_PROTON_VERSION}.tar.zst"
    fetch "$DXVK_NVAPI_URL" "$dl/dxvk-nvapi-v${DXVK_NVAPI_VERSION}.tar.gz"
    [ -d "$DXVK_DIR/dxvk-${DXVK_VERSION}" ] || tar -xzf "$dl/dxvk-${DXVK_VERSION}.tar.gz" -C "$DXVK_DIR/"
    [ -d "$DXVK_DIR/vkd3d-proton-${VKD3D_PROTON_VERSION}" ] || tar --zstd -xf "$dl/vkd3d-proton-${VKD3D_PROTON_VERSION}.tar.zst" -C "$DXVK_DIR/"
    if [ ! -d "$DXVK_DIR/dxvk-nvapi-v${DXVK_NVAPI_VERSION}" ]; then
        mkdir -p "$DXVK_DIR/dxvk-nvapi-v${DXVK_NVAPI_VERSION}"
        tar -xzf "$dl/dxvk-nvapi-v${DXVK_NVAPI_VERSION}.tar.gz" -C "$DXVK_DIR/dxvk-nvapi-v${DXVK_NVAPI_VERSION}/"
    fi
    log "Translators unpacked in $DXVK_DIR"
}

create_prefix() {
    step "Creating the Wine prefix (win64)"
    if [ -d "$WINEPREFIX/drive_c" ]; then
        warn "The prefix already exists. To recreate it, delete: $WINEPREFIX"
    else
        "$WINE" wineboot --init 2>/dev/null
        "$WINESERVER" --wait
        log "Prefix created"
    fi

    step "Windows 10"
    local key="HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion"
    "$WINE" reg add "$key" /v CurrentBuildNumber /t REG_SZ /d "19041" /f 2>/dev/null
    "$WINE" reg add "$key" /v CurrentVersion /t REG_SZ /d "10.0" /f 2>/dev/null
    "$WINE" reg add "$key" /v ProductName /t REG_SZ /d "Windows 10 Pro" /f 2>/dev/null
    "$WINE" reg add "$key" /v CSDVersion /t REG_SZ /d "" /f 2>/dev/null
    "$WINE" reg add "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Windows" \
        /v CSDVersion /t REG_DWORD /d 0 /f 2>/dev/null
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f 2>/dev/null
    "$WINESERVER" --wait
    log "Windows 10 set"
}

# Copy the translator DLLs into the prefix and make Wine load them instead of its own.
install_translators() {
    step "Installing the Direct3D translators in the prefix"
    local sys32="$WINEPREFIX/drive_c/windows/system32"
    local syswow64="$WINEPREFIX/drive_c/windows/syswow64"
    local dxvk="$DXVK_DIR/dxvk-${DXVK_VERSION}"
    local vkd3d="$DXVK_DIR/vkd3d-proton-${VKD3D_PROTON_VERSION}"
    local nvapi="$DXVK_DIR/dxvk-nvapi-v${DXVK_NVAPI_VERSION}"
    local dll

    for dll in d3d8 d3d9 d3d10core d3d11 dxgi; do
        [ -f "$dxvk/x64/$dll.dll" ] && cp "$dxvk/x64/$dll.dll" "$sys32/"
        [ -f "$dxvk/x32/$dll.dll" ] && cp "$dxvk/x32/$dll.dll" "$syswow64/"
    done
    for dll in d3d12 d3d12core; do
        cp "$vkd3d/x64/$dll.dll" "$sys32/"
        cp "$vkd3d/x86/$dll.dll" "$syswow64/"
    done
    cp "$nvapi/x64/nvapi64.dll" "$sys32/"
    [ -f "$nvapi/x64/nvofapi64.dll" ] && cp "$nvapi/x64/nvofapi64.dll" "$sys32/"
    [ -f "$nvapi/x32/nvapi.dll" ] && cp "$nvapi/x32/nvapi.dll" "$syswow64/"

    for dll in d3d8 d3d9 d3d10core d3d11 dxgi d3d12 d3d12core nvapi nvapi64 nvofapi64; do
        "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" \
            /v "$dll" /t REG_SZ /d "native,builtin" /f >/dev/null 2>&1
    done
    "$WINESERVER" --wait

    # Without this DXVK reports an AMD card and WoW asks for an NVIDIA one.
    if [ ! -f "$DXVK_CONFIG_FILE" ]; then
        cat > "$DXVK_CONFIG_FILE" << 'EOF'
# DXVK config for WoW (loaded through DXVK_CONFIG_FILE, see config.sh)

# Report the real NVIDIA GPU. By default DXVK reports an AMD card, and WoW then
# says it "requires an NVIDIA graphics card" and turns off Low Latency Mode.
dxgi.hideNvidiaGpu = False

# Graphics Pipeline Library removes most shader compile stutter on NVIDIA.
dxvk.enableGraphicsPipelineLibrary = Auto
EOF
        log "Wrote $DXVK_CONFIG_FILE"
    fi
    log "DXVK $DXVK_VERSION, vkd3d-proton $VKD3D_PROTON_VERSION and dxvk-nvapi $DXVK_NVAPI_VERSION installed"
}

install_dependencies() {
    step "Windows dependencies (vcrun2019, corefonts)"
    export PATH="$WINE_BIN_DIR:$PATH"
    winetricks -q --force vcrun2019 2>&1 | tail -3 || warn "vcrun2019 may need a manual install"
    winetricks -q --force corefonts 2>&1 | tail -3 || warn "corefonts: continuing without them"
    winetricks -q win10 2>&1 | tail -2
    "$WINESERVER" --wait
    log "Dependencies installed"

    step "Battle.net tweaks"
    # Disable the crash reporter (causes hangs)
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" /v "BNUpdate" /t REG_SZ /d "" /f 2>/dev/null
    # IE proxy settings (Battle.net needs them)
    "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" \
        /v ProxyEnable /t REG_DWORD /d 0 /f 2>/dev/null
    "$WINESERVER" --wait
    log "Tweaks applied"
}

install_battlenet() {
    step "Battle.net installer"
    if [ -f "$BATTLENET_INSTALLER" ]; then
        log "Installer already downloaded"
    else
        curl -fL --progress-bar -o "$BATTLENET_INSTALLER" \
            "https://www.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live"
    fi
    log "The Battle.net installer opens now. Install it normally."
    warn "IMPORTANT: when it finishes, close Battle.net completely, then use ./launch.sh"
    echo ""
    "$WINE" "$BATTLENET_INSTALLER" 2>"$WOW_LAUNCHER_DIR/logs/installer.log" &
    wait $! 2>/dev/null || true
    "$WINESERVER" --wait
}

main() {
    check_requirements
    install_wine
    download_translators
    create_prefix
    install_translators
    install_dependencies
    install_battlenet

    step "SETUP COMPLETE"
    log "Wine:         $WINE_VERSION Staging"
    log "DXVK:         $DXVK_VERSION"
    log "vkd3d-proton: $VKD3D_PROTON_VERSION"
    log "dxvk-nvapi:   $DXVK_NVAPI_VERSION"
    log "Prefix:       $WINEPREFIX"
    log ""
    log "Launch Battle.net with:  $SCRIPT_DIR/launch.sh"
}

# Run when executed; sourcing only loads the functions (used to test single steps).
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
