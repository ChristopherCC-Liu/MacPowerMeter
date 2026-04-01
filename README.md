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
- **Low overhead** -- Target: <20MB memory, <1% CPU
- **Menu bar only** -- No Dock icon (LSUIElement)

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel Mac
- Swift 5.9+ / Xcode 15+ (for building from source)

## Install from GitHub

```bash
git clone https://github.com/ChristopherCC-Liu/MacPowerMeter.git
cd MacPowerMeter
./install.sh
```

This will:
1. Build the release binary via Swift Package Manager
2. Create a `.app` bundle and copy it to `/Applications/`
3. Install a `powermeter` CLI command to `/usr/local/bin/`

## Usage

```bash
powermeter          # Launch (appears in menu bar)
powermeter stop     # Quit
powermeter status   # Check if running
```

Or launch from Spotlight: search "MacPowerMeter".

## Uninstall

```bash
cd MacPowerMeter
./install.sh uninstall
```

## Architecture

```
MacPowerMeter/
  Models/         SystemMetrics (immutable struct) + MetricsHistory (ring buffer, 60 samples)
  Collectors/     CPUCollector (Mach API) / MemoryCollector (vm_statistics64) / PowerCollector (IOReport)
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

Power data is collected via Apple's private `IOReport` framework, loaded dynamically with `dlopen`. If IOReport is unavailable (e.g., sandboxed environment), power metrics gracefully degrade to 0 and the power section is hidden.

## Settings

Click the menu bar item to open the detail panel, then adjust:

- **Refresh interval** -- 1 / 2 / 5 / 10 seconds
- **Visible metrics** -- Toggle power, CPU, RAM independently
- **Launch at Login** -- Start automatically on boot

## Build from Source

```bash
# Debug build
swift build

# Release build
swift build --configuration release

# Run directly (without .app bundle)
.build/release/MacPowerMeter

# Create .app bundle only (no install)
./create-app-bundle.sh
```

## License

MIT
