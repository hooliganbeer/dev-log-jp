# 🚀 Full-Stack & Geek Tech Notes: 生きている、そして勉強している。

> **「生きている、そして勉強している。」**
> *(Living, and Learning. / 生于世，学无止境。)*

欢迎来到我的技术笔记仓库。这里记录了一名拥有 **20年实战经验**、现居日本的全栈极客在技术海洋中探索的轨迹。

## 🖋️ 从 ToB 巅峰到 ToC 降维探索

在过去的 20 年里，我曾在中国深耕 **ToB** 领域：
* 曾任创业公司 **CTO**，主持餐饮机器人及中央厨房 O2O 电商项目。
* 曾任房地产公司 **技术 VP**，主导复杂地产 ERP 系统的架构与研发。

如今，我来到了日本。面对文化差异与 ToB 领域的天然壁垒，我选择了拥抱 **ToC** 赛道。在日本平衡的工作节奏下（每天 8 小时 + 在宅办公），我拥有了充沛的业余时间。作为一名全栈极客，我正利用这些时间，结合 AI 的赋能，发出来自中国一流技术者的声音。

## 🏗️ 2026 核心项目：Praxis (プラクシス)

**Praxis** 来源于希腊语，意为“实践、练习”。这是我 2026 年的首个 ToC 项目，旨在通过技术手段，解决语言学习者的核心痛点。

### 🎙️ Project Slogan
> **耳から覚える、口から使える。**
> *(由耳入心，出口成章 / Learn from the ear, use from the mouth)*

### 🌟 核心路线图与当前进展 (Roadmap & Status)

1. **MVP 阶段 (PoC) - [进行中 🟢]**
   * **音频规范化:** 基于 `FFmpeg-kit` 实现多源格式向标准 `16kHz/Mono` WAV 的预处理转换。
   * **高性能 VAD 引擎 (C++ Native):**
     * 在 NDK 中深度集成 **WebRTC VAD**。
     * 采用 **MediaCodec + JNI** 流式解码架构，支持大文件毫秒级切片。
     * 实现了 **Downmix-Peak 采样算法**：同步提取帧峰值，为 UI 提供极低内存占用的波形渲染数据。
     * **多模态检测:** 支持 4 级侵略性模式调节。
   * **智能逻辑切片:** 自动识别静音断句，存入本地 `SQLite` 播放列表。

2. **AI 增强阶段 - [计划中 ⚪]**
   * **语料适配分析:** 自动识别字幕并统计词汇量，判断材料难易度。
   * **AI 导师:** 使用专业 Prompt 优化语言知识点的即时展示。

### 💰 变现与技术选型
* **架构:** Firebase/Cloud Functions/Firestore (Serverless)。
* **支付:** Google Play Billing Library。
* **核心:** NDK (C++), WebRTC VAD, MediaCodec API, Coroutines.

## 🧠 AI & 极客哲学 (AI & Philosophy)

在 AI 时代，我深信 AI 是为了赋能个体而进化的。虽然 AI 能够处理海量的重复工作，但以下两点是尚不可替代的核心价值：

1. **产品领域的卓绝创新力:** 洞察用户需求（如 Praxis 的诞生），定义产品灵魂的能力。
2. **技术领域的专业判断力:** 在复杂系统中进行关键决策（如弃用普通算法，选择集成 WebRTC VAD）的能力。

**“有了 AI，我一人足矣！”** —— AI 是我的挚友与团队，它让我能更专注于创造与判断。

## 📁 核心技术栈 (Core Skills)
* **当前专注:** 嵌入式 C/C++ (支付终端)、Android 原生/NDK 开发、高性能音频处理。
* **全栈背景:** Java/Spring, C#/.NET (20y+), JavaScript/TS (10y+), DevOps/CI/CD。
* **语言能力:** 日语 N2+ (一年达成)。

## 🛠️ 关于作者
* **Name:** DevilSoul | **Exp:** 20 Years
* **Location:** Japan | **Platform:** [zenn.dev/devilsoul](https://zenn.dev/devilsoul)
* **Contact:** [hooliganbeer@gmail.com](mailto:hooliganbeer@gmail.com)

---

© 2026 DevilSoul. Built with ❤️, AI Wisdom, and 20 Years of Passion.