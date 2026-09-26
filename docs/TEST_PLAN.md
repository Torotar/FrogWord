# WordFlowHarmony 测试计划

## 目标

本计划覆盖 1.0.0 发布前的基础自动化测试、Service 层测试思路、真机兼容测试和回归测试。第五阶段不继续新增复杂业务功能，测试重点是稳定性、数据正确性和发布风险收敛。

## 自动化测试范围

1. 首页能正常启动并显示 WordFlow 标题。
2. 首页统计卡片显示：今日学习、今日复习、待复习、已掌握、总单词。
3. 点击开始学习进入 StudyPage。
4. 点击复习单词进入 ReviewPage。
5. 点击设置进入 SettingsPage。
6. 搜索页能打开，输入关键词后能展示结果。
7. AI 配置页能保存 Base URL、模型名、API Key。
8. 深色模式开关能保存，重启后仍保持。
9. 学习计划能保存 dailyGoal、reviewGoal 等设置。
10. 词书管理页能打开并显示词书列表。
11. DebugDatabasePage 仅开发阶段可进入，正式发布前隐藏入口。

## 测试目录

```text
test/
├─ IndexPage.test.ets
├─ Navigation.test.ets
├─ Settings.test.ets
└─ StudyFlow.test.ets
```

如项目使用 DevEco Studio 默认 ohosTest 目录，也可以把这些示例迁移到：

```text
entry/src/ohosTest/ets/test/
```

## UI 自动化建议

使用 HarmonyOS 推荐的 Hypium + UiTest。不同 SDK 版本中 `@ohos.UiTest`、`ON.text`、`driver.delayMs` 的命名可能略有差异，以当前 DevEco Studio 自动补全为准。

建议给关键按钮和输入框补充稳定标识，避免测试依赖展示文案：

```ts
.id('start_study_button')
```

之后测试中优先按 id 查找组件。

## Service 层测试思路

Service 层建议拆成可独立验证的纯逻辑和数据库逻辑：

1. `SpacedRepetition`：直接单元测试输入输出，不依赖 UI。
2. `DateUtil`：测试日期格式、今日日期、最近 7 天生成。
3. `CsvParser` / `JsonParser`：测试合法数据、空字段、非法 difficulty、重复单词。
4. `PreferencesService`：测试默认值读取、保存、重启后读取。
5. `WordService`：测试搜索 limit=50、空关键词不查全表、已掌握排序。
6. `StudyRecordService`：测试认识/不认识后 correct/wrong、next_review_time、mastered 是否正确。
7. `DebugService`：测试统计汇总、清空学习记录、重建默认词库。

数据库相关测试建议使用测试前清理数据、测试后恢复默认词库，避免污染手工测试环境。

## 真机回归清单

1. 首次安装启动，默认词库自动初始化。
2. 冷启动速度可接受，首页不长时间白屏。
3. 首页、学习、复习、设置、搜索、统计、词书管理可正常跳转。
4. 学习记录保存后，首页统计立即刷新。
5. 复习页只显示到期单词。
6. 搜索最多展示 50 条，不输入关键词时为空状态。
7. AI 接口无 API Key 时不发请求并提示。
8. AI 接口弱网/超时时不崩溃。
9. 在线发音失败时提示错误，不影响页面。
10. CSV / JSON 导入成功、重复跳过、非法数据跳过。
11. 深色模式切换后页面颜色正确，重启后保持。
12. 清除应用数据后再次启动能重新初始化。

## 发布阻断标准

以下问题必须修复后才能发布：

1. App 无法启动或首页无法进入。
2. 数据库初始化失败导致核心页面不可用。
3. 学习记录丢失或统计明显错误。
4. API Key 被硬编码或输出到日志。
5. Debug 页面正式版仍明显暴露。
6. release 包无法安装或启动。
