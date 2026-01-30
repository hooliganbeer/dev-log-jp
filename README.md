# 🎙️ Praxis (プラクシス): 耳から覚える、口から使える。

> **「生きている、そして勉強している。」**
> *(Living, and Learning. / 生于世，学无止境。)*

## 🏗️ 项目愿景
**Praxis** 旨在通过极致的技术手段，打破语言学习者“听力”与“口语”之间的断层，实现高效的影子跟读与语料循环。

## 🖋️ 开发者心路：20 年 ToB 老兵的 ToC 降维打击
我曾任创业公司 **CTO** 与地产上市集团 **技术 VP**。如今旅居日本，在告别了国内 996 的职业生涯之后，我决定利用业余时间打造这款纯粹的、面向全球市场的 ToC 语言练习工具。

## 🌟 核心技术架构 (Current Status)

### 1. 核心基础设施 - [已完成 ✅]
* **智能 I/O 引擎**: 
    * 自研 `FileDownloader`，支持基于服务器能力的自动策略切换（并行分片 vs 全量流式）。
    * 严格遵循 **RFC 5987** 标准，通过 Header 自动解码多语言文件名（如 `€ - 测试.zip`）。
* **自动化 i18n 架构 (ASM-based)**: 
    * **实战演进**: 在遭遇 KSP 2.x 接口变更阻碍后，果断切换至 **Gradle + ASM 字节码扫描** 方案。
    * 直接解析类初始化块 (`<clinit>`)，实现编译期全自动资源提取。
* **多态 JSON 体系**: 封装 `JsonValue` 密封类，解决动态语料下类型安全的序列化难题。

### 2. 自动化测试与质量保证 - [已完成 ✅]
* **单元测试覆盖**: 针对下载器实现了完善的测试矩阵。
    * **Mock 策略验证**: 模拟 HEAD 请求，确保大文件触发并行分片，小文件自动回落全量下载。
    * **协议兼容性测试**: 验证 RFC 5987 文件名解码与优先级策略。
    * **集成测试**: 在 Android 真实环境下完成网络下载、分片合并与文件系统校验。

### 3. 音频引擎 (PoC) - [已完成 ✅]
* **FFmpeg 16KB Page Size 适配**: 已完成对 Android 15 的深度兼容。
* **WebRTC VAD 引擎**: 深度集成 C++ 原生引擎，支持毫秒级精准语音检测（VAD）。

## 🧠 极客哲学：实战派的决策力
1. **不迷信工具**: 当 KSP 的黑盒限制了生产力，直接深入字节码 (ASM) 拿回控制权。
2. **测试驱动 (TDD)**: 即使基础设施再底层，也要通过全绿的单元测试来证明其健壮性。

## 🛠️ 技术栈 (Tech Stack)
* **Core**: Kotlin, NDK (C++), Coroutines, **ASM (Bytecode Mastery)**, Serialization
* **Media**: FFmpeg-kit, MediaCodec API, WebRTC VAD
* **Quality**: JUnit 4, AndroidX Test, Mockito

## 🛠️ 关于作者
* **Name**: DevilSoul | **Exp**: 20 Years Full-Stack
* **Location**: Japan | **Language**: 日语 N2+ (一年达成)

© 2026 Praxis Project. Built with ❤️, AI Wisdom, and 20 Years of Passion.