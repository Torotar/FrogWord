import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { SettingItem } from '../components/SettingItem';
import { SUB_PAGE_CONTENT_OVERLAP } from '../components/HdsSubPageLayout';
import { createHdsSubPageTitleBarOptions } from '../components/HdsSubPageTitleBarOptions';
import { CacheService } from '../services/CacheService';
import { DatabaseService } from '../services/DatabaseService';
import { PreferencesService } from '../services/PreferencesService';
import { StudyRecordService } from '../services/StudyRecordService';
import { Constants } from '../utils/Constants';
import { ThemeColor } from '../utils/ThemeColor';

@Entry
@Component
struct MoreSettingsPage {
  @State private isLoading: boolean = true;
  @State private cacheSizeDesc: string = '';
  @State private searchEngine: string = Constants.DEFAULT_SEARCH_ENGINE;
  @StorageLink('resolvedDarkMode') darkMode: boolean = false;
  @StorageLink('materialEffectMode') materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;
  private pageScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadSettings();
  }

  private async loadSettings(): Promise<void> {
    this.isLoading = true;
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      await PreferencesService.init(context);
      this.cacheSizeDesc = CacheService.getCacheSize(context).display;
      this.searchEngine = await PreferencesService.getSearchEngine();
    } catch (error) {
      console.error('MoreSettingsPage loadSettings failed: ' + JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  private async updateSearchEngine(index: number): Promise<void> {
    this.searchEngine = index === 1 ? Constants.SEARCH_ENGINE_YOUDAO : Constants.SEARCH_ENGINE_CAMBRIDGE;
    await PreferencesService.setSearchEngine(this.searchEngine);
  }

  private searchEngineIndex(): number {
    return this.searchEngine === Constants.SEARCH_ENGINE_YOUDAO ? 1 : 0;
  }

  private searchEngineLabel(): string {
    return this.searchEngine === Constants.SEARCH_ENGINE_YOUDAO ? '有道词典' : '剑桥词典';
  }

  private confirmResetStudyRecords(): void {
    AlertDialog.show({
      title: '确认重置单词记录',
      message: '该操作会清空所有学习、复习和统计记录，但不会删除词库。确定要重置吗？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '确认重置',
        fontColor: ThemeColor.get(this.darkMode).danger,
        action: () => {
          this.resetStudyRecords();
        }
      }
    });
  }

  private async resetStudyRecords(): Promise<void> {
    try {
      await StudyRecordService.resetAllRecords();
      this.showToast('单词记录已重置');
    } catch (error) {
      console.error('MoreSettingsPage resetStudyRecords failed: ' + JSON.stringify(error));
      this.showToast('重置单词记录失败');
    }
  }

  private confirmClearCache(): void {
    AlertDialog.show({
      title: '确认清除缓存',
      message: '当前缓存占用：' + this.cacheSizeDesc + '\n\n该操作会删除在线词书导入时产生的临时文件，不会影响词库和学习记录。确定要清除吗？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '确认清除',
        fontColor: '#F59E0B',
        action: () => {
          this.clearCache();
        }
      }
    });
  }

  private clearCache(): void {
    try {
      const context = getContext(this) as common.Context;
      const clearedSize = CacheService.clearCache(context);
      this.cacheSizeDesc = '0 B';
      this.showToast('缓存已清除（' + clearedSize.display + '）');
    } catch (error) {
      console.error('MoreSettingsPage clearCache failed: ' + JSON.stringify(error));
      this.showToast('清除缓存失败');
    }
  }

  private aiConfigIcon(): Resource {
    return this.darkMode ? $r('app.media.ai_config_dark') : $r('app.media.ai_config_light');
  }

  private definitionIcon(): Resource {
    return this.darkMode ? $r('app.media.definition_dark') : $r('app.media.definition_light');
  }

  private clearCacheIcon(): Resource {
    return this.darkMode ? $r('app.media.clear_cache_dark') : $r('app.media.clear_cache_light');
  }

  private resetDataIcon(): Resource {
    return this.darkMode ? $r('app.media.reset_data_dark') : $r('app.media.reset_data_light');
  }

  build() {
    HdsNavDestination() {
      List({ scroller: this.pageScroller }) {
        if (this.isLoading) {
          ListItem() {
            Text('正在加载设置...')
              .fontSize(16)
              .fontColor(ThemeColor.get(this.darkMode).textSecondary)
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 40 })
          }
          .width('100%')
          .reuseId('more-settings-loading')
        } else {
          ListItem() {
            Column() {
              Row() {
                Image(this.definitionIcon()).width(22).height(22).objectFit(ImageFit.Contain).margin({ right: 12 })
                Column() {
                  Text('搜索引擎').fontSize(15).fontColor(ThemeColor.get(this.darkMode).textPrimary)
                  Text('选择在线查词来源').fontSize(13).fontColor(ThemeColor.get(this.darkMode).textSecondary)
                    .margin({ top: 4 }).width('100%').lineHeight(18)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ right: 12 })
                Select(['剑桥词典', '有道词典'].map((label: string): SelectOption => ({ value: label })))
                  .selected(this.searchEngineIndex())
                  .value(this.searchEngineLabel())
                  .height(36)
                  .padding({ left: 12, right: 8 })
                  .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
                  .borderRadius(12)
                  .font({ size: 13, weight: FontWeight.Medium })
                  .fontColor(ThemeColor.get(this.darkMode).primary)
                  .selectedOptionFont({ size: 16, weight: FontWeight.Medium })
                  .optionFont({ size: 16, weight: FontWeight.Normal })
                  .onSelect((index: number) => { this.updateSearchEngine(index); })
              }
              .width('100%')
              .padding({ top: 18, bottom: 18 })
              Divider().color(ThemeColor.get(this.darkMode).border)
              SettingItem({
                icon: this.aiConfigIcon(), title: 'AI 接口配置', description: '自定义或兼容接口', value: '去配置', showArrow: true,
                textPrimary: ThemeColor.get(this.darkMode).textPrimary, textSecondary: ThemeColor.get(this.darkMode).textSecondary,
                primary: ThemeColor.get(this.darkMode).primary, darkMode: this.darkMode,
                onItemClick: () => { router.pushUrl({ url: 'pages/AiConfigPage' }); }
              })
              Divider().color(ThemeColor.get(this.darkMode).border)
              SettingItem({
                icon: this.clearCacheIcon(), title: '清除缓存', description: '删除在线词书导入产生的临时文件（当前：' + this.cacheSizeDesc + '）', value: '清除', showArrow: true,
                textPrimary: ThemeColor.get(this.darkMode).textPrimary, textSecondary: ThemeColor.get(this.darkMode).textSecondary,
                primary: ThemeColor.get(this.darkMode).danger, darkMode: this.darkMode,
                onItemClick: () => { this.confirmClearCache(); }
              })
              Divider().color(ThemeColor.get(this.darkMode).border)
              SettingItem({
                icon: this.resetDataIcon(), title: '重置单词记录', description: '清空学习、复习、统计记录，不删除词库', value: '重置', showArrow: true,
                textPrimary: ThemeColor.get(this.darkMode).textPrimary, textSecondary: ThemeColor.get(this.darkMode).textSecondary,
                primary: ThemeColor.get(this.darkMode).danger, darkMode: this.darkMode,
                onItemClick: () => { this.confirmResetStudyRecords(); }
              })
              if (Constants.DEBUG_MODE) {
                Divider().color(ThemeColor.get(this.darkMode).border)
                SettingItem({
                  title: '开发者调试', description: '数据库状态、清空记录、重建默认词库', value: '打开', showArrow: true,
                  textPrimary: ThemeColor.get(this.darkMode).textPrimary, textSecondary: ThemeColor.get(this.darkMode).textSecondary,
                  primary: ThemeColor.get(this.darkMode).danger, darkMode: this.darkMode,
                  onItemClick: () => { router.pushUrl({ url: 'pages/DebugDatabasePage' }); }
                })
              }
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 4, bottom: 4 })
            .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
            .borderRadius(20)
            .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
            .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
          }
          .width('100%')
          .reuseId('more-settings-actions')
        }

        ListItem() {
          Column().width('100%').height(32)
        }
        .width('100%')
        .reuseId('more-settings-bottom-spacer')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 20, right: 20, top: 0 })
      .contentStartOffset(-SUB_PAGE_CONTENT_OVERLAP)
      .contentEndOffset(SUB_PAGE_CONTENT_OVERLAP)
      .cachedCount(2)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .enableScrollInteraction(true)
      .friction(0.75)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .titleBar(createHdsSubPageTitleBarOptions('更多设置', this.darkMode, this.materialEffectMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed(() => {
      router.back();
      return true;
    })
    .bindToScrollable([this.pageScroller])
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    .backgroundColor(ThemeColor.get(this.darkMode).background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
