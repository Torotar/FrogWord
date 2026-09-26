import { common } from '@kit.AbilityKit';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import router from '@ohos.router';
import { SettingItem } from '../components/SettingItem';
import { DatabaseService } from '../services/DatabaseService';
import { PreferencesService } from '../services/PreferencesService';
import { ThemeService } from '../services/ThemeService';
import { Constants } from '../utils/Constants';
import { ThemeColor } from '../utils/ThemeColor';
import { createHdsTabTitleBarOptions } from '../components/HdsTabTitleBarOptions';

@Component
export struct SettingsPage {
  @Prop @Watch('onReselect') reselectToken: number = 0;
  @State private isLoading: boolean = false;
  @StorageLink('resolvedDarkMode') darkMode: boolean = false;
  @State private themeMode: number = 0;
  @State private materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;
  @State private forgettingCoefficient: number = Constants.DEFAULT_FORGETTING_COEFFICIENT;
  private pageScroller: Scroller = new Scroller();

  private onReselect(): void {
    this.pageScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
  }

  aboutToAppear(): void {
    this.loadSettings();
  }

  onPageShow(): void {
    const context = getContext(this) as common.Context;
    ThemeService.applySystemBars(context, this.darkMode);
    this.loadForgettingCoefficient();
  }

  private async loadSettings(): Promise<void> {
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      await PreferencesService.init(context);
      this.themeMode = await ThemeService.getThemeMode();
      this.materialEffectMode = await PreferencesService.getMaterialEffectMode();
      AppStorage.setOrCreate('materialEffectMode', this.materialEffectMode);
      this.forgettingCoefficient = await PreferencesService.getForgettingCoefficient();
    } catch (error) {
      console.error('SettingsPage loadSettings failed: ' + JSON.stringify(error));
    } finally {
      this.isLoading = false;
    }
  }

  private async updateThemeMode(mode: number): Promise<void> {
    this.themeMode = mode;
    const context = getContext(this) as common.Context;
    const resolvedDarkMode: boolean = await ThemeService.applyThemeMode(context, mode);
    this.darkMode = resolvedDarkMode;
  }

  private async updateMaterialEffectMode(mode: number): Promise<void> {
    this.materialEffectMode = mode;
    AppStorage.setOrCreate('materialEffectMode', mode);
    await PreferencesService.setMaterialEffectMode(mode);
  }

  private async loadForgettingCoefficient(): Promise<void> {
    this.forgettingCoefficient = await PreferencesService.getForgettingCoefficient();
  }

  private forgettingCoefficientLabel(value: number): string {
    if (value <= 0.3) {
      return '轻松';
    } else if (value <= 0.5) {
      return '标准';
    } else if (value <= 0.7) {
      return '紧凑';
    } else {
      return '密集';
    }
  }

  private themeModeLabel(mode: number): string {
    if (mode === 0) {
      return '自动';
    } else if (mode === 1) {
      return '浅色';
    } else {
      return '深色';
    }
  }

  private materialEffectModeLabel(mode: number): string {
    if (mode === 0) {
      return '禁用';
    } else if (mode === 1) {
      return '流畅';
    } else if (mode === 2) {
      return '轻柔';
    } else if (mode === 3) {
      return '精美';
    } else {
      return '精美';
    }
  }

  private materialEffectModeDescription(): string {
    if (this.materialEffectMode === 0) {
      return '关闭标题区域和底部页签的沉浸光感。';
    } else if (this.materialEffectMode === 1) {
      return '流畅档位，光影效果更克制。';
    } else if (this.materialEffectMode === 2) {
      return '轻柔档位，兼顾清晰度和氛围。';
    } else {
      return '精美档位，强化通透感和材质层次。';
    }
  }

  private displayModeIcon(): Resource {
    return this.darkMode ? $r('app.media.display_mode_dark') : $r('app.media.display_mode_light');
  }

  private materialEffectIcon(): Resource {
    return this.darkMode ? $r('app.media.material_effect_dark') : $r('app.media.material_effect_light');
  }

  private studyPlanIcon(): Resource {
    return this.darkMode ? $r('app.media.study_plan_dark') : $r('app.media.study_plan_light');
  }

  private forgettingIcon(): Resource {
    return this.darkMode ? $r('app.media.forgetting_coefficient_dark') : $r('app.media.forgetting_coefficient_light');
  }

  private wordBookIcon(): Resource {
    return this.darkMode ? $r('app.media.book_dark') : $r('app.media.book_light');
  }

  private webDavIcon(): Resource {
    return this.darkMode ? $r('app.media.webdav_dark') : $r('app.media.webdav_light');
  }

  private moreSettingsIcon(): Resource {
    return this.darkMode ? $r('app.media.settings_dark') : $r('app.media.settings_light');
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      HdsNavigation() {
        List({ scroller: this.pageScroller }) {
          if (this.isLoading) {
            ListItem() {
              Column() {
                Text('正在加载设置...')
                  .fontSize(16)
                  .fontColor(this.darkMode ? '#CBD5E1' : ThemeColor.get(this.darkMode).textSecondary)
                  .margin({ top: 40 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
            }
            .width('100%')
            .reuseId('settings-loading')
          } else {
            ListItem() {
              Column() {
              Text('外观')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                .width('100%')
                .margin({ bottom: 14 })

              Row() {
                Image(this.displayModeIcon())
                  .width(22)
                  .height(22)
                  .objectFit(ImageFit.Contain)
                  .margin({ right: 12 })
                Text('显示模式')
                  .fontSize(15)
                  .fontColor(ThemeColor.get(this.darkMode).textPrimary)
                  .layoutWeight(1)
                Select([0, 1, 2].map((mode: number): SelectOption => ({ value: this.themeModeLabel(mode) })))
                  .selected(this.themeMode)
                  .value(this.themeModeLabel(this.themeMode))
                  .height(36)
                  .padding({ left: 12, right: 8 })
                  .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
                  .borderRadius(12)
                  .font({ size: 13, weight: FontWeight.Medium })
                  .fontColor(ThemeColor.get(this.darkMode).primary)
                  .selectedOptionFont({ size: 16, weight: FontWeight.Medium })
                  .optionFont({ size: 16, weight: FontWeight.Normal })
                  .onSelect((index: number) => { this.updateThemeMode(index); })
              }
              .width('100%')

              Divider().color(ThemeColor.get(this.darkMode).border).margin({ top: 16 })

              Row() {
                Image(this.materialEffectIcon())
                  .width(22)
                  .height(22)
                  .objectFit(ImageFit.Contain)
                  .margin({ right: 12 })
                Column() {
                  Text('沉浸光感')
                    .fontSize(15)
                    .fontColor(ThemeColor.get(this.darkMode).textPrimary)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Select([0, 1, 2, 3].map((mode: number): SelectOption => ({ value: this.materialEffectModeLabel(mode) })))
                  .selected(this.materialEffectMode)
                  .value(this.materialEffectModeLabel(this.materialEffectMode))
                  .height(36)
                  .padding({ left: 12, right: 8 })
                  .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
                  .borderRadius(12)
                  .font({ size: 13, weight: FontWeight.Medium })
                  .fontColor(ThemeColor.get(this.darkMode).primary)
                  .selectedOptionFont({ size: 16, weight: FontWeight.Medium })
                  .optionFont({ size: 16, weight: FontWeight.Normal })
                  .onSelect((index: number) => { this.updateMaterialEffectMode(index); })
              }
              .width('100%')
              .padding({ top: 16 })

            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 18, bottom: 16 })
            .margin({ top: 136 })
            .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
            .borderRadius(22)
            .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
            .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
            }
            .width('100%')
            .reuseId('settings-appearance')

            ListItem() {
              Column() {
              Text('学习')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                .width('100%')
                .margin({ bottom: 12 })
              SettingItem({
                icon: this.studyPlanIcon(), title: '学习计划', description: '每日目标、复习上限和提醒设置', value: '设置', showArrow: true,
                textPrimary: ThemeColor.get(this.darkMode).textPrimary, textSecondary: ThemeColor.get(this.darkMode).textSecondary,
                primary: ThemeColor.get(this.darkMode).primary, darkMode: this.darkMode,
                onItemClick: () => { router.pushUrl({ url: 'pages/StudyPlanPage' }); }
              })
              Divider().color(ThemeColor.get(this.darkMode).border)
              SettingItem({
                icon: this.forgettingIcon(), title: '遗忘系数', description: '调整艾宾浩斯遗忘曲线复习频率',
                value: this.forgettingCoefficientLabel(this.forgettingCoefficient) + ' (' + this.forgettingCoefficient.toFixed(1) + ')', showArrow: true,
                textPrimary: ThemeColor.get(this.darkMode).textPrimary, textSecondary: ThemeColor.get(this.darkMode).textSecondary,
                primary: ThemeColor.get(this.darkMode).primary, darkMode: this.darkMode,
                onItemClick: () => { router.pushUrl({ url: 'pages/ForgettingCoefficientPage' }); }
              })
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 18, bottom: 4 })
            .margin({ top: 20 })
            .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
            .borderRadius(22)
            .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
            .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
            }
            .width('100%')
            .reuseId('settings-study')

            ListItem() {
              Column() {
              Text('数据')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                .width('100%')
                .margin({ bottom: 12 })
              SettingItem({
                icon: this.wordBookIcon(), title: '词书管理', description: '查看、选择、删除和导入词书', value: '打开', showArrow: true,
                textPrimary: ThemeColor.get(this.darkMode).textPrimary, textSecondary: ThemeColor.get(this.darkMode).textSecondary,
                primary: ThemeColor.get(this.darkMode).primary, darkMode: this.darkMode,
                onItemClick: () => { router.pushUrl({ url: 'pages/WordBookManagePage' }); }
              })
              Divider().color(ThemeColor.get(this.darkMode).border)
              SettingItem({
                icon: this.webDavIcon(), title: 'WebDAV 数据管理', description: '上传、拉取和自动同步学习数据', value: '同步', showArrow: true,
                textPrimary: ThemeColor.get(this.darkMode).textPrimary, textSecondary: ThemeColor.get(this.darkMode).textSecondary,
                primary: ThemeColor.get(this.darkMode).primary, darkMode: this.darkMode,
                onItemClick: () => { router.pushUrl({ url: 'pages/WebDavSyncPage' }); }
              })
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 18, bottom: 4 })
            .margin({ top: 20 })
            .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
            .borderRadius(22)
            .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
            .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
            }
            .width('100%')
            .reuseId('settings-data')

            ListItem() {
              Column() {
              Text('其他')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                .width('100%')
                .margin({ bottom: 12 })
              SettingItem({
                icon: this.moreSettingsIcon(), title: '更多设置', description: '学习偏好、AI 接口与数据维护', value: '打开', showArrow: true,
                textPrimary: ThemeColor.get(this.darkMode).textPrimary, textSecondary: ThemeColor.get(this.darkMode).textSecondary,
                primary: ThemeColor.get(this.darkMode).primary, darkMode: this.darkMode,
                onItemClick: () => { router.pushUrl({ url: 'pages/MoreSettingsPage' }); }
              })
              Divider().color(ThemeColor.get(this.darkMode).border)
              SettingItem({
                icon: $r('app.media.app_icon'), title: '关于', description: '应用介绍与版本信息', value: '查看', showArrow: true,
                textPrimary: ThemeColor.get(this.darkMode).textPrimary, textSecondary: ThemeColor.get(this.darkMode).textSecondary,
                primary: ThemeColor.get(this.darkMode).primary, darkMode: this.darkMode,
                onItemClick: () => { router.pushUrl({ url: 'pages/AboutPage' }); }
              })
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 18, bottom: 4 })
            .margin({ top: 20 })
            .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
            .borderRadius(22)
            .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
            .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
            }
            .width('100%')
            .reuseId('settings-about')

            ListItem() {
              Text('v' + Constants.APP_VERSION)
                .fontSize(12)
                .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                .width('100%')
                .textAlign(TextAlign.Center)
                .margin({ top: 30, bottom: 8 })
                .opacity(0.6)
            }
            .width('100%')
            .reuseId('settings-version')

            ListItem() {
              Column() {
                Blank().height(120)
              }
              .width('100%')
            }
            .width('100%')
            .reuseId('settings-bottom-spacer')
          }
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 0 })
        .height('100%')
        .cachedCount(2)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .enableScrollInteraction(true)
        .friction(0.75)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .titleBar(createHdsTabTitleBarOptions('设置', '管理你的偏好和工具', this.darkMode, this.materialEffectMode))
      .titleMode(HdsNavigationTitleMode.FULL)
      .hideBackButton(true)
      .bindToScrollable([this.pageScroller])
      .backgroundColor(ThemeColor.get(this.darkMode).background)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeColor.get(this.darkMode).background)
  }
}
