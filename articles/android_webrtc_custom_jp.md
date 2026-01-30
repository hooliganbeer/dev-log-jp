---
title: "WebRTC M43 Android オーディオエンジン・カスタマイズガイド"
emoji: "🎙️"
type: "tech"
topics: ["android", "webrtc", "cpp", "ndk", "audio"]
published: true
---

# WebRTC M43 Android オーディオエンジン・カスタマイズガイド

本マニュアルは、WebRTC M43 ソースコードから純粋なオーディオアルゴリズムライブラリ（AEC/AGC/NS/VAD/NetEq）を抽出し、現代の NDK ツールチェーンを使用して、Google Play の 16K ページアラインメントおよび 64 ビットアーキテクチャ要件を満たすビルド方法を解説します。

## 一、 オーディオコア技術解説：シーン別理解
コードを切り離す前に、オーディオ処理の物理的なリンクとデータ形式を理解していないと、JNI インターフェースを正しく呼び出すことができません。

### 1.1 コアアルゴリズム：通話中に何をしているのか？
- **AEC (エコーキャンセラー - Acoustic Echo Canceller)**：
    - **利用シーン**：ハンズフリー通話中に自分の声が遅れて聞こえる場合、エコーキャンセラーが機能していません。
    - **近端信号 (Near-end)**：自分のマイクが拾ったすべての音（自分の声 ＋ 相手の声の回り込み）。
    - **遠端信号 (Far-end)**：相手から送られてきた、スピーカーから再生される音。
    - **原理**：遠端信号をリファレンスとして、近端信号から「相手の声」を正確に引き算することで、自分の声だけを相手に届けます。
- **AGC (自動ゲイン制御)**：マイクの距離に応じて音量を自動調整し、安定した音量を維持します。
- **NS (ノイズ抑制)**：エアコンやファンなどの定常的な背景ノイズを識別して除去します。
- **VAD (音声活動検出)**：発話の有無を判定し、帯域の節約や区切りに使用します。
- **NetEq (オーディオエンジンの脳)**：音声パケットをキャッシュし、パケットロス補完やジッター制御を行います。

### 1.2 必須知識：オーディオフレームの内容
WebRTC インターフェースを扱う際、操作するのは PCM (Pulse Code Modulation) 生データです。
- **サンプリングレート**：1秒あたりの録音回数。WebRTC 内部では通常 16kHz または 32kHz を使用します。
- **チャンネル**：モノラル (Mono) または ステレオ (Stereo)。WebRTC アルゴリズムは通常モノラルを処理します。
- **ビット深度**：1サンプルあたりのサイズ。WebRTC は通常 16bit (2バイト) の整数を使用します。
- **オーディオフレーム**：WebRTC は通常 10ms 単位で処理します。例：16kHz、モノラル、16bit の 10ms データは 160 サンプル（320バイト）です。

### 1.3 特記事項：リサンプリング (Resample)
- **意図**：Android システムは通常 44.1kHz/48kHz で録音しますが、WebRTC の AEC/NS 等のモジュールは 16kHz/32kHz で最も安定して動作します。
- **技術的アクション**：エンジンに音声を入れる前に、`common_audio` のリサンプラーで周波数変換を行う必要があります。これを行わないと、音声の速度異常やノイズが発生します。

## 二、 事前準備：モダン NDK への適合
- **NDK バージョン**: NDK r25 - r29 推奨。Google Play の要件に基づき、arm64-v8a および 16K ページアラインメントへの対応が必須です。
- **OS 環境**: Windows 10/11。
- **ソースコードの状態**: 解凍済みの WebRTC M43 src ディレクトリ。

## 三、 実戦ステップ：ソースコードの物理削減
不要なモジュールを物理的に削除することで、コンパイラが不要な依存関係を探すのを防ぎます。

### ステップ 1：コア自動化クリーンアップスクリプト (webrtc_custom.bat)
```batch
@echo off
:: 重要：コンソールのコードページを UTF-8 に切り替え
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: ============================================================
:: WebRTC Android NDK カスタマイズスクリプト (M43 統合版)
:: ============================================================

set "WEBRTC_DIR=%~1"

if "%WEBRTC_DIR%"=="" (
    echo [エラー] 使用法: webrtc_custom.bat ^<webrtc_root_dir^>
    exit /b 1
)

set "ROOT=%~f1"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

if not exist "%ROOT%" (
    echo [エラー] 対象ディレクトリが見つかりません: %ROOT%
    exit /b 1
)

echo ==========================================
echo  WebRTC のクリーンアップを開始: %ROOT%
echo ==========================================

:: 1. ルートディレクトリのクリーンアップ
echo [1/5] 非オーディオコアモジュールを削除中 (Root/Base/Video)...
for %%D in (build examples tools test video video_engine common_video p2p libjingle sound) do (
    if exist "%ROOT%\%%D" (
        rd /s /q "%ROOT%\%%D"
        echo   - [削除済み] %%D
    )
)

for %%F in (video_decoder.h video_encoder.h video_frame.h video_renderer.h video_receive_stream.h video_send_stream.h video_engine_tests.isolate) do (
    if exist "%ROOT%\%%F" (
        del /f /q "%ROOT%\%%F"
        echo   - [削除済みファイル] %%F
    )
)

:: 2. 内部コンポーネントの精査 (Base, System, VoiceEngine)
echo [2/5] コアコンポーネント内部のコードを精査中...
if exist "%ROOT%\base" (
    for /r "%ROOT%\base" %%f in (*_unittest.* *_test.*) do del /f /q "%%f"
)

:: 3. Modules のディープクリーンアップ
echo [3/5] Modules とサブモジュールを処理中...
set "MOD=%ROOT%\modules"
if exist "%MOD%" (
    for %%D in (desktop_capture video_capture video_render video_processing video_coding media_file) do (
        if exist "%MOD%\%%D" rd /s /q "%MOD%\%%D"
    )
    for %%M in (audio_coding audio_conference_mixer audio_device audio_processing bitrate_controller pacing remote_bitrate_estimator rtp_rtcp utility) do (
        if exist "%MOD%\%%M" (
            for /r "%MOD%\%%M" %%d in (test tests mock) do if exist "%%d" rd /s /q "%%d"
            del /s /f /q "%MOD%\%%M\*_unittest.*" >nul 2>&1
        )
    )
)

:: 4. 補助ファイルの強制削除
echo [4/5] 強力なクリーンアップを実行中 (py, gyp, gn, isolate, OWNERS 等)...
for %%X in (py pyc gyp gypi gn gni isolate txt md settings) do (
    for /r "%ROOT%" %%f in (*.%%X) do del /f /q "%%f" 2>nul
)

echo ==========================================
echo  完了：WebRTC カスタマイズが終了しました。
echo ==========================================
pause
```

### ステップ 2：実行手順とチェックリスト
- **実行コマンド**:
    ```batch
    D:
    cd /d D:\webrtc_m43
    webrtc_custom.bat src
    ```
- **削除済みモジュールリスト（参考）**:
    - `video/` & `video_engine/`: ビデオ全般のロジック。
    - `p2p/` & `libjingle/`: 通信プロトコル関連。
    - `test/` & `mock/`: 全てのユニットテストとモック。
    - 全ての Google 内部ビルドスクリプト (GYP/GN/PY)。

## 四、 モダンビルドシステム：16K ページアラインメントと CMake
### 4.1 16K ページアラインメントの設定 (Google Play 必須)
Android 15+ 向けに、SO ライブラリのロード失敗を防ぐためリンカーフラグを追加します。
```cmake
set(CMAKE_SHARED_LINKER_FLAGS "${S}{CMAKE_SHARED_LINKER_FLAGS} -Wl,-z,max-page-size=16384")
```

### 4.2 CMakeLists.txt 設定リファレンス
```cmake
cmake_minimum_required(VERSION 3.22)
project(praxis-native LANGUAGES C CXX)

# 1. ソースファイルの検索
file(GLOB_RECURSE WEBRTC_SOURCES "webrtc/*.c" "webrtc/*.cc" "webrtc/*.cpp")

# 2. ネイティブライブラリの作成
add_library(praxis-native SHARED native-bridge.cpp ${S}{WEBRTC_SOURCES})

# 3. コンパイル定義
target_compile_definitions(praxis-native PRIVATE
        WEBRTC_POSIX=1       # POSIX スレッド実装を有効化
        WEBRTC_ANDROID=1     # Android 固有のコードを有効化
        WEBRTC_LINUX=1       # Android は Linux ベース
        WEBRTC_AUDIO_PROCESSING_FIXED_POINT # 固定小数点演算を有効化
)

set_target_properties(praxis-native PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)

# 4. インクルードディレクトリ
target_include_directories(praxis-native PUBLIC 
    ${S}{CMAKE_CURRENT_SOURCE_DIR} 
    ${S}{CMAKE_CURRENT_SOURCE_DIR}/webrtc
)

# 5. リンクライブラリ
find_library(log-lib log)
target_link_libraries(praxis-native ${S}{log-lib} m)
```

## 五、 公式リファレンスとアドバイス
- 公式 CMake ガイド: Android NDK CMake
- 16 KB ページアラインメントの解説: Google Play への対応
- 主要 API エントリ: `modules/audio_processing/include/audio_processing.h` を重点的に確認してください。

---
**ドキュメントバージョン:** v1.0  
**更新日:** 2026-01-30  
