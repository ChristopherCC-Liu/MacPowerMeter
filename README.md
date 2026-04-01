# MacPowerMeter

macOS menu bar system monitor -- real-time power consumption, CPU usage, and RAM usage with custom vector icons and gradient energy bars.

```
 PowerIcon 12.3W | CPUIcon 23% | MemoryIcon 67%
```

## Features

- **Real-time monitoring** -- Power (W), CPU (%), RAM (%) in the menu bar
- **Custom vector icons** -- Hand-drawn lightning bolt, chip, and DIMM shapes (no emoji, no SF Symbols)
- **Gradient energy bars** -- Capsule-shaped progress bars with spring animation
  - Power: orange to yellow
  - CPU: blue to cyan
  - RAM: green to mint
  - Turns red at >80%, pulses at >95%
- **Detail panel** -- Click to see breakdowns (CPU/GPU/ANE power, per-core CPU, Active/Wired/Compressed memory)
- **Trend charts** -- Mini line charts with 60-sample history (Swift Charts)
- **Configurable** -- Choose which metrics to display, adjust refresh interval (1-10s)
- **Low overhead** -- Target: <20MB memory, <1% CPU
- **Menu bar only** -- No Dock icon (LSUIElement)

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac
- Xcode Command Line Tools (`xcode-select --install`)

## Install

### First time install

```bash
# 1. Clone the repo
git clone https://github.com/ChristopherCC-Liu/MacPowerMeter.git

# 2. Enter the directory
cd MacPowerMeter

# 3. Run the installer (builds + installs + creates CLI command)
#    You will be prompted for your password (needed to create /usr/local/bin/powermeter)
./install.sh
```

### Update to latest version

If you already have a `MacPowerMeter` directory from a previous install:

```bash
# Enter your existing directory
cd MacPowerMeter

# Pull the latest changes
git pull origin main

# Reinstall
./install.sh
```

### If you get "directory already exists" error

```bash
# Option A: Remove old directory and start fresh
rm -rf MacPowerMeter
git clone https://github.com/ChristopherCC-Liu/MacPowerMeter.git
cd MacPowerMeter
./install.sh

# Option B: Update inside the existing directory
cd MacPowerMeter
git pull origin main
./install.sh
```

### What the installer does

1. Compiles the release binary via Swift Package Manager (`swift build --configuration release`)
2. Creates a `.app` bundle with proper Info.plist
3. Copies the `.app` to `/Applications/MacPowerMeter.app`
4. Creates a `powermeter` CLI command at `/usr/local/bin/powermeter`

## Usage

After installation, use any of these methods to launch:

```bash
# From terminal
powermeter              # Launch (appears in menu bar)
powermeter stop         # Quit the app
powermeter status       # Check if running
powermeter help         # Show all commands
```

Or launch from **Spotlight**: press Cmd+Space, type "MacPowerMeter", hit Enter.

Or double-click `/Applications/MacPowerMeter.app` in Finder.

The app appears as an icon in your menu bar (no Dock icon). Click it to open the detail panel.

## Settings

Click the menu bar item to open the detail panel. At the bottom you'll find settings:

- **Refresh interval** -- 1 / 2 / 5 / 10 seconds
- **Status Bar** -- Toggle power, CPU, RAM display independently
- **Launch at Login** -- Start automatically on boot
- **Quit** -- Exit the app

Settings take effect immediately and persist across app restarts.

## Uninstall

```bash
cd MacPowerMeter
./install.sh uninstall
```

This removes `/Applications/MacPowerMeter.app` and `/usr/local/bin/powermeter`.

## Architecture

```
MacPowerMeter/
  Models/         SystemMetrics (immutable struct) + MetricsHistory (ring buffer, 60 samples)
  Collectors/     CPUCollector (Mach API) / MemoryCollector (vm_statistics64) / PowerCollector (strategy)
  Engine/         MetricsEngine actor -- async let parallel collection, AsyncStream output
  ViewModels/     @Observable ViewModel -- subscribes to engine, drives UI
  Views/
    Icons/        PowerIcon / CPUIcon / MemoryIcon (SwiftUI Shape + Path)
    Components/   EnergyBar (gradient capsule) / MiniChart (Swift Charts)
    ...           StatusBarLabel / MetricsPanel / SettingsView
  Theme/          ColorTheme (3 color schemes, light/dark adaptive)
  Utilities/      LaunchAtLogin (SMAppService)
```

### Data Flow

```
CPUCollector  ---+
MemoryCollector -+--> MetricsEngine (actor) --> AsyncStream --> MetricsViewModel (@Observable) --> SwiftUI
PowerCollector --+
```

### Power Monitoring

Power data collection uses a strategy pattern with automatic fallback:

1. **IOReport** (primary) -- Apple's private framework for energy model data. Provides per-component breakdown (CPU/GPU/ANE). Loaded dynamically via `dlopen`.
2. **SMC** (fallback) -- Direct AppleSMC access via IOKit. Reads hardware power keys (PSTR, PHPC, PCPG). Works when IOReport is unavailable.
3. **Degraded mode** -- If both methods fail, the power section is hidden automatically.

Supports both Apple Silicon (little-endian SMC) and Intel Mac (big-endian SMC).

## Build from Source

```bash
# Debug build
swift build

# Release build
swift build --configuration release

# Run directly (without .app bundle)
.build/release/MacPowerMeter

# Create .app bundle only (without installing to /Applications)
./create-app-bundle.sh
```

## Troubleshooting

**"zsh: no such file or directory: ./install.sh"**
Make sure you are inside the `MacPowerMeter` directory: `cd MacPowerMeter`

**"destination path already exists"**
You already have the directory. Update instead: `cd MacPowerMeter && git pull origin main && ./install.sh`

**Power shows 0W or is hidden**
Power monitoring requires non-sandboxed execution. If running from Xcode, disable App Sandbox. The installed `.app` bundle is non-sandboxed by default.

**Build fails with "swift: command not found"**
Install Xcode Command Line Tools: `xcode-select --install`

## License

MIT
