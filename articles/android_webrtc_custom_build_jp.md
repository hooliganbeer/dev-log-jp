---
title: "WebRTC M114 NDK：Android 音声パイプラインのカスタマイズ統合方案"
type: "tech"
topics: ["WebRTC", "AndroidNDK", "C++", "WSL", "音声アルゴリズム", "NDKデバッグ"]
published: true
---

# WebRTC M114 NDK：Android 音声パイプラインのカスタマイズ統合方案

> **概要**：Android 端で WebRTC APM モジュールを統合する際、ビルドシステムが過度に巨大化するという課題に対し、本稿では WSL 環境を前提とした実践的なエンジニアリング方案を提示する。内容は、基本的な環境構築、ツールチェーン設定、ソース同期、GN スクリプトのカスタマイズ、静的ライブラリのパッケージングまでを網羅する。

---

## 1. ビルド環境の準備 (WSL / Ubuntu)

WebRTC のビルドは Google 提供の `depot_tools` および内部で連携する GN / Ninja ツールチェーンに強く依存する。

### 1.1 システム依存関係のインストール
WSL 環境にて、Python 実行環境および必要なビルドツールをインストールする：
```bash
sudo apt-get update
sudo apt-get install -y python3 python3-pip git wget curl unzip
```

### 1.2 depot_tools の設定（重要：Windows ツールチェーンの無効化）
**重要**：`fetch` や `gclient` を実行する前に、必ず環境変数を設定しておくこと。

```bash
# depot_tools を取得
cd ~
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git

# 環境変数を設定（~/.bashrc への追記を推奨）
export PATH="$HOME/depot_tools:$PATH"

# --- 重要な落とし穴 ---
# Windows 用ツールチェーンのチェックを必ず無効化すること
# 有効なままだと、Google 社内限定のビルドツールを取得しようとして HTTP 429 エラーが発生する
export DEPOT_TOOLS_WIN_TOOLCHAIN=0
# ---------------------
```

### 1.3 GN ツールのインストールと設定（重要：バイナリの手動配置）
**補足**：`depot_tools/gn` は実体バイナリではなく、Python 製のラッパースクリプトである。WSL 環境ではパス解決に失敗するケースが多い。

#### 最終解決策：バイナリ差し替え方式
`gn --version` 実行時にエラーが出る場合は、以下を実施する：
1. 公式バイナリをダウンロード（GN Google Storage）。
2. `$HOME/depot_tools/gn` を実体バイナリで上書き、もしくはシンボリックリンクを作成する。

---

## 2. コアアーキテクチャ設計

本方案では、Windows 上での開発と WSL 上でのビルドを分離する二重環境アーキテクチャを採用する：
- **ソース管理**：Wrapper コードは Windows 側の Android プロジェクトに配置する。
- **自動同期**：Shell スクリプトにより、WSL 側の `webrtc/src/bridge` へ物理コピーする。
- **ビルド分離**：IDE は編集のみを担当し、重い C++ ビルドは WSL に委譲する。

---

## 3. `src/BUILD.gn` のカスタマイズ（M114 対応）

```gn
static_library("webrtc_audio_minimal") {
  # すべての依存関係を単一の .a にまとめ、シンボル欠損を防止する
  complete_static_lib = true

  # Bridge ラッパーコード
  sources = [
    "bridge/apm_wrapper.cc",
    "bridge/vad_wrapper.cc",
    "bridge/resampler_wrapper.cc",
  ]

  # Bridge 内ヘッダ参照用
  include_dirs = [ "bridge" ]

  # Chromium スタイルチェックを無効化
  configs -= [ "//build/config/clang:find_bad_constructs" ]

  deps = [
    # --- Audio Processing Module (APM) ---
    "//modules/audio_processing:audio_processing",
    "//modules/audio_processing:api",

    # --- Common Audio ---
    "//common_audio:common_audio",
    "//common_audio:common_audio_c",

    # --- RTC Base ---
    "//rtc_base:checks",
    "//rtc_base:logging",
    "//rtc_base:criticalsection",
    "//rtc_base:platform_thread",
    "//rtc_base:refcount",
    "//rtc_base:safe_minmax",
    "//rtc_base/system:arch",
    "//rtc_base/system:unused",
    "//system_wrappers:system_wrappers",

    # --- API / Utility ---
    "//api:scoped_refptr",
    "//api:array_view",
    "//api/audio:audio_frame_api",

    # --- Third Party ---
    "//third_party/abseil-cpp/absl/strings",
    "//third_party/abseil-cpp/absl/types:optional",
  ]
}
```

---

## 4. 自動ビルドスクリプト（build_android_audio.sh）

```bash
#!/bin/bash
# WebRTC ビルド自動化スクリプト（WSL 強化版）

WINDOWS_PROJECT_ROOT="/mnt/d/workspace/project/cowx/praxis/core"
PROJECT_BRIDGE_DIR="${WINDOWS_PROJECT_ROOT}/src/main/cpp/bridge/webrtc"
PROJECT_JNI_LIBS="${WINDOWS_PROJECT_ROOT}/src/main/jniLibs"
WEBRTC_SRC_DIR=$(pwd)
BRIDGE_INTERNAL_DIR="${WEBRTC_SRC_DIR}/bridge"

mkdir -p "${BRIDGE_INTERNAL_DIR}"
rm -f "${BRIDGE_INTERNAL_DIR}"/*
cp -v "${PROJECT_BRIDGE_DIR}"/*.cc "${BRIDGE_INTERNAL_DIR}/"
cp -v "${PROJECT_BRIDGE_DIR}"/*.h "${BRIDGE_INTERNAL_DIR}/"

rm -rf out/android_arm64 out/android_armv7

COMMON_ARGS='
  target_os="android"
  is_debug=false
  is_component_build=false
  rtc_include_tests=false
  rtc_build_examples=false
  rtc_build_tools=false
  rtc_enable_protobuf=false
  rtc_build_json=false
  rtc_build_libvpx=false
  rtc_libvpx_build_vp9=false
  rtc_build_opus=false
  rtc_use_x11=false
  rtc_enable_symbol_export=true
  rtc_exclude_metrics_default=true
  apm_debug_dump=false
  symbol_level=0
  strip_debug_info=true
  use_lld=true
  treat_warnings_as_errors=false
  use_custom_libcxx=true
'

gn gen out/android_arm64 --args="${COMMON_ARGS} target_cpu=\"arm64\""
ninja -C out/android_arm64 webrtc_audio_minimal

gn gen out/android_armv7 --args="${COMMON_ARGS} target_cpu=\"arm\" arm_version=7 arm_use_neon=true"
ninja -C out/android_armv7 webrtc_audio_minimal
```

---

## 5. Android Studio のインデックスエラー対策

```cmake
set(WEBRTC_SRC_DIR "D:/webrtc_android/src")
include_directories(${WEBRTC_SRC_DIR} ${WEBRTC_SRC_DIR}/third_party/abseil-cpp)
add_library(webrtc_ide_support SHARED bridge/webrtc/apm_wrapper.cc)
```

---

## 6. undefined reference の体系的な調査手順

1. c++filt によるシンボルのデマングル
2. grep による定義検索
3. BUILD.gn ターゲットの特定
4. deps 修正または API の見直し

---

## 7. シンボルエクスポート検証

```cpp
extern "C" __attribute__((visibility("default"))) void* CreateApmWrapper();
```

```bash
nm -u out/android_arm64/obj/bridge/libwebrtc_audio_minimal.a | grep " T "
```

---

## 8. 参考資料

- https://webrtc.org/native-code/android/
- https://gn.googlesource.com/gn/+/master/docs/quick_start.md
- https://webrtc.googlesource.com/src/+/refs/heads/m114
- https://developer.android.com/ndk/guides/debug

---

## 9. 結論

ツールチェーンのラッパー罠を回避し、ソースの物理同期、`complete_static_lib` の指定、Clean Build、厳密なシンボル検証を行うことで、実運用レベルの WebRTC NDK 音声モジュールを安定して構築できる。

