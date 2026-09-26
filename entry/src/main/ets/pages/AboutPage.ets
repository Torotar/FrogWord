import router from '@ohos.router';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { SUB_PAGE_CONTENT_OVERLAP } from '../components/HdsSubPageLayout';
import { createHdsSubPageTitleBarOptions } from '../components/HdsSubPageTitleBarOptions';
import { Constants } from '../utils/Constants';
import { ThemeColor } from '../utils/ThemeColor';

@Entry
@Component
struct AboutPage {
  @StorageLink('resolvedDarkMode') darkMode: boolean = false;
  @StorageLink('materialEffectMode') materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;
  private pageScroller: Scroller = new Scroller();

  @Builder
  private appIdentity() {
    Column() {
      Image($r('app.media.app_icon'))
        .width(88)
        .height(88)
        .objectFit(ImageFit.Cover)
        .borderRadius(20)

      Text('呱呱单词')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .margin({ top: 18 })

      Text('版本 ' + Constants.APP_VERSION)
        .fontSize(14)
        .fontColor(ThemeColor.get(this.darkMode).textSecondary)
        .margin({ top: 6 })

      Text('专注于词书管理、单词学习与复习规划')
        .fontSize(14)
        .fontColor(ThemeColor.get(this.darkMode).textSecondary)
        .lineHeight(22)
        .textAlign(TextAlign.Center)
        .margin({ top: 16 })
    }
    .width('100%')
    .padding({ top: 34, bottom: 28 })
  }

  @Builder
  private infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .fontWeight(FontWeight.Medium)

      Blank()

      Text(value)
        .fontSize(14)
        .fontColor(ThemeColor.get(this.darkMode).textSecondary)
    }
    .width('100%')
    .height(56)
  }

  @Builder
  private appInfoCard() {
    Column() {
      this.infoRow('应用名称', '呱呱单词')

      Divider()
        .color(ThemeColor.get(this.darkMode).border)

      this.infoRow('当前版本', Constants.APP_VERSION)
    }
    .width('100%')
    .padding({ left: 20, right: 20 })
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
    .borderRadius(20)
    .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
  }

  build() {
    HdsNavDestination() {
      List({ scroller: this.pageScroller }) {
        ListItem() {
          this.appIdentity()
        }
        .width('100%')
        .reuseId('about-identity')

        ListItem() {
          this.appInfoCard()
        }
        .width('100%')
        .reuseId('about-info')

        ListItem() {
          Column().width('100%').height(32)
        }
        .width('100%')
        .reuseId('about-bottom-spacer')
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
    .titleBar(createHdsSubPageTitleBarOptions('关于', this.darkMode, this.materialEffectMode))
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
