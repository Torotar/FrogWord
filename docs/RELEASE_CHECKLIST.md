# WordFlowHarmony 发布检查清单

## 基础配置

1. `app.json5` 应用名称正确。
2. `module.json5` module 名称、abilities 配置正确。
3. `bundleName` 使用正式包名，不使用测试包名。
4. `versionCode` 已递增。
5. `versionName` 为 `1.5.3`。
6. 应用图标、启动图标已替换为正式资源。
7. `ohos.permission.INTERNET` 权限保留，并在隐私说明中解释用途。
8. 文件选择若使用系统 Picker，通常不需要额外存储权限；以当前 SDK 文档和真机测试为准。

## Release 配置

1. `Constants.DEBUG_MODE` 发布前改为 `false`。
2. `Constants.BUILD_TYPE` 发布前改为 `release`。
3. DebugDatabasePage 入口从 SettingsPage 隐藏。
4. 测试 API Key 清空，不打包任何真实密钥。
5. 删除临时日志、临时测试数据和无用资源。
6. AI、发音、文件导入异常提示保持用户可理解。

## 签名和证书

1. DevEco Studio 已配置 release signing config。
2. 证书未过期，密码正确。
3. Profile 与 bundleName、设备/发布类型匹配。
4. 使用正式发布 Profile，不混用 debug Profile。
5. HAP / APP 包输出路径记录清楚，避免上传旧包。

## 打包前功能检查

1. 首次启动初始化默认词库。
2. 首页统计显示正常。
3. 学习、复习、搜索、详情、设置、统计、词书管理可打开。
4. Preferences 设置重启后仍保持。
5. AI 接口无 Key 时不请求，有 Key 时能测试。
6. 在线发音不可用时不崩溃。
7. CSV / JSON 导入不影响已有词库。
8. 清空学习记录、重建默认词库仅开发阶段可用。

## 常见签名错误

1. `Profile not match bundleName`：检查 Profile 中的 bundleName 与项目配置一致。
2. `Certificate expired`：重新申请或更新证书。
3. `Keystore password error`：检查签名配置密码。
4. `No signing config`：在 DevEco Studio 的 Project Structure 中配置 release 签名。
5. `Install failed due to version downgrade`：提高 versionCode 或卸载旧版本后安装。

## 打包失败排查步骤

1. 先执行 Clean Project。
2. 查看 hvigor 控制台第一条 ArkTS 编译错误。
3. 检查新增路由是否在 `main_pages.json`。
4. 检查 import 路径大小写。
5. 检查权限名称是否拼写正确。
6. 检查 release 签名、证书、Profile。
7. 在真机安装 release 包并做冒烟测试。
