# Wordcard 项目协作指南

本文件适用于整个 `wordcard` 仓库。修改子目录中的代码前，若存在更近层级的 `AGENTS.md`，以更近层级的规则为准。

## 项目定位

- 这是一个面向手机的 HarmonyOS Stage 模型背单词应用，主要使用 ArkTS、ArkUI 和 HDS（`@kit.UIDesignKit`）。
- 当前只有 `entry` 应用模块；入口 Ability 为 `EntryAbility`，启动页为 `pages/Index`。
- 构建配置为 HarmonyOS API 24，兼容 API 22；应用包名为 `com.torotar.wordcard`。
- 核心功能包括词书管理、单词学习、到期复习、错词重学、拼写训练、统计、学习计划、发音、AI 配置以及 WebDAV 备份恢复。
- 当前重点上下文：**复习单词界面**。相关改动优先从 `entry/src/main/ets/pages/ReviewPage.ets` 开始追踪，但必须同时检查它依赖的服务、偏好设置和复用组件。

## 开始工作前

1. 先阅读目标页面及其直接依赖，不根据文件名猜测行为。
2. 保持用户已有改动；不要回退、覆盖或顺手重构与当前任务无关的内容。
3. 搜索优先使用 `rg` / `rg --files`，并排除 `build`、`.hvigor`、`oh_modules` 等生成目录。
4. 修改前确认真实调用链：页面状态 -> Service -> Model / Preferences / RDB -> 统计或备份消费者。
5. 中文文件按 UTF-8 读取；在 Windows PowerShell 中使用 `Get-Content -Encoding utf8`，不要把终端显示的乱码写回源文件。

## 目录与职责

```text
AppScope/
  app.json5                         应用包名和正式版本元数据
entry/src/main/
  module.json5                      Ability、权限、设备类型和备份扩展
  resources/base/profile/
    main_pages.json                 页面路由注册表
    backup_config.json              系统备份配置
  ets/entryability/EntryAbility.ets 启动、主题、数据库和偏好初始化
  ets/pages/                        页面和页面级状态
  ets/components/                   可复用 ArkUI/HDS 组件
  ets/services/                     数据、学习、音频、网络和偏好逻辑
  ets/model/                        跨层数据结构
  ets/algorithm/                    间隔重复算法
  ets/utils/                        常量、主题、解析和日期工具
entry/src/test/                     本地单元测试入口
entry/src/ohosTest/                 真机/模拟器测试入口
test/                               尚未接入默认测试入口的 UI 测试示例
docs/                               测试、隐私、版本冻结和发布检查清单
```

不要手工修改 `entry/build/`、`.hvigor/`、`oh_modules/`、`.idea/` 中的生成物或本机状态。`local.properties` 和签名材料是机器相关配置，不应作为业务代码修改。

## 运行时架构

- `EntryAbility` 启动时初始化 `DatabaseService`、`PreferencesService`、主题状态和沉浸式系统栏；页面不要另建一套全局初始化流程。
- `Index.ets` 是主壳，使用 `HdsNavigation` 与 `HdsTabs` 组织首页、统计和设置入口。二级页通过 `router.pushUrl` 打开。
- 新增 `@Entry` 页面时，必须同步注册到 `entry/src/main/resources/base/profile/main_pages.json`。
- 页面负责展示和短生命周期交互状态；可复用查询、持久化、网络、音频及业务计算放入对应 Service。
- 跨页面主题状态使用既有 `AppStorage` / `@StorageLink`：`resolvedDarkMode` 与 `materialEffectMode`。颜色从 `ThemeColor.get(darkMode)` 取得。
- 二级页沿用 `HdsNavDestination`、`createHdsSubPageTitleBarOptions(...)` 和 `HdsSubPageLayout` 中的布局常量；主 Tab 标题沿用 `createHdsTabTitleBarOptions(...)`。

## 数据与持久化规则

- 主数据库为 `wordflow.db`，版本号在 `Constants.DATABASE_VERSION`。核心表包括 `word_book`、`words`、`study_record`、`study_daily`、`study_event` 和 `study_session`。
- 数据库结构变化必须同时完成：提高数据库版本、补充 `DatabaseService.migrate(...)`、保证全新安装的 `createTables()` 结构一致，并检查备份恢复兼容性。
- 查询返回的 `ResultSet` 必须在 `finally` 中关闭。SQL 使用绑定参数，禁止拼接用户输入。
- 学习结果统一经 `StudyRecordService` 记录；学习时长统一经 `StudySessionService` 开始、刷新和结束，不能只更新页面计数。
- 学习计划字段跨越 `StudyPlan.ets`、`PreferencesService`、`StudyPlanService`、`StudyPlanPage`、`StudyPage` 和 `ReviewPage`。新增或修改计划项时要完整贯通，不能只增加设置控件。
- 偏好设置必须具有明确默认值、类型化 getter/setter 和重启后的读取路径。不要在多个页面复制同一个默认值而不检查 `Constants`。
- WebDAV 自定义远端路径必须被尊重；只有空值时才回退到 `/wordcard`。备份内容变化时检查完整学习状态，而不只是单词表。
- API Key、WebDAV 密码和签名密码不得硬编码到新源码、打印到日志或写入测试夹具。不要在文档或回复中回显 `build-profile.json5` 内的签名秘密。

## 复习单词界面

`ReviewPage.ets` 不是单一列表页，修改时必须保留以下状态机和行为：

- 页面模式：`list`（到期列表）与 `review`（逐卡复习）。
- 复习阶段：`review`（认识/不认识判断）与 `spell`（复习后的拼写训练）。
- 数据来源：按已选词书查询到期词，应用时间筛选，并排除当天已经持久化完成和本次会话已完成的单词。
- 数量约束：复习目标和每组数量来自 `PreferencesService`；列表、进度、完成态和下一组必须使用同一口径。
- 回退语义：在逐卡模式按返回键应先回到复习列表；只有列表模式才退出页面。
- 生命周期：进入复习时开始 `StudySessionService` 会话；切后台、离开页面和完成复习时刷新或结束时长，避免重复累计和丢失。
- 答题落库：认识/不认识由 `StudyRecordService.recordAnswer(..., 'review', ...)` 处理；当天完成 ID 通过现有 Preferences 路径持久化。
- 发音：自动发音、释义展示后发音及标题栏菜单共用现有偏好；播放图标动画必须跟随 `AudioService` 的真实播放 Promise 生命周期。
- 拼写训练：继续复用 `ReviewSpellingTraining`，不要在页面中复制第二套拼写判定逻辑。
- UI：保持列表滚动位置、时间筛选、空状态、深浅色、材质效果、系统安全区和 HDS 标题栏行为。

复习页改动至少人工核对：无词书、无到期词、不同时间筛选、开始复习、认识与不认识、自动发音、进入拼写训练、完成态、返回列表、切后台再回来以及深浅色模式。

## ArkTS 与 ArkUI 约定

- 保持严格类型：为页面参数、回调、集合元素和异步返回值声明类型，避免 `any`、无类型对象和不受控类型断言。
- 遵循当前 ArkTS 能力边界；不要引入 JavaScript 中可用但 ArkTS 严格模式不支持的动态写法。
- `@State` 只保存会影响渲染的状态；控制器、计时器、Set 和临时缓存保持普通字段，并在页面退出时清理。
- 异步动作要有防重复状态，并在 `try/catch/finally` 中恢复 UI；失败时不得提前显示成功或静默吞掉关键数据错误。
- 列表 `ForEach` 使用稳定且唯一的 key。可点击范围绑定到用户看到的完整容器，而不是只绑定内部文字。
- 保持组件尺寸和布局稳定，长文本要换行或限制行数，不能覆盖相邻控件；同时检查窄屏和系统大字体下的表现。
- 复用已有 HDS 标题栏、主题色、间距和卡片圆角，不在局部页面引入不一致的导航壳或任意强调色。
- 线性 SVG 图标默认保留资源自身外观，不通过运行时 `fillColor` / `fill` 强行改色；需要深浅色时使用已有 light/dark 资源对。
- 注释只解释不明显的业务约束或状态转换，不为直观代码添加逐行说明。

## 常见跨文件改动

- 新页面：页面文件 + `main_pages.json` + 发起导航的入口 + 返回行为。
- 新偏好项：`Constants` 默认值 + `PreferencesService` key/getter/setter + 页面加载和保存 + 重启验证。
- 新学习规则：页面入口 + `StudyPage`/`ReviewPage` 消费 + `StudyRecordService` 记录 + 统计口径 + 测试。
- 数据库字段或表：版本迁移 + 新装建表 + Model/Service + 备份恢复 + 旧数据升级验证。
- 主题或材质：`ThemeService` / `ThemeColor` + `AppStorage` 状态 + 深浅色和系统栏验证。
- 版本变更：以 `AppScope/app.json5` 的 `versionCode` / `versionName` 为正式元数据，同时核对 `Constants.APP_VERSION`，不要只改页面显示文字。

## 构建与验证

本机 DevEco Studio 工具位于 `D:\application\other\huawei\DevEco Studio`。在仓库根目录执行调试 HAP 编译：

```powershell
$env:DEVECO_SDK_HOME = 'D:\application\other\huawei\DevEco Studio\sdk'
& 'D:\application\other\huawei\DevEco Studio\tools\node\node.exe' `
  'D:\application\other\huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js' `
  --mode module -p product=default -p module=entry@default `
  assembleHap --analyze=normal --parallel --incremental --no-daemon
```

- 源码修改后至少执行一次上述 `assembleHap`，并报告第一条真实 ArkTS 编译错误，不能只做文本搜索。
- HAP 通常输出到 `entry/build/default/outputs/default/`；交付前按实际生成文件确认名称和时间，避免引用旧包。
- 当前命令可能提示 `No signingConfig found for product default`；这不阻止源码编译和未签名 HAP 打包，但真机安装或发布仍需在 DevEco Studio 中使用匹配的签名配置单独验证。
- `entry/src/test` 和 `entry/src/ohosTest` 是当前 Hvigor 识别的测试目录。仓库根目录 `test/` 仍是 UI 自动化示例，未迁入测试入口前不能把它们描述为已执行或已通过。
- UI、导航、音频、系统栏、键盘、后台时长和数据库升级属于真机行为；仅编译成功不能替代真机验证，应明确说明未验证的部分。
- 发布前同时检查 `docs/TEST_PLAN.md`、`docs/PRIVACY_CHECKLIST.md`、`docs/RELEASE_CHECKLIST.md` 和 `docs/VERSION_FREEZE_PLAN.md`。

## 完成标准

1. 改动严格落在用户指定范围，没有夹带无关重构或资源变化。
2. 页面、Service、持久化、统计和备份之间的数据口径一致。
3. 新增路由、偏好、数据库版本和资源均已补齐必要注册或迁移。
4. 深浅色、空状态、加载、失败、防重复点击和返回行为得到覆盖。
5. ArkTS 构建通过；无法进行的真机或自动化验证被明确列出。
6. 最终说明包含修改文件、可观察行为、验证命令与结果，不把推测写成已验证事实。
