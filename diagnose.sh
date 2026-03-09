#!/bin/bash
# Diagnostic tool for WoW Classic launcher issues

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok() { echo -e "  ${GREEN}OK${NC}  $1"; }
fail() { echo -e "  ${RED}FAIL${NC}  $1"; ISSUES=$((ISSUES + 1)); }
warn() { echo -e "  ${YELLOW}WARN${NC}  $1"; }
ISSUES=0

echo -e "${CYAN}=== Diagnostico del WoW Classic Launcher ===${NC}"
echo ""

# 1. GPU & Drivers
echo -e "${CYAN}[GPU & Drivers]${NC}"
if nvidia-smi &>/dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null)
    DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null)
    ok "NVIDIA GPU: $GPU_NAME (driver $DRIVER)"
else
    fail "Driver NVIDIA no detectado"
fi

if [ -f /usr/share/vulkan/icd.d/nvidia_icd.json ]; then
    ok "Vulkan NVIDIA ICD presente"
else
    fail "Falta nvidia_icd.json - instala libnvidia-gl"
fi

# Check 32-bit NVIDIA
if dpkg -l libnvidia-gl-590:i386 &>/dev/null; then
    ok "Librerías NVIDIA 32-bit instaladas"
else
    fail "Faltan librerías NVIDIA 32-bit (libnvidia-gl-590:i386)"
fi

# Vulkan test
if command -v vulkaninfo &>/dev/null; then
    VK_DEVICES=$(VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json vulkaninfo --summary 2>/dev/null | grep "deviceName" | head -1)
    if [ -n "$VK_DEVICES" ]; then
        ok "Vulkan funciona: $VK_DEVICES"
    else
        fail "Vulkan no reporta dispositivos GPU"
    fi
else
    warn "vulkaninfo no instalado - instala vulkan-tools para verificar"
fi

echo ""

# 2. Wine-GE
echo -e "${CYAN}[Wine-GE]${NC}"
if [ -x "$WINE" ]; then
    WINE_VER=$("$WINE" --version 2>/dev/null)
    ok "Wine-GE: $WINE_VER"
else
    fail "Wine-GE no encontrado en: $WINE"
    # Try to find it
    FOUND=$(find "$WINE_GE_DIR" -name "wine" -type f -executable 2>/dev/null | head -1)
    if [ -n "$FOUND" ]; then
        warn "Encontrado en: $FOUND (actualiza config.sh)"
    fi
fi

echo ""

# 3. Wine Prefix
echo -e "${CYAN}[Wine Prefix]${NC}"
if [ -d "$WINEPREFIX/drive_c" ]; then
    ok "Prefix existe: $WINEPREFIX"

    # Check Windows version
    WIN_VER=$("$WINE" reg query "HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion" /v ProductName 2>/dev/null | grep -oP "Windows.*" || echo "desconocido")
    ok "Version Windows: $WIN_VER"
else
    fail "Prefix no existe - ejecuta ./setup.sh"
fi

# Check DXVK
if [ -f "$WINEPREFIX/drive_c/windows/system32/d3d11.dll" ]; then
    # Check if it's DXVK or builtin
    if strings "$WINEPREFIX/drive_c/windows/system32/d3d11.dll" 2>/dev/null | grep -qi dxvk; then
        ok "DXVK instalado en system32"
    else
        warn "d3d11.dll existe pero puede no ser DXVK"
    fi
else
    fail "DXVK no instalado en el prefix"
fi

echo ""

# 4. Battle.net
echo -e "${CYAN}[Battle.net]${NC}"
if [ -f "$BATTLENET_EXE" ]; then
    ok "Battle.net encontrado: $BATTLENET_EXE"
else
    ALT="$WINEPREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
    if [ -f "$ALT" ]; then
        ok "Battle.net Launcher encontrado (ruta alternativa)"
    else
        fail "Battle.net no instalado - ejecuta ./setup.sh"
    fi
fi

# Check for WoW
echo ""
echo -e "${CYAN}[WoW Classic]${NC}"
WOW_FOUND=false
for dir in "$WINEPREFIX/drive_c/Program Files (x86)/World of Warcraft/_classic_" \
           "$WINEPREFIX/drive_c/Program Files (x86)/World of Warcraft/_classic_era_"; do
    if [ -d "$dir" ]; then
        ok "Directorio WoW encontrado: $dir"
        WOW_FOUND=true
        for exe in WowClassic.exe Wow.exe WoW.exe; do
            [ -f "$dir/$exe" ] && ok "Ejecutable: $exe"
        done
    fi
done
if ! $WOW_FOUND; then
    warn "WoW Classic no instalado aun (instálalo desde Battle.net)"
fi

echo ""

# 5. System
echo -e "${CYAN}[Sistema]${NC}"
MEM_AVAIL=$(free -g | awk '/Mem:/ {print $7}')
ok "RAM disponible: ${MEM_AVAIL}GB"
DISK_AVAIL=$(df -BG /home 2>/dev/null | awk 'NR==2 {print $4}')
ok "Disco disponible: $DISK_AVAIL"

# Check esync
NOFILE_LIMIT=$(ulimit -n 2>/dev/null)
if [ "$NOFILE_LIMIT" -ge 524288 ] 2>/dev/null; then
    ok "ulimit -n: $NOFILE_LIMIT (esync OK)"
else
    warn "ulimit -n: $NOFILE_LIMIT (esync necesita >= 524288)"
    warn "Anade a /etc/security/limits.conf:"
    warn "  $USER soft nofile 524288"
    warn "  $USER hard nofile 524288"
fi

echo ""
echo -e "${CYAN}=== Resultado ===${NC}"
if [ "$ISSUES" -eq 0 ]; then
    echo -e "${GREEN}Todo OK - sin problemas detectados${NC}"
else
    echo -e "${RED}Se encontraron $ISSUES problemas. Revisa los mensajes FAIL arriba.${NC}"
fi
