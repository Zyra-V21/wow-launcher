#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON_DIR="$HOME/.local/share/icons"
APP_DIR="$HOME/.local/share/applications"

GREEN='\033[0;32m'
NC='\033[0m'
log() { echo -e "${GREEN}[+]${NC} $1"; }

mkdir -p "$ICON_DIR" "$APP_DIR"

# Download icons
log "Descargando iconos..."
curl -sL --connect-timeout 10 --max-time 15 \
    "https://e7.pngegg.com/pngimages/338/572/png-clipart-battle-net-world-of-warcraft-overwatch-computer-icons-blizzard-entertainment-world-of-warcraft-leaf-text.png" \
    -o "$ICON_DIR/battlenet.png"
curl -sL --connect-timeout 10 --max-time 15 \
    "https://www.clipartmax.com/png/middle/145-1450959_icon-world-of-warcraft-classic-icon-world-of-warcraft-classic.png" \
    -o "$ICON_DIR/wow-classic.png"
log "Iconos descargados"

# Battle.net
cat > "$APP_DIR/battlenet.desktop" << EOF
[Desktop Entry]
Name=Battle.net
Comment=Blizzard Battle.net Launcher (Wine)
Exec=$SCRIPT_DIR/launch.sh --battlenet
Icon=$ICON_DIR/battlenet.png
Terminal=false
Type=Application
Categories=Game;
Keywords=blizzard;battlenet;wow;warcraft;
StartupWMClass=battle.net.exe
EOF

# WoW Classic
cat > "$APP_DIR/wow-classic.desktop" << EOF
[Desktop Entry]
Name=WoW Classic
Comment=World of Warcraft Classic (Wine)
Exec=$SCRIPT_DIR/launch.sh --wow-classic
Icon=$ICON_DIR/wow-classic.png
Terminal=false
Type=Application
Categories=Game;
Keywords=wow;warcraft;classic;mmorpg;
StartupWMClass=wowclassic.exe
EOF

# WoW Retail
cat > "$APP_DIR/wow-retail.desktop" << EOF
[Desktop Entry]
Name=WoW Retail
Comment=World of Warcraft Retail (Wine)
Exec=$SCRIPT_DIR/launch.sh --wow-retail
Icon=$ICON_DIR/wow-classic.png
Terminal=false
Type=Application
Categories=Game;
Keywords=wow;warcraft;retail;mmorpg;
StartupWMClass=wow.exe
EOF

chmod +x "$APP_DIR/battlenet.desktop" "$APP_DIR/wow-classic.desktop" "$APP_DIR/wow-retail.desktop"
update-desktop-database "$APP_DIR" 2>/dev/null || true

log "Accesos directos instalados:"
log "  - Battle.net"
log "  - WoW Classic"
log "  - WoW Retail"
log "Ya puedes buscarlos en el menu de aplicaciones."
