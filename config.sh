#!/bin/bash
# WoW Classic TBC Launcher - Configuration

# Base directory
export WOW_LAUNCHER_DIR="$HOME/wow-launcher"

# Wine 11.4 Staging (Kron4ek build)
export WINE_VERSION="11.4"
export WINE_DIR="$WOW_LAUNCHER_DIR/wine-staging/wine-${WINE_VERSION}-staging-amd64"
export WINE="$WINE_DIR/bin/wine"
export WINE64="$WINE_DIR/bin/wine64"
export WINESERVER="$WINE_DIR/bin/wineserver"
export WINE_BIN_DIR="$WINE_DIR/bin"
export WINE_LIB_DIR="$WINE_DIR/lib"
export WINE_LIB64_DIR="$WINE_DIR/lib64"

# DXVK
export DXVK_VERSION="2.7.1"
export DXVK_DIR="$WOW_LAUNCHER_DIR/dxvk"

# Wine prefix (isolated from system Wine)
export WINEPREFIX="$WOW_LAUNCHER_DIR/prefix"
export WINEARCH="win64"

# Battle.net
export BATTLENET_INSTALLER="$WOW_LAUNCHER_DIR/Battle.net-Setup.exe"
export BATTLENET_EXE="$WINEPREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net.exe"

# GPU - force NVIDIA discrete GPU
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json

# Performance
export DXVK_ASYNC=1
export STAGING_SHARED_MEMORY=1
export WINE_LARGE_ADDRESS_AWARE=1
export DXVK_LOG_LEVEL=none
export WINEESYNC=1
export WINEFSYNC=1
export WINEDEBUG=-all

# DLL overrides for Battle.net compatibility
export WINEDLLOVERRIDES="wintrust=b;crypt32=b;dnsapi=b;iphlpapi=b"
