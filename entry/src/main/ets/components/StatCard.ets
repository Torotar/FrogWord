@Component
export struct StatCard {
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop subtitle: string = '';
  @Prop accentColor: string = '#2563EB';
  @Prop cardWidth: string = '31%';
  @Prop cardBackground: string = '#FFFFFF';
  @Prop textPrimary: string = '#334155';
  @Prop textSecondary: string = '#94A3B8';
  onCardClick?: () => void;

  build() {
    Column() {
      Text(this.value)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.accentColor)

      Text(this.title)
        .fontSize(13)
        .fontColor(this.textPrimary)
        .margin({ top: 6 })

      Text(this.subtitle)
        .fontSize(11)
        .fontColor(this.textSecondary)
        .margin({ top: 4 })
    }
    .width(this.cardWidth)
    .height(112)
    .padding(12)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.cardBackground)
    .borderRadius(16)
    .border({ width: 1, color: 'rgba(148, 163, 184, 0.22)' })
    .shadow({
      radius: 10,
      color: 'rgba(15, 23, 42, 0.05)',
      offsetY: 4
    })
    .onClick(() => {
      if (this.onCardClick) {
        this.onCardClick();
      }
    })
  }
}
