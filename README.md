# MacStats

![macOS](https://img.shields.io/badge/macOS-14.0%2B-brightgreen)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/License-MIT-blue)

> macOS 菜单栏系统监控工具 — CPU、内存、GPU、网络、磁盘、电池，一览无余
>
> A lightweight macOS menu bar system monitor — CPU, memory, GPU, network, disk, battery all in one place

---

## 功能 Features

| 中文 | English |
|---|---|
| CPU 实时使用率 + 进度条 | Real-time CPU usage with progress bar |
| 内存用量 / 总量 + 进度条 | Memory usage with progress bar |
| GPU 型号显示 | GPU model name |
| 网络上行/下行实时速度 | Real-time upload & download speed |
| 内网 IP + 公网 IP | Local & public IP address |
| 磁盘剩余容量 + 使用率 | Disk free space & usage |
| 电池循环次数 + 健康度 + 充电状态 | Battery cycle count, health & charging status |

## 截图 Screenshot

![Screenshot](https://via.placeholder.com/320x480?text=MacStats+Menu+Bar)

*(菜单栏弹出面板展示所有系统信息 / Menu bar popover showing all system stats)*

## 安装 Installation

### 快速开始 Quick Start

1. 从 [Releases](https://github.com/alazymerlin/MacStats/releases) 下载最新版 `MacStats.app`
2. 拖入 `/Applications` 文件夹，双击运行
3. 菜单栏出现绿色 CPU 图标，点击查看所有系统状态

### 从源码构建 Build from Source

```bash
# 使用 Xcode (推荐)
xcodegen generate
xcodebuild -project MacStats.xcodeproj -scheme MacStats -configuration Release build

# 或使用 SwiftPM
swift build -c release

# 安装到 /Applications
cp -R .build/release/MacStats.app /Applications/
```

### 前提条件 Prerequisites

- macOS 14.0+ (Sonoma)
- Xcode 16+ (如需自行编译)
- 无需开发者账号即可运行

## 使用 Usage

| 操作 Action | 说明 Description |
|---|---|
| 点击菜单栏 CPU 图标 | 展开/收起面板 |
| 点击「设置 ▼」 | 展开选项（显示 CPU 百分比等） |
| 点击「退出」 | 关闭应用 |

所有数据每 **2 秒** 自动刷新一次，公网 IP 每 **2 分钟** 刷新一次。

## 技术栈 Tech Stack

- **SwiftUI** — 菜单栏界面 (`MenuBarExtra` on macOS 14+)
- **CoreGraphics** — 自定义 app 图标（绿色 CPU 芯片）
- **IOKit** — 读取电池循环次数、健康度等硬件数据
- **Mach API** — CPU、内存占用率
- **ifaddrs** — 内网 IP、网络速度
- **URLSession** — 公网 IP (api.ipify.org)
- **pmset** — 电池存在检测

## 项目结构 Project Structure

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

## 数据来源 Data Sources

- **CPU**: `host_statistics()` (Mach)
- **Memory**: `host_statistics64()` (Mach)
- **GPU**: `Metal` / `MTLCreateSystemDefaultDevice()`
- **Network**: `getifaddrs()` + delta calculation
- **IP**: `getnameinfo()` (local), `api.ipify.org` (public)
- **Disk**: `FileManager.attributesOfFileSystem()`
- **Battery**: IOKit `AppleSmartBattery` service + `pmset -g batt`

## 许可 License

MIT License

Copyright © 2026 MaoYF

---

Made with ❤️ by [alazymerlin](https://github.com/alazymerlin)
