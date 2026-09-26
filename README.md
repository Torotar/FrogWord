# FrogWord / 呱呱学英语

中文 | [English](#english)

## 中文

FrogWord（呱呱学英语）是一款基于 HarmonyOS Stage 模型和 ArkTS/ArkUI 开发的手机背单词应用。应用包名为 `com.torotar.wordcard`，当前版本为 `1.0.0`。

### 功能

- 词书管理、单词学习与到期复习
- 错词重学、拼写训练、学习统计和学习计划
- 单词发音、AI 配置以及 WebDAV 备份与恢复
- 深色模式和 HarmonyOS 组件界面

### 开发环境

- DevEco Studio 与 HarmonyOS SDK
- 目标 API 24，兼容 API 22
- ArkTS、ArkUI、Stage 模型

使用 DevEco Studio 打开项目根目录并等待依赖同步，然后选择 `default` 产品和 `entry` 模块，通过 **Build > Build Hap(s)** 执行构建。

根目录的 `build-profile.json5` 是本机文件，包含签名配置，不会提交。可复制 `build-profile.example.json5` 为 `build-profile.json5`，再按本机 DevEco Studio 环境配置签名。`entry/build-profile.json5` 是模块构建配置，会随源码提交。

### 下载

GitHub Release 提供 `entry-default-unsigned.hap`。该 HAP 未签名；安装或发布前需要使用匹配应用包名和设备/发布目标的签名配置重新签名或构建。

### 隐私提示

不要提交 API Key、WebDAV 密码、签名密码、证书或个人签名配置。请检查 `docs/PRIVACY_CHECKLIST.md` 和 `docs/RELEASE_CHECKLIST.md` 后再进行正式发布。

## English

FrogWord (呱呱学英语) is a mobile vocabulary learning app built with the HarmonyOS Stage model, ArkTS, and ArkUI. Its application bundle is `com.torotar.wordcard`, and the current version is `1.0.0`.

### Features

- Word book management, vocabulary study, and due reviews
- Mistake review, spelling practice, study statistics, and study plans
- Word pronunciation, AI configuration, and WebDAV backup and restore
- Dark mode and a HarmonyOS component based interface

### Development environment

- DevEco Studio and the HarmonyOS SDK
- Target API 24; compatible with API 22
- ArkTS, ArkUI, and the Stage model

Open the project root in DevEco Studio and let dependencies synchronize. Select the `default` product and `entry` module, then build with **Build > Build Hap(s)**.

The root `build-profile.json5` is a machine-specific file containing signing configuration and is not committed. Copy `build-profile.example.json5` to `build-profile.json5`, then configure signing for your local DevEco Studio setup. The module file `entry/build-profile.json5` is part of the source project and is committed.

### Download

GitHub Releases provide `entry-default-unsigned.hap`. This HAP is unsigned. Before installing or publishing it, sign or rebuild it with a signing configuration that matches the application bundle and the intended device or release target.

### Privacy

Do not commit API keys, WebDAV passwords, signing passwords, certificates, or personal signing configuration. Review `docs/PRIVACY_CHECKLIST.md` and `docs/RELEASE_CHECKLIST.md` before a production release.
