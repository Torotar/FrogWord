<a id="chinese"></a>

# 呱呱单词

中文 | [English](#guagua-words-english)

## 简介

呱呱单词是一款基于 HarmonyOS Stage 模型、使用 ArkTS 和 ArkUI 开发的单词学习应用。它支持词书管理、间隔复习和拼写训练，并将词书与学习记录保存在本机。当前版本为 `1.5.3`。

## 功能

- 创建和管理词书，学习新词、复习到期词、重学错词并进行拼写训练。
- 查看学习统计和学习计划，设置每日目标、复习数量、主题与发音偏好。
- 从 CSV、JSON 数组或有道 JSON Lines 文件导入词书，也可以浏览和导入在线词书。
- 查询单词释义并播放发音；可配置兼容 OpenAI API 格式的 AI 服务，为单词生成解释。
- 通过 WebDAV 备份与恢复词书和学习数据。

## 数据与联网说明

- CSV/JSON 文件通过系统文件选择器导入；JSON 支持标准数组和有道 JSON Lines 格式。
- 在线词书目录和词书文件需要网络连接。
- WebDAV 使用 `wordcard-backup.json` 保存词书、单词和学习记录。恢复备份会替换本机现有词书和学习数据；操作前请先备份。
- AI 解释需要用户自行填写服务地址、模型和 API Key。请求会将所查询的单词发送到用户配置的第三方服务。
- 在线词典与发音需要网络连接，相关服务受第三方可用性影响。

## 环境要求

- DevEco Studio 与兼容项目配置的 HarmonyOS SDK。
- 项目模型版本为 `6.1.1`，目标 SDK 为 API 24，兼容 API 22。
- 使用 ArkTS、ArkUI 和 HarmonyOS Stage 模型，依赖由 OHPM 管理。

## 构建

1. 在 DevEco Studio 中打开仓库根目录。
2. 等待项目同步完成，并确认已安装项目所需的 HarmonyOS SDK。
3. 选择 `default` 产品和 `entry` 模块，通过 **Build > Build Hap(s)** 构建应用。

根目录的 `build-profile.json5` 是本机签名配置，不会提交。首次构建时可复制 `build-profile.example.json5` 为 `build-profile.json5`，再按本机 DevEco Studio 环境配置签名。仓库当前不包含 `hvigorw.bat` 命令行包装脚本；命令行构建方式需以本机 DevEco Studio 安装和项目工具链为准。源码测试位于 `entry/src/test` 和 `entry/src/ohosTest`，请使用与当前 SDK 匹配的测试配置运行。

## 下载

[GitHub Releases](https://github.com/Torotar/FrogWord/releases) 提供应用包。未签名 HAP 需要使用匹配的签名配置重新签名或构建后，才能用于安装或正式分发。

## 项目结构

- `AppScope/`：应用级配置与资源。
- `entry/src/main/ets/`：ArkTS 页面、数据模型和服务。
- `entry/src/test/`：本地单元测试。
- `entry/src/ohosTest/`：设备侧测试。
- `docs/`：测试、隐私和发布检查文档。

## 许可证

本仓库尚未指定开源许可证。未经另行许可，代码仍受其适用的版权保护。

---

<a id="guagua-words-english"></a>

# 呱呱单词

[中文](#chinese) | English

## Overview

呱呱单词 is a vocabulary learning app built with ArkTS, ArkUI, and the HarmonyOS Stage model. It provides word book management, spaced reviews, and spelling practice, with word books and study records stored on the device. The current version is `1.5.3`.

## Features

- Create and manage word books; study new words, review due words, revisit mistakes, and practice spelling.
- View study statistics and plans, and configure daily goals, review amounts, appearance, and pronunciation preferences.
- Import word books from CSV, JSON arrays, or Youdao JSON Lines files, or browse and import online word books.
- Look up definitions and play pronunciations. Configure an OpenAI API compatible service to generate word explanations.
- Back up and restore word books and study data through WebDAV.

## Data and network notes

- CSV and JSON files are imported through the system file picker. JSON import supports standard arrays and Youdao JSON Lines.
- An internet connection is required to browse the online word book catalog and download word books.
- WebDAV stores word books, words, and study records in `wordcard-backup.json`. Restoring a backup replaces the current local word books and study data, so make a backup first.
- AI explanations require a service URL, model, and API key supplied by the user. The queried word is sent to the configured third-party service.
- Online dictionary and pronunciation services require network access and depend on third-party availability.

## Requirements

- DevEco Studio and a HarmonyOS SDK compatible with the project configuration.
- Project model version `6.1.1`, target API 24, compatible with API 22.
- ArkTS, ArkUI, and the HarmonyOS Stage model; dependencies are managed through OHPM.

## Build

1. Open the repository root in DevEco Studio.
2. Wait for project sync to finish and confirm that the required HarmonyOS SDK is installed.
3. Select the `default` product and `entry` module, then build with **Build > Build Hap(s)**.

The root `build-profile.json5` contains local signing configuration and is not committed. For a first build, copy `build-profile.example.json5` to `build-profile.json5` and configure signing for your DevEco Studio setup. This repository does not include an `hvigorw.bat` command-line wrapper; command-line builds depend on the toolchain provided by the local DevEco Studio installation. Source tests are under `entry/src/test` and `entry/src/ohosTest`; use test configurations compatible with the installed SDK.

## Downloads

Application packages are available from [GitHub Releases](https://github.com/Torotar/FrogWord/releases). An unsigned HAP must be signed or rebuilt with a matching signing configuration before installation or production distribution.

## Project layout

- `AppScope/`: app-level configuration and resources.
- `entry/src/main/ets/`: ArkTS pages, data models, and services.
- `entry/src/test/`: local unit tests.
- `entry/src/ohosTest/`: on-device tests.
- `docs/`: testing, privacy, and release checklists.

## License

No open-source license has been specified for this repository. The code remains protected by applicable copyright unless permission is granted separately.
