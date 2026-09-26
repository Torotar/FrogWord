import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { HdsNavDestination, HdsNavDestinationTitleMode, NestedScrollInfo } from '@kit.UIDesignKit';
import { SUB_PAGE_CONTENT_OVERLAP } from '../components/HdsSubPageLayout';
import { createHdsSubPageTitleBarOptions } from '../components/HdsSubPageTitleBarOptions';
import { AiConfig } from '../model/AiConfig';
import { AiConfigService } from '../services/AiConfigService';
import { AiService } from '../services/AiService';
import { DatabaseService } from '../services/DatabaseService';
import { PreferencesService } from '../services/PreferencesService';
import { Constants } from '../utils/Constants';
import { ThemeColor } from '../utils/ThemeColor';

@Entry
@Component
struct AiConfigPage {
  @State private isLoading: boolean = true;
  @State private isTesting: boolean = false;
  @State private provider: string = 'openai-compatible';
  @State private baseUrl: string = '';
  @State private model: string = '';
  @State private apiKey: string = '';
  @State private deepSeekApiKey: string = '';
  @State private xiaomiApiKey: string = '';
  @State private customApiKey: string = '';
  @State private deepSeekModel: string = '';
  @State private xiaomiModel: string = '';
  @State private customModel: string = '';
  @State private availableModels: string[] = [];
  @State private formRevision: number = 0;
  @State private resultText: string = '';
  @StorageLink('resolvedDarkMode') darkMode: boolean = false;
  @StorageLink('materialEffectMode') materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;
  private parentScroller: Scroller = new Scroller();
  private childScroller: Scroller = new Scroller();
  private nestedScrollInfo: NestedScrollInfo[] = [{ parent: this.parentScroller, child: this.childScroller }];

  aboutToAppear(): void {
    this.loadConfig();
  }

  private async loadConfig(): Promise<void> {
    this.isLoading = true;
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      await PreferencesService.init(context);
      const config: AiConfig = await AiConfigService.getConfig();
      this.provider = config.aiProvider;
      this.baseUrl = config.aiBaseUrl;
      this.model = config.aiModel;
      this.deepSeekApiKey = await AiConfigService.getApiKey('deepseek');
      this.xiaomiApiKey = await AiConfigService.getApiKey('xiaomi-mimo-token-plan');
      this.customApiKey = await AiConfigService.getApiKey('openai-compatible');
      this.deepSeekModel = await AiConfigService.getModel('deepseek');
      this.xiaomiModel = await AiConfigService.getModel('xiaomi-mimo-token-plan');
      this.customModel = await AiConfigService.getModel('openai-compatible');
      this.migrateLegacyApiKey(config.aiApiKey);
      this.migrateLegacyModel(config.aiModel);
      this.apiKey = this.getCachedApiKey(this.provider);
      this.model = this.getCachedModel(this.provider);
      this.availableModels = [];
    } catch (error) {
      console.error('AiConfigPage loadConfig failed: ' + JSON.stringify(error));
      this.resultText = 'AI 配置加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({
      message: message,
      duration: 2000
    });
  }

  private async saveConfig(): Promise<void> {
    try {
      this.cacheCurrentApiKey();
      this.cacheCurrentModel();
      await AiConfigService.saveConfig(this.buildCurrentConfig());
      await AiConfigService.saveApiKey('deepseek', this.deepSeekApiKey);
      await AiConfigService.saveApiKey('xiaomi-mimo-token-plan', this.xiaomiApiKey);
      await AiConfigService.saveApiKey('openai-compatible', this.customApiKey);
      await AiConfigService.saveModel('deepseek', this.deepSeekModel);
      await AiConfigService.saveModel('xiaomi-mimo-token-plan', this.xiaomiModel);
      await AiConfigService.saveModel('openai-compatible', this.customModel);
      this.resultText = '';
      this.showToast('AI 配置已保存');
    } catch (error) {
      console.error('AiConfigPage saveConfig failed: ' + JSON.stringify(error));
      this.showToast('AI 配置保存失败');
    }
  }

  private buildCurrentConfig(): AiConfig {
    return {
      aiProvider: this.provider,
      aiBaseUrl: this.baseUrl,
      aiModel: this.model,
      aiApiKey: this.apiKey
    };
  }

  private async testModels(): Promise<void> {
    this.cacheCurrentApiKey();
    this.cacheCurrentModel();
    this.isTesting = true;
    this.resultText = '';
    this.showToast('正在拉取模型列表...');
    try {
      const modelsText: string = await AiService.fetchAvailableModels(this.buildCurrentConfig());
      const models: string[] = this.parseModels(modelsText);
      this.availableModels = models;
      if (models.length > 0) {
        if (this.model.trim().length === 0 || !this.isModelAvailable(this.model, models)) {
          this.model = models[0];
          this.setCachedModel(this.provider, this.model);
        }
        this.showToast('已获取 ' + models.length.toString() + ' 个模型');
      } else {
        this.showToast(modelsText);
      }
    } catch (error) {
      console.error('testModels failed: ' + JSON.stringify(error));
      this.showToast('模型列表拉取失败');
    } finally {
      this.isTesting = false;
    }
  }

  private parseModels(modelsText: string): string[] {
    const models: string[] = [];
    const lines: string[] = modelsText.split('\n');
    for (let index: number = 0; index < lines.length; index++) {
      const modelName: string = lines[index].trim();
      if (modelName.length > 0 && modelName.indexOf('失败') < 0 && modelName.indexOf('为空') < 0 && modelName.indexOf('{') < 0) {
        models.push(modelName);
      }
    }
    return models;
  }

  private isModelAvailable(modelName: string, models: string[]): boolean {
    for (let index: number = 0; index < models.length; index++) {
      if (models[index] === modelName) {
        return true;
      }
    }
    return false;
  }

  private selectProvider(provider: string): void {
    this.cacheCurrentApiKey();
    this.cacheCurrentModel();
    this.provider = provider;
    this.availableModels = [];
    this.apiKey = this.getCachedApiKey(provider);
    this.model = this.getCachedModel(provider);
    this.formRevision++;
    if (provider === 'deepseek') {
      this.baseUrl = 'https://api.deepseek.com';
    } else if (provider === 'xiaomi-mimo-token-plan') {
      this.baseUrl = 'https://token-plan-cn.xiaomimimo.com/v1';
    } else {
      this.baseUrl = '';
    }
  }

  private migrateLegacyApiKey(apiKey: string): void {
    if (apiKey.length === 0) {
      return;
    }
    if (this.provider === 'deepseek' && this.deepSeekApiKey.length === 0) {
      this.deepSeekApiKey = apiKey;
    } else if (this.provider === 'xiaomi-mimo-token-plan' && this.xiaomiApiKey.length === 0) {
      this.xiaomiApiKey = apiKey;
    } else if (this.provider === 'openai-compatible' && this.customApiKey.length === 0) {
      this.customApiKey = apiKey;
    }
  }

  private migrateLegacyModel(model: string): void {
    if (model.length === 0) {
      return;
    }
    if (this.provider === 'deepseek' && this.deepSeekModel.length === 0) {
      this.deepSeekModel = model;
    } else if (this.provider === 'xiaomi-mimo-token-plan' && this.xiaomiModel.length === 0) {
      this.xiaomiModel = model;
    } else if (this.provider === 'openai-compatible' && this.customModel.length === 0) {
      this.customModel = model;
    }
  }

  private cacheCurrentApiKey(): void {
    this.setCachedApiKey(this.provider, this.apiKey);
  }

  private cacheCurrentModel(): void {
    this.setCachedModel(this.provider, this.model);
  }

  private getCachedApiKey(provider: string): string {
    if (provider === 'deepseek') {
      return this.deepSeekApiKey;
    }
    if (provider === 'xiaomi-mimo-token-plan') {
      return this.xiaomiApiKey;
    }
    return this.customApiKey;
  }

  private setCachedApiKey(provider: string, apiKey: string): void {
    if (provider === 'deepseek') {
      this.deepSeekApiKey = apiKey;
    } else if (provider === 'xiaomi-mimo-token-plan') {
      this.xiaomiApiKey = apiKey;
    } else {
      this.customApiKey = apiKey;
    }
  }

  private getCachedModel(provider: string): string {
    if (provider === 'deepseek') {
      return this.deepSeekModel;
    }
    if (provider === 'xiaomi-mimo-token-plan') {
      return this.xiaomiModel;
    }
    return this.customModel;
  }

  private setCachedModel(provider: string, model: string): void {
    if (provider === 'deepseek') {
      this.deepSeekModel = model;
    } else if (provider === 'xiaomi-mimo-token-plan') {
      this.xiaomiModel = model;
    } else {
      this.customModel = model;
    }
  }

  private isCustomProvider(): boolean {
    return this.provider === 'openai-compatible';
  }

  private getProviderLabel(provider: string): string {
    if (provider === 'deepseek') {
      return 'DeepSeek';
    }
    if (provider === 'xiaomi-mimo-token-plan') {
      return 'Xiaomi MiMo Token Plan';
    }
    return 'OpenAI 兼容接口';
  }

  private getProviderIndex(): number {
    if (this.provider === 'deepseek') {
      return 0;
    }
    if (this.provider === 'xiaomi-mimo-token-plan') {
      return 1;
    }
    return 2;
  }

  private selectProviderByIndex(index: number): void {
    if (index === 0) {
      this.selectProvider('deepseek');
    } else if (index === 1) {
      this.selectProvider('xiaomi-mimo-token-plan');
    } else {
      this.selectProvider('openai-compatible');
    }
  }

  private getModelSelectOptions(): SelectOption[] {
    if (this.availableModels.length > 0) {
      return this.availableModels.map((modelName: string): SelectOption => ({ value: modelName }));
    }
    const fallbackModel: string = this.model.trim().length > 0 ? this.model : '请先拉取模型列表';
    return [{ value: fallbackModel }];
  }

  private getModelIndex(): number {
    const index: number = this.availableModels.indexOf(this.model);
    return index >= 0 ? index : 0;
  }

  @Builder
  private buildModelMenu() {
    Menu() {
      ForEach(this.availableModels, (modelName: string) => {
        MenuItem({ content: modelName })
          .selected(this.model === modelName)
          .selectIcon(true)
          .contentFont({
            size: 13,
            weight: this.model === modelName ? FontWeight.Medium : FontWeight.Normal
          })
          .onChange((selected: boolean) => {
            if (selected) {
              this.model = modelName;
              this.setCachedModel(this.provider, modelName);
            }
          })
      }, (modelName: string) => modelName)
    }
    .font({
      size: 13,
      weight: FontWeight.Normal
    })
    .radius(12)
  }

  @Builder
  private sectionTitle(title: string) {
    Text(title)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(ThemeColor.get(this.darkMode).textPrimary)
      .width('100%')
  }

  @Builder
  private buildProviderSelector() {
    Column() {
      this.sectionTitle('AI 服务商')

      Select([
        { value: 'DeepSeek' },
        { value: 'Xiaomi MiMo Token Plan' },
        { value: 'OpenAI 兼容接口' }
      ])
      .selected(this.getProviderIndex())
      .value(this.getProviderLabel(this.provider))
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .margin({ top: 8 })
      .backgroundColor(ThemeColor.get(this.darkMode).background)
      .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
      .borderRadius(12)
      .font({
        size: 14,
        weight: FontWeight.Normal
      })
      .fontColor(ThemeColor.get(this.darkMode).textPrimary)
      .selectedOptionFont({
        size: 16,
        weight: FontWeight.Medium
      })
      .optionFont({
        size: 16,
        weight: FontWeight.Normal
      })
      .onSelect((index: number) => {
        this.selectProviderByIndex(index);
      })
    }
    .width('100%')
    .margin({ bottom: 18 })
  }

  @Builder
  private buildBaseUrlInput() {
    Column() {
      this.sectionTitle('Base URL')

      if (this.isCustomProvider()) {
        TextInput({ text: this.baseUrl, placeholder: '请输入兼容 OpenAI 的 Base URL' })
          .id('base-url-' + this.formRevision.toString())
          .height(48)
          .type(InputType.Normal)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
          .placeholderColor(ThemeColor.get(this.darkMode).textSecondary)
          .backgroundColor(ThemeColor.get(this.darkMode).background)
          .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
          .padding({ left: 16, right: 16 })
          .borderRadius(12)
          .margin({ top: 8 })
          .onChange((text: string) => {
            this.baseUrl = text;
            this.availableModels = [];
          })
      } else {
        Text(this.baseUrl)
          .width('100%')
          .height(48)
          .fontSize(14)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
          .padding({ left: 16, right: 16 })
          .margin({ top: 8 })
          .backgroundColor(ThemeColor.get(this.darkMode).background)
          .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
          .borderRadius(12)
      }

      Text('填写兼容 OpenAI Response 格式的服务端点地址')
        .fontSize(12)
        .fontColor(ThemeColor.get(this.darkMode).textSecondary)
        .lineHeight(18)
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
    .margin({ bottom: 18 })
  }

  @Builder
  private buildModelInput() {
    Column() {
      this.sectionTitle('模型名')

      Select(this.getModelSelectOptions())
      .selected(this.getModelIndex())
      .value(this.model.trim().length > 0 ? this.model : '请先拉取模型列表')
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .margin({ top: 8 })
      .backgroundColor(ThemeColor.get(this.darkMode).background)
      .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
      .borderRadius(12)
      .font({
        size: 14,
        weight: FontWeight.Normal
      })
      .fontColor(this.model.trim().length > 0 ? ThemeColor.get(this.darkMode).textPrimary : ThemeColor.get(this.darkMode).textSecondary)
      .selectedOptionFont({
        size: 16,
        weight: FontWeight.Medium
      })
      .optionFont({
        size: 16,
        weight: FontWeight.Normal
      })
      .enabled(this.availableModels.length > 0)
      .onSelect((index: number, value?: string) => {
        if (this.availableModels.length === 0) {
          return;
        }
        const selectedModel: string = value ?? this.availableModels[index];
        this.model = selectedModel;
        this.setCachedModel(this.provider, selectedModel);
      })
    }
    .width('100%')
    .margin({ bottom: 18 })
  }

  @Builder
  private buildApiKeyInput() {
    Column() {
      this.sectionTitle('API Key')

      TextInput({ text: this.apiKey, placeholder: '请输入 API Key' })
        .id('api-key-' + this.formRevision.toString())
        .height(48)
        .type(InputType.Password)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .placeholderColor(ThemeColor.get(this.darkMode).textSecondary)
        .backgroundColor(ThemeColor.get(this.darkMode).background)
        .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
        .padding({ left: 16, right: 16 })
        .borderRadius(12)
        .margin({ top: 8 })
        .onChange((text: string) => {
          this.apiKey = text;
          this.setCachedApiKey(this.provider, text);
        })
    }
    .width('100%')
    .margin({ bottom: 18 })
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Top }) {
        Scroll(this.parentScroller) {
          List({ scroller: this.childScroller }) {
            if (this.isLoading) {
              ListItem() {
                Text('正在加载 AI 配置...')
                  .fontSize(16)
                  .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                  .margin({ top: 16 })
              }
              .width('100%')
              .reuseId('ai-config-loading')
            } else {
              ListItem() {
                Column() {
                  this.buildProviderSelector()
                  this.buildBaseUrlInput()
                  this.buildModelInput()
                  this.buildApiKeyInput()
                }
                .width('100%')
                .padding(20)
                .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
                .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
                .borderRadius(18)
                .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
                .margin({ top: 12 })
              }
              .width('100%')
              .reuseId('ai-config-form')

              ListItem() {
                Column() {
                  Button('保存配置')
                    .width('100%')
                    .buttonStyle(ButtonStyleMode.EMPHASIZED)
                    .controlSize(ControlSize.NORMAL)
                    .role(ButtonRole.NORMAL)
                    .onClick(() => {
                      this.saveConfig();
                    })

                  Button(this.isTesting ? '正在拉取模型...' : '拉取模型列表')
                    .width('100%')
                    .buttonStyle(ButtonStyleMode.NORMAL)
                    .controlSize(ControlSize.NORMAL)
                    .role(ButtonRole.NORMAL)
                    .enabled(!this.isTesting)
                    .margin({ top: 14 })
                    .onClick(() => {
                      this.testModels();
                    })
                }
                .width('100%')
                .padding(20)
                .margin({ top: 14 })
                .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
                .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
                .borderRadius(22)
                .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
              }
              .width('100%')
              .reuseId('ai-config-actions')

              if (this.resultText.length > 0) {
                ListItem() {
                  Text(this.resultText)
                    .width('100%')
                    .fontSize(14)
                    .fontColor(ThemeColor.get(this.darkMode).textPrimary)
                    .lineHeight(22)
                    .padding(16)
                    .margin({ top: 18 })
                    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
                    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
                    .borderRadius(16)
                    .shadow({ radius: 10, color: 'rgba(15, 23, 42, 0.05)', offsetY: 4 })
                }
                .width('100%')
                .reuseId('ai-config-result')
              }
            }

            ListItem() {
              Column().width('100%').height(32)
            }
            .width('100%')
            .reuseId('ai-config-bottom-spacer')
          }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.TopStart)
          .padding({ left: 20, right: 20, top: 0 })
          .contentStartOffset(-SUB_PAGE_CONTENT_OVERLAP)
          .contentEndOffset(SUB_PAGE_CONTENT_OVERLAP)
          .cachedCount(2)
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .enableScrollInteraction(true)
          .friction(0.75)
          .scrollBar(BarState.Auto)
          .nestedScroll({
            scrollForward: NestedScrollMode.PARENT_FIRST,
            scrollBackward: NestedScrollMode.SELF_FIRST
          })
        }
        .layoutWeight(1)
        .width('100%')
        .height('100%')
        .align(Alignment.TopStart)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .titleBar(createHdsSubPageTitleBarOptions('AI 接口配置', this.darkMode, this.materialEffectMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed(() => {
      router.back();
      return true;
    })
    .bindToNestedScrollable(this.nestedScrollInfo)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor(ThemeColor.get(this.darkMode).background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
