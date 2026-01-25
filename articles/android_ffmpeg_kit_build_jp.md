---
title: "WSL (Ubuntu) 環境で FFmpeg-kit を手動ビルドする：Android 15 (16KB Page Size) への対応"
emoji: "🎥"
type: "tech"
topics: ["android", "ffmpeg", "wsl", "cpp", "android15"]
published: true
---

# Android 開発日記：ffmpeg-kit プロジェクトの手動ビルド (WSL 環境)

本記事は、Android 15 (16KB Page Size) への適応を見据え、WSL (Ubuntu) 環境で ffmpeg-kit をゼロからビルドした際の記録です。NDK r29 の設定および 16KB アライメントの検証手順を含みます。

---

## 1. 環境構築 (WSL Ubuntu)

ビルドを始める前に、ツールチェーン、依存ライブラリ、Java 環境をセットアップします。

### 1.1 ツールチェーンのインストール
```bash
sudo apt update
# 必須ライブラリとビルドツールのインストール
sudo apt install -y autoconf automake build-essential libtool pkg-config curl git doxygen nasm yasm bison gperf wget python3
# 補助ツール（ドキュメント生成および国際化対応）
sudo apt install -y autopoint gettext libtool-bin groff ghostscript cmake
# 32bit 互換ライブラリと依存関係
sudo apt install -y lib32z1 lib32stdc++6 libncurses5-dev libbz2-1.0 unzip
```

### 1.2 Android SDK & NDK (NDK r29)
Android 15 の 16KB ページサイズ対応には、最新の NDK 使用が推奨されます。

```bash
mkdir -p ~/android-sdk/cmdline-tools
cd ~/android-sdk/cmdline-tools

# Google 公式コマンドラインツールのダウンロード
wget [https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip](https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip)
unzip commandlinetools-linux-*.zip
mv cmdline-tools latest

# ライセンス承諾とコンポーネントインストール
cd ~/android-sdk/cmdline-tools/latest/bin
./sdkmanager --licenses
./sdkmanager "platform-tools" "platforms;android-33" "build-tools;33.0.1"
```

### 1.3 Java 環境 (JDK 17)
```bash
sudo apt update
sudo apt install -y openjdk-17-jdk
java -version
```

---

## 2. 環境変数の設定

`~/.bashrc` に以下の設定を追加します。

```bash
# Java 
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# Android SDK & NDK
export ANDROID_HOME=$HOME/android-sdk
export ANDROID_SDK_ROOT=$HOME/android-sdk
# NDK r29 のパスを指定
export ANDROID_NDK_ROOT=/home/devilsoul/android-ndk-r29
export PATH=$ANDROID_NDK_ROOT:$PATH
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH

# 【重要】16KB ページサイズアライメントを強制
export LDFLAGS="-Wl,-z,max-page-size=16384"
```

---

## 3. ソースコードの初期化

ビルドスクリプトが git コマンドを利用するため、リポジトリの初期化が必須です。

```bash
# WSL 内部のファイルシステムへコピーしてパフォーマンスを向上
cp -r /mnt/d/workspace/project/github/arthenica-ffmpeg-kit-1036d3c/ ~/ffmpeg-kit-source
cd ~/ffmpeg-kit-source
chmod +x android.sh

# Git 初期化
git init
git config user.email "hooliganbeer@gmail.com"
git config user.name "DevilSoul"
git add .
git commit -m "initial commit for build"
```

---

## 4. ビルドの执行

### 4.1 メモリ不足（OOM）対策
WSL でのビルド中にメモリ不足が発生する場合、Swap 領域を確保します。

```bash
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 並列ビルド数の制限 (-j4 が比較的安定)
export MAKEFLAGS="-j4"
```

### 4.2 ビルドコマンドの実行
```bash
export LDFLAGS="-Wl,-z,max-page-size=16384"

# --enable-lame: MP3 サポート
# --disable-x86: モバイル向け 64bit アーキチャに限定
./android.sh --enable-lame --disable-x86 --disable-arm-v7a-neon
```

---

## 5. ビルド産物の検証 (16KB Page Size)

Pixel 9 シリーズなどの Android 15 デバイスで動作させるための必須チェックです。

```bash
# arm64-v8a アーキテクチャを例に確認
readelf -l android/libs/arm64-v8a/libffmpegkit.so | grep LOAD
```

**判定基準：**
1. VirtAddr (仮想アドレス): 末尾が 000 であること。
2. Alignment (アライメント): 0x4000 (16384) と表示されていること。

---

## 6. 高度な設定：アライメントの注入

検証が通らない場合、ビルド設定ファイルに直接リンクパラメータを記述します。

```makefile
# Application.mk
APP_PLATFORM := android-35
APP_LDFLAGS := -Wl,--hash-style=both -Wl,-z,max-page-size=16384
```

---
**ドキュメントバージョン:** v1.0  
**更新日:** 2026-01-25  