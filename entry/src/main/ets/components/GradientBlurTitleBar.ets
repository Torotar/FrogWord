import router from '@ohos.router';
import { ThemeColor } from '../utils/ThemeColor';

@Component
export struct GradientBlurTitleBar {
  @Prop title: string = '';
  @Prop darkMode: boolean = false;
  private readonly STATUS_BAR_HEIGHT: number = 56;
  private readonly TITLE_BAR_HEIGHT: number = 40;
  private readonly FADE_HEIGHT: number = 72;
  private readonly SCROLL_BAR_SAFE_WIDTH: number = 8;

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Stack({ alignContent: Alignment.Top }) {
        Column()
          .width('100%')
          .height(this.STATUS_BAR_HEIGHT + this.TITLE_BAR_HEIGHT + this.FADE_HEIGHT)
          .linearGradientBlur(72, {
            fractionStops: [[0, 0.02], [0.24, 0.16], [0.58, 0.62], [1, 1]],
            direction: GradientDirection.Top
          })

        Column()
          .width('100%')
          .height(this.STATUS_BAR_HEIGHT + this.TITLE_BAR_HEIGHT + this.FADE_HEIGHT)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: this.darkMode ?
              [['rgba(18, 20, 26, 0.36)', 0], ['rgba(18, 20, 26, 0.16)', 0.48], ['rgba(18, 20, 26, 0)', 1]] :
              [['rgba(245, 249, 255, 0.68)', 0], ['rgba(245, 249, 255, 0.28)', 0.5], ['rgba(245, 249, 255, 0)', 1]]
          })
      }
      .width('calc(100% - ' + this.SCROLL_BAR_SAFE_WIDTH + 'vp)')
      .height(this.STATUS_BAR_HEIGHT + this.TITLE_BAR_HEIGHT + this.FADE_HEIGHT)
      .clip(true)
      .position({ x: 0, y: 0 })

      Row() {
        Row() {
          Image(this.darkMode ? $r('app.media.back_dark') : $r('app.media.back_light'))
            .width(19)
            .height(19)
            .objectFit(ImageFit.Contain)
            .offset({ x: -1 })
        }
        .width(32)
        .height(32)
        .backgroundColor(ThemeColor.get(this.darkMode).primaryLight)
        .borderRadius(16)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          router.back();
        })

        Text(this.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Blank()
          .width(32)
      }
      .width('100%')
      .height(this.TITLE_BAR_HEIGHT)
      .padding({ left: 20, right: 20 })
      .alignItems(VerticalAlign.Center)
      .position({ x: 0, y: this.STATUS_BAR_HEIGHT })
    }
    .width('100%')
    .height(this.STATUS_BAR_HEIGHT + this.TITLE_BAR_HEIGHT + this.FADE_HEIGHT)
  }
}

@Component
export struct GradientTopBlur {
  @Prop darkMode: boolean = false;
  @Prop headerHeight: number = 56;
  @Prop fadeHeight: number = 72;
  private readonly STATUS_BAR_HEIGHT: number = 56;
  private readonly SCROLL_BAR_SAFE_WIDTH: number = 8;

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column()
        .width('100%')
        .height(this.STATUS_BAR_HEIGHT + this.headerHeight + this.fadeHeight)
        .linearGradientBlur(72, {
          fractionStops: [[0, 0.02], [0.24, 0.16], [0.58, 0.62], [1, 1]],
          direction: GradientDirection.Top
        })

      Column()
        .width('100%')
        .height(this.STATUS_BAR_HEIGHT + this.headerHeight + this.fadeHeight)
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: this.darkMode ?
            [['rgba(18, 20, 26, 0.24)', 0], ['rgba(18, 20, 26, 0.10)', 0.48], ['rgba(18, 20, 26, 0)', 1]] :
            [['rgba(245, 249, 255, 0.42)', 0], ['rgba(245, 249, 255, 0.16)', 0.5], ['rgba(245, 249, 255, 0)', 1]]
        })
    }
    .width('calc(100% - ' + this.SCROLL_BAR_SAFE_WIDTH + 'vp)')
    .height(this.STATUS_BAR_HEIGHT + this.headerHeight + this.fadeHeight)
    .clip(true)
    .position({ x: 0, y: 0 })
    .hitTestBehavior(HitTestMode.Transparent)
  }
}

@Component
export struct GradientTabTitleBar {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop darkMode: boolean = false;
  private readonly STATUS_BAR_HEIGHT: number = 56;
  private readonly HEADER_HEIGHT: number = 56;
  private readonly FADE_HEIGHT: number = 72;

  build() {
    Stack({ alignContent: Alignment.Top }) {
      GradientTopBlur({
        darkMode: this.darkMode,
        headerHeight: this.HEADER_HEIGHT,
        fadeHeight: this.FADE_HEIGHT
      })

      Column() {
        Text(this.title)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')
          .width('100%')

        Text(this.subtitle)
          .fontSize(14)
          .fontColor(this.darkMode ? '#CBD5E1' : '#8C8CA8')
          .margin({ top: 4 })
          .width('100%')
      }
      .width('100%')
      .height(this.HEADER_HEIGHT)
      .justifyContent(FlexAlign.End)
      .padding({ left: 24, right: 24, bottom: 10 })
      .position({ x: 0, y: this.STATUS_BAR_HEIGHT })
    }
    .width('100%')
    .height(this.STATUS_BAR_HEIGHT + this.HEADER_HEIGHT + this.FADE_HEIGHT)
    .position({ x: 0, y: 0 })
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
