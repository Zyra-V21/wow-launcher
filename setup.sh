#!/bin/bash
set -euo pipefail

# Colors for output
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

# ─────────────────────────────────────────────
# Step 0: Verify system requirements
# ─────────────────────────────────────────────
step "Verificando requisitos del sistema"

# Check NVIDIA driver
if ! nvidia-smi &>/dev/null; then
    err "No se detecta el driver NVIDIA. Instálalo primero."
fi
log "Driver NVIDIA detectado: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader)"

# Check Vulkan ICD
if [ ! -f /usr/share/vulkan/icd.d/nvidia_icd.json ]; then
    err "No se encuentra nvidia_icd.json. Instala: sudo apt install libnvidia-gl-590"
fi
log "Vulkan NVIDIA ICD encontrado"

# Check 32-bit libraries
if ! dpkg -l | grep -q "libnvidia-gl-590:i386"; then
    warn "Faltan las librerías 32-bit de NVIDIA. Instalando..."
    sudo apt install -y libnvidia-gl-590:i386 libnvidia-compute-590:i386
fi
log "Librerías 32-bit NVIDIA OK"

# Check required packages
REQUIRED_PKGS="cabextract p7zip-full vulkan-tools"
MISSING=""
for pkg in $REQUIRED_PKGS; do
    if ! dpkg -l "$pkg" &>/dev/null; then
        MISSING="$MISSING $pkg"
    fi
done
if [ -n "$MISSING" ]; then
    log "Instalando paquetes necesarios:$MISSING"
    sudo apt install -y $MISSING
fi
log "Paquetes del sistema OK"

# ─────────────────────────────────────────────
# Step 1: Create directory structure
# ─────────────────────────────────────────────
step "Creando estructura de directorios"
mkdir -p "$WOW_LAUNCHER_DIR"/{wine-ge,dxvk,downloads,logs}
log "Directorios creados en $WOW_LAUNCHER_DIR"

# ─────────────────────────────────────────────
# Step 2: Download and install Wine-GE
# ─────────────────────────────────────────────
step "Descargando Wine-GE ($WINE_GE_VERSION)"

WINE_GE_ARCHIVE="$WOW_LAUNCHER_DIR/downloads/wine-ge-${WINE_GE_VERSION}.tar.xz"

if [ -x "$WINE" ]; then
    log "Wine-GE ya está instalado, saltando..."
else
    if [ ! -f "$WINE_GE_ARCHIVE" ]; then
        log "Descargando Wine-GE desde GitHub..."
        curl -L --progress-bar -o "$WINE_GE_ARCHIVE" "$WINE_GE_URL"
    fi
    log "Extrayendo Wine-GE..."
    tar -xf "$WINE_GE_ARCHIVE" -C "$WINE_GE_DIR/"
    if [ -x "$WINE" ]; then
        log "Wine-GE instalado correctamente"
    else
        # Try to find the actual binary path
        FOUND_WINE=$(find "$WINE_GE_DIR" -name "wine" -type f -executable | head -1)
        if [ -n "$FOUND_WINE" ]; then
            log "Wine-GE encontrado en: $FOUND_WINE"
            warn "La ruta del binario difiere. Actualiza config.sh si es necesario."
        else
            err "No se encontró el binario de Wine-GE después de extraer"
        fi
    fi
fi

# Verify wine works
log "Verificando Wine-GE..."
"$WINE" --version 2>/dev/null || err "Wine-GE no funciona. Revisa los logs."
log "Wine-GE version: $("$WINE" --version 2>/dev/null)"

# ─────────────────────────────────────────────
# Step 3: Download DXVK
# ─────────────────────────────────────────────
step "Descargando DXVK ($DXVK_VERSION)"

DXVK_ARCHIVE="$WOW_LAUNCHER_DIR/downloads/dxvk-${DXVK_VERSION}.tar.gz"

if [ -d "$DXVK_DIR/dxvk-${DXVK_VERSION}" ]; then
    log "DXVK ya está descargado, saltando..."
else
    if [ ! -f "$DXVK_ARCHIVE" ]; then
        log "Descargando DXVK..."
        curl -L --progress-bar -o "$DXVK_ARCHIVE" "$DXVK_URL"
    fi
    log "Extrayendo DXVK..."
    tar -xzf "$DXVK_ARCHIVE" -C "$DXVK_DIR/"
    log "DXVK extraído"
fi

# ─────────────────────────────────────────────
# Step 4: Create Wine prefix
# ─────────────────────────────────────────────
step "Creando Wine prefix (win64)"

if [ -d "$WINEPREFIX/drive_c" ]; then
    warn "El prefix ya existe. Si quieres recrearlo, borra: $WINEPREFIX"
else
    log "Inicializando prefix en $WINEPREFIX..."
    "$WINE" wineboot --init 2>/dev/null
    "$WINESERVER" --wait
    log "Prefix creado"
fi

# ─────────────────────────────────────────────
# Step 5: Set Windows version to Windows 10
# ─────────────────────────────────────────────
step "Configurando Windows 10"

"$WINE" reg add "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion" \
    /v CurrentBuildNumber /t REG_SZ /d "19041" /f 2>/dev/null
"$WINE" reg add "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion" \
    /v CurrentVersion /t REG_SZ /d "10.0" /f 2>/dev/null
"$WINE" reg add "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion" \
    /v ProductName /t REG_SZ /d "Windows 10 Pro" /f 2>/dev/null
"$WINE" reg add "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion" \
    /v CSDVersion /t REG_SZ /d "" /f 2>/dev/null
"$WINE" reg add "HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Windows" \
    /v CSDVersion /t REG_DWORD /d 0 /f 2>/dev/null

# Set default Windows version in winecfg
"$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine" \
    /v Version /t REG_SZ /d "win10" /f 2>/dev/null

"$WINESERVER" --wait
log "Windows 10 configurado"

# ─────────────────────────────────────────────
# Step 6: Install DXVK into prefix
# ─────────────────────────────────────────────
step "Instalando DXVK en el prefix"

DXVK_SETUP="$DXVK_DIR/dxvk-${DXVK_VERSION}/setup_dxvk.sh"
if [ -f "$DXVK_SETUP" ]; then
    export PATH="$WINE_BIN_DIR:$PATH"
    bash "$DXVK_SETUP" install 2>&1 | tail -5
    log "DXVK instalado en el prefix"
else
    # Manual DXVK installation
    log "Instalando DXVK manualmente..."
    DXVK_BASE="$DXVK_DIR/dxvk-${DXVK_VERSION}"
    SYS32="$WINEPREFIX/drive_c/windows/system32"
    SYSWOW64="$WINEPREFIX/drive_c/windows/syswow64"

    for dll in d3d9 d3d10core d3d11 dxgi; do
        [ -f "$DXVK_BASE/x64/${dll}.dll" ] && cp -v "$DXVK_BASE/x64/${dll}.dll" "$SYS32/"
        [ -f "$DXVK_BASE/x32/${dll}.dll" ] && cp -v "$DXVK_BASE/x32/${dll}.dll" "$SYSWOW64/"
    done

    # Set DLL overrides
    for dll in d3d9 d3d10core d3d11 dxgi; do
        "$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" \
            /v "$dll" /t REG_SZ /d "native,builtin" /f 2>/dev/null
    done
    log "DXVK DLLs copiados y overrides configurados"
fi

"$WINESERVER" --wait

# ─────────────────────────────────────────────
# Step 7: Install Windows dependencies
# ─────────────────────────────────────────────
step "Instalando dependencias de Windows (vcrun, corefonts, etc.)"

export PATH="$WINE_BIN_DIR:$PATH"

# Use winetricks with our Wine-GE
WINETRICKS_WINE="$WINE"
log "Instalando Visual C++ runtimes..."
winetricks -q --force vcrun2019 2>&1 | tail -3 || warn "vcrun2019 puede que necesite instalación manual"

log "Instalando corefonts..."
winetricks -q --force corefonts 2>&1 | tail -3 || warn "corefonts: continuando sin ellas"

log "Instalando win10 mode via winetricks..."
winetricks -q win10 2>&1 | tail -2

"$WINESERVER" --wait
log "Dependencias instaladas"

# ─────────────────────────────────────────────
# Step 8: Battle.net specific registry tweaks
# ─────────────────────────────────────────────
step "Aplicando tweaks para Battle.net"

# Disable crash reporter (causes hangs)
"$WINE" reg add "HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides" \
    /v "BNUpdate" /t REG_SZ /d "" /f 2>/dev/null

# IE proxy settings (Battle.net needs this)
"$WINE" reg add "HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" \
    /v ProxyEnable /t REG_DWORD /d 0 /f 2>/dev/null

# Renderer: force DX11 for WoW (works best with DXVK)
mkdir -p "$WINEPREFIX/drive_c/users/$USER/Application Data/Battle.net"

"$WINESERVER" --wait
log "Tweaks aplicados"

# ─────────────────────────────────────────────
# Step 9: Download Battle.net installer
# ─────────────────────────────────────────────
step "Descargando instalador de Battle.net"

if [ -f "$BATTLENET_INSTALLER" ]; then
    log "Instalador ya descargado"
else
    log "Descargando Battle.net-Setup.exe..."
    curl -L --progress-bar -o "$BATTLENET_INSTALLER" \
        "https://www.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live"
    log "Instalador descargado"
fi

# ─────────────────────────────────────────────
# Step 10: Run Battle.net installer
# ─────────────────────────────────────────────
step "Lanzando instalador de Battle.net"
log "Se abrirá el instalador de Battle.net."
log "Instálalo normalmente (siguiente, siguiente, etc.)"
log ""
warn "IMPORTANTE: Cuando el instalador termine, cierra Battle.net completamente"
warn "antes de continuar. Luego usa ./launch.sh para lanzarlo."
echo ""

"$WINE" "$BATTLENET_INSTALLER" 2>"$WOW_LAUNCHER_DIR/logs/installer.log" &
INSTALLER_PID=$!

log "Instalador lanzado (PID: $INSTALLER_PID)"
log "Esperando a que termine..."
wait $INSTALLER_PID 2>/dev/null || true
"$WINESERVER" --wait

# ─────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────
echo ""
step "INSTALACION COMPLETADA"
log "Wine-GE:  $WINE_GE_VERSION"
log "DXVK:     $DXVK_VERSION"
log "Prefix:   $WINEPREFIX"
log ""
log "Para lanzar Battle.net:"
log "  cd $SCRIPT_DIR && ./launch.sh"
log ""
log "Para lanzar WoW Classic TBC directamente (una vez instalado):"
log "  cd $SCRIPT_DIR && ./launch.sh --wow"
echo ""
