---
title: "WSL (Ubuntu) 环境下手动编译 FFmpeg-kit：适配 Android 15 (16KB Page Size)"
emoji: "🎥"
type: "tech"
topics: ["android", "ffmpeg", "wsl", "cpp", "android15"]
published: true
---

# Android 开发笔记：手动编译 ffmpeg-kit 项目 (WSL 环境)

本笔记详细记录了在 WSL (Ubuntu) 环境下从零搭建环境并编译 ffmpeg-kit 的过程。特别针对 Android 15 (16KB Page Size) 适配要求，包含了 NDK r29 的配置及对齐验证步骤。

---

## 一、 环境准备 (WSL Ubuntu)

在开始编译前，需要安装完整的构建工具链、底层依赖库以及 Java 环境。

### 1.1 安装基础编译工具链
```bash
sudo apt update
# 安装必备库和构建工具
sudo apt install -y autoconf automake build-essential libtool pkg-config curl git doxygen nasm yasm bison gperf wget python3
# 安装辅助工具（用于文档生成及国际化支持）
sudo apt install -y autopoint gettext libtool-bin groff ghostscript cmake
# 安装 32 位兼容库与依赖
sudo apt install -y lib32z1 lib32stdc++6 libncurses5-dev libbz2-1.0 unzip
```

### 1.2 安装 Android SDK & NDK (NDK r29)
为了适配 Android 15，建议使用最新的 NDK。

```bash
mkdir -p ~/android-sdk/cmdline-tools
cd ~/android-sdk/cmdline-tools

# 下载 Google 官方命令行工具
wget [https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip](https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip)
unzip commandlinetools-linux-*.zip
mv cmdline-tools latest

# 接受许可并安装必要平台组件
cd ~/android-sdk/cmdline-tools/latest/bin
./sdkmanager --licenses
./sdkmanager "platform-tools" "platforms;android-33" "build-tools;33.0.1"
```

### 1.3 安装 Java 环境 (JDK 17)
```bash
sudo apt update
sudo apt install -y openjdk-17-jdk
java -version
```

---

## 二、 环境变量设置

将以下配置添加至 ~/.bashrc。

```bash
# Java 路径配置
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# Android SDK & NDK 路径配置
export ANDROID_HOME=$HOME/android-sdk
export ANDROID_SDK_ROOT=$HOME/android-sdk
# 指向 NDK r29 所在路径
export ANDROID_NDK_ROOT=/home/devilsoul/android-ndk-r29
export PATH=$ANDROID_NDK_ROOT:$PATH
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

# 【关键参数】强制链接器使用 16KB 内存页对齐
export LDFLAGS="-Wl,-z,max-page-size=16384"
```

---

## 三、 源码处理与初始化

由于编译脚本依赖 git 命令获取版本号，源码必须初始化 Git 仓库记录。

```bash
# 将源码拷贝到 WSL 内部系统以提升性能
cp -r /mnt/d/workspace/project/github/arthenica-ffmpeg-kit-1036d3c/ ~/ffmpeg-kit-source
cd ~/ffmpeg-kit-source
chmod +x android.sh

# Git 初始化
git init
git config user.email "hooliganbeer@gmail.com"
git config user.name "DevilSoul"
git add .
git commit -m "initial commit for build"
```

---

## 四、 编译执行

### 4.1 虚拟内存优化 (解决 WSL OOM 问题)
如果编译过程中出现内存不足，建议开启 Swap 分区。

```bash
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 限制并发编译数 (-j4 较稳)
export MAKEFLAGS="-j4"
```

### 4.2 执行编译脚本
```bash
export LDFLAGS="-Wl,-z,max-page-size=16384"

# --enable-lame: 开启 MP3 编码支持
# --disable-x86: 仅编译移动端 64 位架构
./android.sh --enable-lame --disable-x86 --disable-arm-v7a-neon
```

---

## 五、 产物验证 (16KB Page Size 检查)

这是适配 Android 15 (Pixel 9 系列等) 的核心指标。

```bash
# 以 arm64-v8a 架构为例检查
readelf -l android/libs/arm64-v8a/libffmpegkit.so | grep LOAD
```

**判定标准：**
1. VirtAddr (虚拟地址)：末尾必须为 000。
2. Alignment (对齐值)：显示为 0x4000 (即 16384)。

---

## 六、 进阶配置：深度对齐注入

如果验证未达标，需在配置文件中显式硬编码链接参数：

```makefile
# Application.mk
APP_PLATFORM := android-35
APP_LDFLAGS := -Wl,--hash-style=both -Wl,-z,max-page-size=16384
```

---
**文档版本:** v1.0  
**更新日期:** 2026-01-25