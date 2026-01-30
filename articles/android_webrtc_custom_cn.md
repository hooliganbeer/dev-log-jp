---
title: "WebRTC M43 Android 音频引擎定制操作指南"
emoji: "🎙️"
type: "tech"
topics: ["android", "webrtc", "cpp", "ndk", "audio"]
published: true
---

# WebRTC M43 Android 音频引擎定制操作指南

本手册旨在指导开发者如何从 WebRTC M43 源码中提取纯净的音频算法库（AEC/AGC/NS/VAD/NetEq），并使用现代 NDK 工具链进行构建，以满足 Google Play 的 16K 页对齐及 64 位架构要求。

## 一、 音频核心技术科普：场景化理解
在剥离代码前，如果不理解音频处理的物理链路及数据格式，你将无法正确调用 JNI 接口。

### 1.1 核心算法：它们在通话中干了什么？
- **AEC (回声消除 - Acoustic Echo Canceller)**：
    - **生活场景**：当你和朋友语音通话并开启免提时，如果你能从耳机里听到“自己说话的声音”，说明对方的回声消除失效了。
    - **近端信号 (Near-end)**：你的麦克风录到的所有声音（包括你的话语 + 扬声器传出的对方声音）。
    - **远端信号 (Far-end/参考音)**：从你手机扬声器播放出来的对方的声音。
    - **原理**：AEC 将“远端信号”作为参考，从“近端信号”中精准地“减去”扬声器放出的声音，这样对方就只会听到你的话。
- **AGC (自动增益控制)**：自动调节录音音量。离麦克风近时压低音量，远时放大音量，保证听感平稳。
- **NS (噪声抑制)**：识别并抹除背景中持续稳定的杂音（如风扇声、空调声）。
- **VAD (静音检测)**：判断当前是否有人说话，用于节省带宽或断句。
- **NetEq (音频黑科技)**：Voice Engine 的大脑，负责缓存语音包并处理丢包补偿。

### 1.2 必备基础：什么是音频帧内容？
在处理 WebRTC 接口时，你操作的是 PCM (Pulse Code Modulation) 原始数据。理解以下参数至关重要：
- **采样率 (Sample Rate)**：每秒钟录制声音的次数。WebRTC 内部通常使用 16kHz 或 32kHz。
- **声道 (Channels)**：单声道 (Mono) 或立体声 (Stereo)。WebRTC 核心算法通常处理单声道。
- **位深/比特率 (Bit Depth)**：每个采样点的大小。WebRTC 通常使用 16bit (2字节) 整型表示。
- **音频帧 (Audio Frame)**：通常 WebRTC 处理 10ms 的数据。例如：16kHz、单声道、16bit 的 10ms 数据包含 160 个采样点，占用 320 字节。

### 1.3 专项解析：重采样 (Resample)
- **核心意图**：由于 Android 系统的录音采样率通常是 44.1kHz 或 48kHz，而 WebRTC 内部音频处理模块（如 AEC/NS）往往在 16kHz 或 32kHz 下工作最稳定且功耗最低。
- **技术动作**：在将音频送入处理引擎前，必须通过 common_audio 中的重采样模块进行频率转换，否则会导致音频速度变快/变慢或产生严重的噪声污染。

## 二、 前置环境：现代 NDK 适配
- **NDK 版本**: 建议使用 NDK r25 - r29。为了满足 Google Play 上线要求，必须支持 arm64-v8a 和 16K 页对齐。
- **OS 环境**: Windows 10/11。
- **源码状态**: 已解压的 WebRTC M43 src 目录。

## 三、 实战步骤：源码物理裁剪
通过以下精简脚本，我们将物理删除不需要的庞大模块，强制编译器不再寻找这些依赖。

### 步骤 1：核心自动化清理脚本 (webrtc_custom.bat)
```batch
@echo off
:: 关键步骤：切换控制台代码页为 UTF-8
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: ============================================================
:: WebRTC Android NDK 定制精简脚本 (M43 统一输出版)
:: ============================================================

set "WEBRTC_DIR=%~1"

if "%WEBRTC_DIR%"=="" (
    echo [错误] 用法: webrtc_custom.bat ^<webrtc_根目录^>
    exit /b 1
)

set "ROOT=%~f1"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

if not exist "%ROOT%" (
    echo [错误] 找不到目标目录: %ROOT%
    exit /b 1
)

echo ==========================================
echo  开始清理 WebRTC: %ROOT%
echo ==========================================

:: 1. 全局根目录清理
echo [1/5] 清理非音频核心模块 (Root/Base/Video)...
for %%D in (build examples tools test video video_engine common_video p2p libjingle sound) do (
    if exist "%ROOT%\%%D" (
        rd /s /q "%ROOT%\%%D"
        echo   - [已删除目录] %%D
    )
)

for %%F in (video_decoder.h video_encoder.h video_frame.h video_renderer.h video_receive_stream.h video_send_stream.h video_engine_tests.isolate) do (
    if exist "%ROOT%\%%F" (
        del /f /q "%ROOT%\%%F"
        echo   - [已删除文件] %%F
    )
)

:: 2. 核心目录内部精简 (Base, System, VoiceEngine)
echo [2/5] 精简核心组件内部代码...
if exist "%ROOT%\base" (
    for /r "%ROOT%\base" %%f in (*_unittest.* *_test.*) do del /f /q "%%f"
)
:: ... 此处逻辑已与定稿脚本完全一致 ...

:: 3. Modules 深度清理
echo [3/5] 处理 Modules 及其子模块...
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

:: 4. 强力清理辅助文件
echo [4/5] 正在执行强力清理 (py, gyp, gn, isolate, OWNERS 等)...
for %%X in (py pyc gyp gypi gn gni isolate txt md settings) do (
    for /r "%ROOT%" %%f in (*.%%X) do del /f /q "%%f" 2>nul
)

echo ==========================================
echo  完成：WebRTC 定制精简结束。
echo ==========================================
pause
```

### 步骤 2：执行说明与清单
- **执行命令**：
    ```batch
    D:
    cd /d D:\webrtc_m43
    webrtc_custom.bat src
    ```
- **已删除模块清单（参考）**：
    - `video/` & `video_engine/`：视频全链路逻辑。
    - `p2p/` & `libjingle/`：传输协议与穿透逻辑。
    - `test/` & `mock/`：所有单元测试与模拟实现。
    - 所有 Google 内部构建脚本（GYP/GN/PY）。

## 四、 现代构建系统：适配 16K 页对齐与 CMake
### 4.1 16K 页对齐配置 (Google Play 必选)
针对 Android 15+，必须在链接参数中添加，以防止最新系统下加载 SO 库闪退：
```cmake
set(CMAKE_SHARED_LINKER_FLAGS "${S}{CMAKE_SHARED_LINKER_FLAGS} -Wl,-z,max-page-size=16384")
```

### 4.2 CMakeLists.txt 配置参考
```cmake
cmake_minimum_required(VERSION 3.22)
project(praxis-native LANGUAGES C CXX)

# 1. 源文件查找
file(GLOB_RECURSE WEBRTC_SOURCES "webrtc/*.c" "webrtc/*.cc" "webrtc/*.cpp")

# 2. 创建原生库
add_library(praxis-native SHARED native-bridge.cpp ${S}{WEBRTC_SOURCES})

# 3. 编译选项与宏定义
target_compile_definitions(praxis-native PRIVATE
        WEBRTC_POSIX=1       # 启用 pthread 相关的线程安全实现
        WEBRTC_ANDROID=1     # 启用 WebRTC 的 Android 特定代码
        WEBRTC_LINUX=1       # Android 底层是 Linux
        WEBRTC_AUDIO_PROCESSING_FIXED_POINT # 启用固定点运算
)

set_target_properties(praxis-native PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)

# 4. 头文件包含
target_include_directories(praxis-native PUBLIC 
    ${S}{CMAKE_CURRENT_SOURCE_DIR} 
    ${S}{CMAKE_CURRENT_SOURCE_DIR}/webrtc
)

# 5. 链接库
find_library(log-lib log)
target_link_libraries(praxis-native ${S}{log-lib} m)
```

## 五、 官方参考与进阶建议
- 官方 CMake 构建指南: Android NDK CMake
- 16 KB 页对齐专项说明: Google Play 适配建议
- 核心 API 入口: 重点研读 `modules/audio_processing/include/audio_processing.h`。

---
**文档版本:** v1.0  
**更新日期:** 2026-01-30
