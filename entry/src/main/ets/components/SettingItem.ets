@Component
export struct SettingItem {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop value: string = '';
  @Prop showArrow: boolean = false;
  @Prop textPrimary: string = '#0F172A';
  @Prop textSecondary: string = '#94A3B8';
  @Prop primary: string = '#2563EB';
  @Prop darkMode: boolean = false;
  @Prop icon: Resource | null = null;
  onItemClick?: () => void;

  build() {
    Row() {
      if (this.icon !== null) {
        Image(this.icon)
          .width(22)
          .height(22)
          .objectFit(ImageFit.Contain)
          .margin({ right: 12 })
      }

      Column() {
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textPrimary)

        Text(this.description)
          .fontSize(13)
          .fontColor(this.textSecondary)
          .margin({ top: 4 })
          .width('100%')
          .lineHeight(18)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ right: (this.value.length > 0 || this.showArrow) ? 18 : 0 })

      if (this.value.length > 0) {
        Text(this.value)
          .fontSize(14)
          .fontColor(this.primary)
          .margin({ right: this.showArrow ? 8 : 0 })
      }

      if (this.showArrow) {
        Image(this.darkMode ? $r('app.media.back_dark') : $r('app.media.back_light'))
          .width(11)
          .height(11)
          .objectFit(ImageFit.Contain)
          .scale({ x: -1, y: 1 })
      }
    }
    .width('100%')
    .padding({ top: 18, bottom: 18 })
    .onClick(() => {
      if (this.onItemClick) {
        this.onItemClick();
      }
    })
  }
}
