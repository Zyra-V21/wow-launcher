# wow-launcher

Battle.net + World of Warcraft launcher for Linux. Runs both **WoW Classic** and **WoW Retail** using Wine 11.4 Staging + DXVK 2.7.1.

Built because Lutris, Bottles, and other existing solutions kept failing to launch Battle.net properly.

## What it does

- Downloads and configures **Wine 11.4 Staging** (standalone, doesn't touch your system Wine)
- Installs **DXVK 2.7.1** for DirectX-to-Vulkan translation
- Creates an isolated Wine prefix with Windows 10 configuration
- Installs required Windows dependencies (vcrun2019, corefonts)
- Applies Battle.net-specific fixes (CEF rendering, digital signature bypass, IPv6 disable)
- Forces **NVIDIA discrete GPU** via PRIME render offload on hybrid laptops
- Enables **esync + fsync** for better performance
- Installs desktop entries so you can launch from your app menu

## Requirements

- Ubuntu 22.04+ (or any distro with recent glibc)
- NVIDIA GPU with proprietary drivers (tested on RTX 5060 Laptop, driver 590)
- Vulkan support (`libvulkan1`, `mesa-vulkan-drivers`)
- 32-bit NVIDIA libraries (`libnvidia-gl-XXX:i386`)
- `winetricks`, `cabextract`, `p7zip-full`

The setup script will check and install missing packages automatically.

## Quick start

```bash
git clone https://github.com/Zyra-V21/wow-launcher.git
cd wow-launcher
./setup.sh
```

The setup downloads everything (~600MB), creates the Wine prefix, and launches the Battle.net installer. Install Battle.net normally, then close it.

After that, always launch with:

```bash
./launch.sh
```

## Desktop integration

To add Battle.net, WoW Classic, and WoW Retail to your Linux app menu:

```bash
./install-desktop.sh
```

This creates `.desktop` entries with icons so you can search and launch them like any other app.

## Usage

```
./launch.sh                 # Launch Battle.net (default)
./launch.sh --wow-classic   # Launch WoW Classic directly
./launch.sh --wow-retail    # Launch WoW Retail directly
./launch.sh --kill          # Kill all Wine processes
./launch.sh --winecfg       # Open Wine configuration
./launch.sh --prefix        # Open the Wine prefix in file manager
./launch.sh --log           # View latest log file
./launch.sh --help          # Show all options
```

## Troubleshooting

Run the diagnostic tool:

```bash
./diagnose.sh
```

It checks GPU drivers, Vulkan, Wine, DXVK, Battle.net installation, esync limits, and more.

### Common issues

**Battle.net installer hangs at "Updating Battle.net Update Agent"**

This happens with old Wine versions (< 9.x). The setup script uses Wine 11.4 Staging which fixes this. If it still hangs, kill and retry -- the Agent sometimes needs a second attempt.

**Battle.net opens but shows a white/blank window**

The launcher already passes `--disable-gpu --no-sandbox` flags to fix CEF rendering. If it persists, check that `HardwareAcceleration` is set to `false` in:
```
~/wow-launcher/prefix/drive_c/users/<you>/AppData/Roaming/Battle.net/Battle.net.config
```

**esync warning**

Add to `/etc/security/limits.conf`:
```
your_username soft nofile 524288
your_username hard nofile 524288
```

Then log out and back in.

### AMD GPUs

This launcher is configured for NVIDIA PRIME offload. For AMD GPUs, edit `config.sh` and remove the NVIDIA-specific variables:

```bash
# Remove or comment out these lines:
# export __NV_PRIME_RENDER_OFFLOAD=1
# export __GLX_VENDOR_LIBRARY_NAME=nvidia
# export __VK_LAYER_NV_optimus=NVIDIA_only
# export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json
```

## File structure

```
config.sh              # All paths, versions, and environment variables
setup.sh               # One-time setup (downloads Wine, DXVK, creates prefix)
launch.sh              # Launcher for Battle.net and WoW
diagnose.sh            # Diagnostic tool for troubleshooting
install-desktop.sh     # Installs .desktop entries and icons for app menu
```

Everything installs to `~/wow-launcher/`. No system-wide changes except the packages installed by setup.

## License

MIT
