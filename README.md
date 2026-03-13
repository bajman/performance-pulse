# Performance Pulse

Liquid Glass-inspired macOS menu bar monitor with live CPU, memory, and download-speed charts.

<p align="center">
  <img src="assets/performance-pulse.png" alt="Performance Pulse screenshot" width="454" />
</p>

## Overview

Performance Pulse is a native SwiftUI menu bar app for macOS Tahoe that samples system CPU usage, memory usage, and current download speed in real time and renders compact live charts in a polished popover.

This is intentionally a menu bar utility, not a WidgetKit widget. WidgetKit timelines are not designed for true second-by-second updates, while a menu bar app can sample continuously and keep the graphs live.

## Features

- Live CPU usage sampling using Mach host statistics
- Live memory usage sampling using Mach VM statistics
- Live download-speed sampling using active network interface byte counters
- Swift Charts-based history graphs
- Tahoe-style Liquid Glass presentation with Reduce Transparency fallback
- Compact menu bar badges for CPU and memory at-a-glance

## Build And Run

```bash
swift run
```

You can also open the package in Xcode 26.4+ and run the `PerformancePulse` executable target.

## Install To Applications

```bash
./scripts/install_app.sh
```

## Test

```bash
swift test
```

## Tech Notes

- Requires macOS 26+
- Built with Swift 6, SwiftUI, and Charts
- The UI uses real glass only on the outer shell and control surfaces; chart cards stay more restrained to avoid over-glassing dense content
