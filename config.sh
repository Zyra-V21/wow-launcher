#!/bin/bash
# WoW Launcher - configuration: paths, versions and environment.

# Base directory (override with WOW_LAUNCHER_DIR=... to install elsewhere)
export WOW_LAUNCHER_DIR="${WOW_LAUNCHER_DIR:-$HOME/wow-launcher}"

# Wine (Kron4ek's standalone Wine Staging build, does not touch system Wine)
export WINE_VERSION="11.4"
export WINE_DIR="$WOW_LAUNCHER_DIR/wine-staging/wine-${WINE_VERSION}-staging-amd64"
export WINE_URL="https://github.com/Kron4ek/Wine-Builds/releases/download/${WINE_VERSION}/wine-${WINE_VERSION}-staging-amd64.tar.xz"
export WINE="$WINE_DIR/bin/wine"
export WINE64="$WINE_DIR/bin/wine64"
export WINESERVER="$WINE_DIR/bin/wineserver"
export WINE_BIN_DIR="$WINE_DIR/bin"
export WINE_LIB_DIR="$WINE_DIR/lib"
export WINE_LIB64_DIR="$WINE_DIR/lib64"

# Direct3D -> Vulkan translators
#   DXVK          -> D3D9/10/11
#   vkd3d-proton  -> D3D12 (WoW Forever and Retail render with DX12)
#   dxvk-nvapi    -> NVAPI (NVIDIA detection, Reflex / Low Latency Mode)
export DXVK_VERSION="3.1.1"
export VKD3D_PROTON_VERSION="3.0.1"
export DXVK_NVAPI_VERSION="0.9.2"
export DXVK_URL="https://github.com/doitsujin/dxvk/releases/download/v${DXVK_VERSION}/dxvk-${DXVK_VERSION}.tar.gz"
export VKD3D_PROTON_URL="https://github.com/HansKristian-Work/vkd3d-proton/releases/download/v${VKD3D_PROTON_VERSION}/vkd3d-proton-${VKD3D_PROTON_VERSION}.tar.zst"
export DXVK_NVAPI_URL="https://github.com/jp7677/dxvk-nvapi/releases/download/v${DXVK_NVAPI_VERSION}/dxvk-nvapi-v${DXVK_NVAPI_VERSION}.tar.gz"
export DXVK_DIR="$WOW_LAUNCHER_DIR/dxvk"

# Wine prefix (isolated from system Wine)
export WINEPREFIX="$WOW_LAUNCHER_DIR/prefix"
export WINEARCH="win64"

# Battle.net
export BATTLENET_INSTALLER="$WOW_LAUNCHER_DIR/Battle.net-Setup.exe"
export BATTLENET_EXE="$WINEPREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net.exe"

# ---------------------------------------------------------------------------
# GPU: force the discrete NVIDIA GPU (PRIME render offload on hybrid laptops)
# ---------------------------------------------------------------------------
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
# VK_ICD_FILENAMES is deprecated; kept for older Vulkan loaders
export VK_DRIVER_FILES=/usr/share/vulkan/icd.d/nvidia_icd.json
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json

# ---------------------------------------------------------------------------
# DXVK
# ---------------------------------------------------------------------------
# dxvk.conf turns off dxgi.hideNvidiaGpu: by default DXVK reports an AMD card,
# and WoW then says it "requires an NVIDIA graphics card" and turns off Low
# Latency Mode. setup.sh writes it.
export DXVK_CONFIG_FILE="$WOW_LAUNCHER_DIR/dxvk.conf"
# NVAPI through dxvk-nvapi. The driver version it reports to the game is
# pinned to 580.17, the one this setup is tested with; remove the line to
# report your real driver.
export DXVK_ENABLE_NVAPI=1
export DXVK_NVAPI_DRIVER_VERSION=58017
export DXVK_STATE_CACHE_PATH="$WOW_LAUNCHER_DIR/cache/dxvk"
export DXVK_LOG_LEVEL=info
export DXVK_LOG_PATH="$WOW_LAUNCHER_DIR/logs"
# DXVK_ASYNC only exists in the "async" fork; upstream DXVK 3.x avoids shader
# stutter with Graphics Pipeline Library, on by default.

# ---------------------------------------------------------------------------
# vkd3d-proton (D3D12)
# ---------------------------------------------------------------------------
export VKD3D_SHADER_CACHE_PATH="$WOW_LAUNCHER_DIR/cache/vkd3d"
export VKD3D_DEBUG=warn
# DXR 1.1 is on by default in vkd3d-proton 3.x. To turn it off:
#   export VKD3D_CONFIG=nodxr

# NVIDIA driver shader cache (also used by Vulkan)
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SIZE=$((4 * 1024 * 1024 * 1024))
export __GL_SHADER_DISK_CACHE_PATH="$WOW_LAUNCHER_DIR/cache/nvidia"
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1

# ---------------------------------------------------------------------------
# Wine / performance
# ---------------------------------------------------------------------------
export STAGING_SHARED_MEMORY=1
export WINE_LARGE_ADDRESS_AWARE=1
export WINEESYNC=1
export WINEFSYNC=1
export WINEDEBUG=-all

# DLL overrides for Battle.net compatibility
export WINEDLLOVERRIDES="wintrust=b;crypt32=b;dnsapi=b;iphlpapi=b"

# gamemoderun: inhibits the screensaver and sets the CPU governor while playing
if command -v gamemoderun >/dev/null 2>&1; then
    export GAMEMODE_CMD="gamemoderun"
else
    export GAMEMODE_CMD=""
fi
