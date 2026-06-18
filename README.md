# MacStats

![macOS](https://img.shields.io/badge/macOS-14.0%2B-brightgreen)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/License-MIT-blue)

> macOS 菜单栏系统监控工具 — CPU、内存、GPU、网络、磁盘、电池，一览无余

![Screenshot](screenshot.png)

<details>
<summary>🇨🇳 中文</summary>

## 功能

- CPU 实时使用率 + 进度条
- 内存用量 / 总量 + 进度条
- GPU 型号显示
- 网络上行/下行实时速度
- 内网 IP + 公网 IP
- 磁盘剩余容量 + 使用率
- 电池循环次数 + 健康度 + 充电状态

## 安装

### 快速开始

从 [Releases](https://github.com/alazymerlin/MacStats/releases) 下载最新版 `MacStats.app`，拖入 `/Applications` 文件夹，双击运行。菜单栏出现绿色 CPU 图标，点击查看所有系统状态。

### 从源码构建

```bash
# 使用 Xcode (推荐)
xcodegen generate
xcodebuild -project MacStats.xcodeproj -scheme MacStats -configuration Release build

# 或使用 SwiftPM
swift build -c release

# 安装到 /Applications
cp -R .build/release/MacStats.app /Applications/
```

### 前提条件

- macOS 14.0+ (Sonoma)
- Xcode 16+ (如需自行编译)
- 无需开发者账号即可运行

## 使用说明

| 操作 | 说明 |
|---|---|
| 点击菜单栏 CPU 图标 | 展开 / 收起面板 |
| 点击「设置 ▼」 | 展开选项（显示 CPU 百分比等） |
| 点击「退出」 | 关闭应用 |

所有数据每 **2 秒** 自动刷新一次，公网 IP 每 **2 分钟** 刷新一次。

## 技术栈

- **SwiftUI** — 菜单栏界面 (`MenuBarExtra` on macOS 14+)
- **CoreGraphics** — 自定义 app 图标（绿色 CPU 芯片）
- **IOKit** — 读取电池循环次数、健康度等硬件数据
- **Mach API** — CPU、内存占用率
- **ifaddrs** — 内网 IP、网络速度
- **URLSession** — 公网 IP (api.ipify.org)
- **pmset** — 电池存在检测

## 项目结构

```
MacStats/
├── Sources/
│   └── MacStats/
│       ├── MacStatsApp.swift    # App 入口 + UI
│       ├── SystemMonitor.swift  # 系统数据采集
│       ├── Info.plist
│       └── Resources/
│           └── MacStats.icns    # App 图标
├── project.yml                  # xcodegen 配置
├── Package.swift                # SwiftPM 配置
└── Scripts/
    ├── install.sh
    └── launch.sh
```

## 数据来源

- **CPU**: `host_statistics()` (Mach)
- **Memory**: `host_statistics64()` (Mach)
- **GPU**: `Metal` / `MTLCreateSystemDefaultDevice()`
- **Network**: `getifaddrs()` + delta calculation
- **IP**: `getnameinfo()` (local), `api.ipify.org` (public)
- **Disk**: `FileManager.attributesOfFileSystem()`
- **Battery**: IOKit `AppleSmartBattery` service + `pmset -g batt`

## 许可

MIT License

Copyright © 2026 MaoYF

</details>

<details>
<summary>🇬🇧 English</summary>

## Features

- Real-time CPU usage with progress bar
- Memory usage with progress bar
- GPU model name
- Real-time upload & download speed
- Local & public IP address
- Disk free space & usage
- Battery cycle count, health & charging status

## Installation

### Quick Start

Download the latest `MacStats.app` from [Releases](https://github.com/alazymerlin/MacStats/releases), drag it into `/Applications`, and double-click to run. A green CPU icon appears in the menu bar — click to view all system stats.

### Build from Source

```bash
# Using Xcode (recommended)
xcodegen generate
xcodebuild -project MacStats.xcodeproj -scheme MacStats -configuration Release build

# Or using SwiftPM
swift build -c release

# Install to /Applications
cp -R .build/release/MacStats.app /Applications/
```

### Prerequisites

- macOS 14.0+ (Sonoma)
- Xcode 16+ (if building from source)
- No developer account required

## Usage

| Action | Description |
|---|---|
| Click menu bar CPU icon | Toggle panel |
| Click "Settings ▼" | Expand options |
| Click "Quit" | Exit the app |

All data refreshes every **2 seconds**; public IP refreshes every **2 minutes**.

## Tech Stack

- **SwiftUI** — Menu bar interface (`MenuBarExtra` on macOS 14+)
- **CoreGraphics** — Custom app icon (green CPU chip)
- **IOKit** — Battery cycle count, health, hardware data
- **Mach API** — CPU & memory usage
- **ifaddrs** — Local IP & network speed
- **URLSession** — Public IP via api.ipify.org
- **pmset** — Battery presence check

## Project Structure

```
MacStats/
├── Sources/
│   └── MacStats/
│       ├── MacStatsApp.swift    # App entry + UI
│       ├── SystemMonitor.swift  # System data collection
│       ├── Info.plist
│       └── Resources/
│           └── MacStats.icns    # App icon
├── project.yml                  # xcodegen config
├── Package.swift                # SwiftPM config
└── Scripts/
    ├── install.sh
    └── launch.sh
```

## Data Sources

- **CPU**: `host_statistics()` (Mach)
- **Memory**: `host_statistics64()` (Mach)
- **GPU**: `Metal` / `MTLCreateSystemDefaultDevice()`
- **Network**: `getifaddrs()` + delta calculation
- **IP**: `getnameinfo()` (local), `api.ipify.org` (public)
- **Disk**: `FileManager.attributesOfFileSystem()`
- **Battery**: IOKit `AppleSmartBattery` service + `pmset -g batt`

## License

MIT License

Copyright © 2026 MaoYF

</details>
