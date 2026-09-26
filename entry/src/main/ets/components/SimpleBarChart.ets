import { StudyDaily } from '../model/StudyStats';

@Component
export struct SimpleBarChart {
  @Prop stats: StudyDaily[] = [];
  @Prop title: string = '';
  @Prop cardBackground: string = '#FFFFFF';
  @Prop textPrimary: string = '#0F172A';
  @Prop textSecondary: string = '#64748B';

  private maxCount(): number {
    let maxValue: number = 1;
    for (let index: number = 0; index < this.stats.length; index++) {
      const value: number = Math.max(this.stats[index].learnCount, this.stats[index].reviewCount);
      if (value > maxValue) {
        maxValue = value;
      }
    }
    return maxValue;
  }

  private barHeight(value: number): number {
    return Math.max(6, Math.round(value * 88 / this.maxCount()));
  }

  build() {
    Column() {
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.textPrimary)
        .width('100%')

      Row() {
        Text('学习')
          .fontSize(12)
          .fontColor('#2563EB')
        Text('复习')
          .fontSize(12)
          .fontColor('#16A34A')
          .margin({ left: 14 })
      }
      .width('100%')
      .margin({ top: 8 })

      Row() {
        ForEach(this.stats, (item: StudyDaily) => {
          Column() {
            Row() {
              Column()
                .width(10)
                .height(this.barHeight(item.learnCount))
                .backgroundColor('#2563EB')
                .borderRadius(5)
                .margin({ right: 4 })

              Column()
                .width(10)
                .height(this.barHeight(item.reviewCount))
                .backgroundColor('#16A34A')
                .borderRadius(5)
            }
            .height(96)
            .alignItems(VerticalAlign.Bottom)

            Text(item.date.substring(5))
              .fontSize(10)
              .fontColor(this.textSecondary)
              .margin({ top: 6 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }, (item: StudyDaily) => item.date)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.cardBackground)
    .borderRadius(18)
  }
}
