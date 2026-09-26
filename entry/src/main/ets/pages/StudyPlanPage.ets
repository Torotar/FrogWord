import { common } from '@kit.AbilityKit';
import router from '@ohos.router';
import { HdsNavDestination, HdsNavDestinationTitleMode } from '@kit.UIDesignKit';
import { SUB_PAGE_CONTENT_OVERLAP } from '../components/HdsSubPageLayout';
import { createHdsSubPageTitleBarOptions } from '../components/HdsSubPageTitleBarOptions';
import { StudyPlan } from '../model/StudyPlan';
import { WordBook } from '../model/WordBook';
import { DatabaseService } from '../services/DatabaseService';
import { PreferencesService } from '../services/PreferencesService';
import { StudyPlanService } from '../services/StudyPlanService';
import { WordBookService } from '../services/WordBookService';
import { Constants } from '../utils/Constants';
import { ThemeColor } from '../utils/ThemeColor';

@CustomDialog
@Component
struct PlanWheelPickerDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: this });
  title: string = '';
  options: string[] = [];
  darkMode: boolean = false;
  @State selectedIndex: number = 0;
  onConfirm: (value: string) => void = () => {};

  build() {
    Column() {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .margin({ top: 8 })

      TextPicker({
        range: this.options,
        selected: this.selectedIndex
      })
        .width('100%')
        .height(180)
        .margin({ top: 12 })
        .selectedTextStyle({
          color: ThemeColor.get(this.darkMode).textPrimary,
          font: { size: 20, weight: FontWeight.Medium }
        })
        .textStyle({
          color: ThemeColor.get(this.darkMode).textSecondary,
          font: { size: 16, weight: FontWeight.Normal }
        })
        .disappearTextStyle({
          color: this.darkMode ? '#64748B' : '#94A3B8',
          font: { size: 14, weight: FontWeight.Normal }
        })
        .onChange((value: string | string[], index: number | number[]) => {
          if (typeof index === 'number') {
            this.selectedIndex = index;
          }
        })

      Row() {
        Button('取消')
          .width('44%')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
          .onClick(() => {
            this.controller.close();
          })

        Button('确定')
          .width('44%')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .onClick(() => {
            if (this.options.length > 0) {
              this.onConfirm(this.options[this.selectedIndex]);
            }
            this.controller.close();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 12 })
    }
    .padding({ left: 24, right: 24, top: 16, bottom: 20 })
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .borderRadius(20)
  }
}

@CustomDialog
@Component
struct PlanDualWheelPickerDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: this });
  title: string = '';
  primaryLabel: string = '';
  groupLabel: string = '';
  primaryOptions: string[] = [];
  groupOptions: string[] = [];
  darkMode: boolean = false;
  @State selectedPrimaryIndex: number = 0;
  @State selectedGroupIndex: number = 0;
  onConfirm: (primaryValue: string, groupValue: string) => void =
    (primaryValue: string, groupValue: string) => {};

  build() {
    Column() {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .margin({ top: 8 })

      Row() {
        Column() {
          Text(this.primaryLabel)
            .fontSize(13)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
            .margin({ bottom: 6 })

          TextPicker({
            range: this.primaryOptions,
            selected: this.selectedPrimaryIndex
          })
            .width('100%')
            .height(150)
            .selectedTextStyle({
              color: ThemeColor.get(this.darkMode).textPrimary,
              font: { size: 20, weight: FontWeight.Medium }
            })
            .textStyle({
              color: ThemeColor.get(this.darkMode).textSecondary,
              font: { size: 16, weight: FontWeight.Normal }
            })
            .disappearTextStyle({
              color: this.darkMode ? '#64748B' : '#94A3B8',
              font: { size: 14, weight: FontWeight.Normal }
            })
            .onChange((value: string | string[], index: number | number[]) => {
              if (typeof index === 'number') {
                this.selectedPrimaryIndex = index;
              }
            })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)

        Column() {
          Text(this.groupLabel)
            .fontSize(13)
            .fontColor(ThemeColor.get(this.darkMode).textSecondary)
            .margin({ bottom: 6 })

          TextPicker({
            range: this.groupOptions,
            selected: this.selectedGroupIndex
          })
            .width('100%')
            .height(150)
            .selectedTextStyle({
              color: ThemeColor.get(this.darkMode).textPrimary,
              font: { size: 20, weight: FontWeight.Medium }
            })
            .textStyle({
              color: ThemeColor.get(this.darkMode).textSecondary,
              font: { size: 16, weight: FontWeight.Normal }
            })
            .disappearTextStyle({
              color: this.darkMode ? '#64748B' : '#94A3B8',
              font: { size: 14, weight: FontWeight.Normal }
            })
            .onChange((value: string | string[], index: number | number[]) => {
              if (typeof index === 'number') {
                this.selectedGroupIndex = index;
              }
            })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .margin({ left: 16 })
      }
      .width('100%')
      .margin({ top: 16 })

      Row() {
        Button('取消')
          .width('44%')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
          .onClick(() => {
            this.controller.close();
          })

        Button('确定')
          .width('44%')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .onClick(() => {
            if (this.primaryOptions.length > 0 && this.groupOptions.length > 0) {
              this.onConfirm(this.primaryOptions[this.selectedPrimaryIndex], this.groupOptions[this.selectedGroupIndex]);
            }
            this.controller.close();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 12 })
    }
    .padding({ left: 24, right: 24, top: 16, bottom: 20 })
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .borderRadius(20)
  }
}

@CustomDialog
@Component
struct TargetDatePickerDialog {
  controller: CustomDialogController = new CustomDialogController({ builder: this });
  darkMode: boolean = false;
  @State selectedDate: Date = new Date();
  onConfirm: (value: string) => void = () => {};

  private padDatePart(value: number): string {
    return value < 10 ? '0' + value.toString() : value.toString();
  }

  private dateValue(date: Date): string {
    return date.getFullYear().toString() + '-' + this.padDatePart(date.getMonth() + 1) + '-' +
      this.padDatePart(date.getDate());
  }

  build() {
    Column() {
      Text('目标完成日期')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .margin({ top: 8 })

      DatePicker({
        start: new Date(),
        end: new Date(new Date().getFullYear() + 5, 11, 31),
        selected: this.selectedDate
      })
        .width('100%')
        .height(180)
        .margin({ top: 12 })
        .selectedTextStyle({
          color: ThemeColor.get(this.darkMode).textPrimary,
          font: { size: 20, weight: FontWeight.Medium }
        })
        .textStyle({
          color: ThemeColor.get(this.darkMode).textSecondary,
          font: { size: 16, weight: FontWeight.Normal }
        })
        .disappearTextStyle({
          color: this.darkMode ? '#64748B' : '#94A3B8',
          font: { size: 14, weight: FontWeight.Normal }
        })
        .onChange((value: DatePickerResult) => {
          const pickedYear: number = value.year ?? this.selectedDate.getFullYear();
          const pickedMonth: number = value.month ?? (this.selectedDate.getMonth() + 1);
          const pickedDay: number = value.day ?? this.selectedDate.getDate();
          const month: number = pickedMonth > 11 ? pickedMonth - 1 : pickedMonth;
          this.selectedDate = new Date(pickedYear, month, pickedDay);
        })

      Row() {
        Button('取消')
          .width('44%')
          .buttonStyle(ButtonStyleMode.NORMAL)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
          .onClick(() => {
            this.controller.close();
          })

        Button('确定')
          .width('44%')
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .controlSize(ControlSize.NORMAL)
          .role(ButtonRole.NORMAL)
          .onClick(() => {
            this.onConfirm(this.dateValue(this.selectedDate));
            this.controller.close();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 12 })
    }
    .padding({ left: 24, right: 24, top: 16, bottom: 20 })
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .borderRadius(20)
  }
}

@Entry
@Component
struct StudyPlanPage {
  @State private isLoading: boolean = true;
  @StorageLink('resolvedDarkMode') darkMode: boolean = false;
  @State private dailyGoalText: string = '20';
  @State private reviewGoalText: string = '30';
  @State private newWordGroupSizeText: string = '10';
  @State private reviewGroupSizeText: string = '10';
  @State private relearnGoalText: string = '30';
  @State private relearnGroupSizeText: string = '10';
  @State private weeklyDaysText: string = '5';
  @State private targetDate: string = '';
  @State private weekendEnabled: boolean = true;
  @State private reminderEnabled: boolean = false;
  @State private message: string = '';
  @State private wordBookList: WordBook[] = [];
  @State private selectedBookId: number = 0;
  @State private selectedBookName: string = '';
  @State private selectedBookTotal: number = 0;
  @State private refreshTick: number = 0;
  @State private manualGoalMode: boolean = false;
  @StorageLink('materialEffectMode') materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;
  private pageScroller: Scroller = new Scroller();
  private pickerController: CustomDialogController | null = null;

  aboutToAppear(): void {
    this.loadPlan();
  }

  private async loadPlan(): Promise<void> {
    this.isLoading = true;
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      await PreferencesService.init(context);

      const plan: StudyPlan = await StudyPlanService.getPlan();
      this.dailyGoalText = plan.dailyGoal.toString();
      this.reviewGoalText = plan.reviewGoal.toString();
      this.newWordGroupSizeText = plan.newWordGroupSize.toString();
      this.reviewGroupSizeText = plan.reviewGroupSize.toString();
      this.relearnGoalText = plan.relearnGoal.toString();
      this.relearnGroupSizeText = plan.relearnGroupSize.toString();
      this.weeklyDaysText = plan.weeklyDays.toString();
      this.targetDate = plan.targetDate;
      this.weekendEnabled = plan.weekendEnabled;
      this.reminderEnabled = plan.reminderEnabled;

      this.selectedBookId = await PreferencesService.getSelectedBookId();
      this.wordBookList = await WordBookService.getAllWordBooks();
      this.updateSelectedBookInfo();
    } catch (error) {
      console.error('StudyPlanPage loadPlan failed: ' + JSON.stringify(error));
      this.message = '学习计划加载失败';
    } finally {
      this.isLoading = false;
    }
  }

  private updateSelectedBookInfo(): void {
    this.selectedBookName = '';
    this.selectedBookTotal = 0;
    for (let index: number = 0; index < this.wordBookList.length; index++) {
      const book: WordBook = this.wordBookList[index];
      if (book.id === this.selectedBookId) {
        this.selectedBookName = book.name;
        this.selectedBookTotal = book.totalCount;
        return;
      }
    }
  }

  private safeNumber(text: string, fallback: number, minValue: number, maxValue: number): number {
    const value: number = Number(text);
    if (Number.isNaN(value)) {
      return fallback;
    }
    return Math.min(maxValue, Math.max(minValue, Math.round(value)));
  }

  private padDatePart(value: number): string {
    return value < 10 ? '0' + value.toString() : value.toString();
  }

  private dateValue(date: Date): string {
    return date.getFullYear().toString() + '-' + this.padDatePart(date.getMonth() + 1) + '-' +
      this.padDatePart(date.getDate());
  }

  private buildNumberOptions(minValue: number, maxValue: number): string[] {
    const options: string[] = [];
    for (let value: number = minValue; value <= maxValue; value++) {
      options.push(value.toString());
    }
    return options;
  }

  private selectIndex(options: string[], value: string): number {
    const index: number = options.indexOf(value);
    return index >= 0 ? index : 0;
  }

  private selectValue(options: string[], value: string): string {
    if (value.length > 0 && options.indexOf(value) >= 0) {
      return value;
    }
    return options.length > 0 ? options[0] : '';
  }

  private parseDateValue(value: string): Date {
    const parts: string[] = value.split('-');
    if (parts.length === 3) {
      const year: number = Number(parts[0]);
      const month: number = Number(parts[1]);
      const day: number = Number(parts[2]);
      if (!Number.isNaN(year) && !Number.isNaN(month) && !Number.isNaN(day)) {
        return new Date(year, month - 1, day);
      }
    }
    return new Date();
  }

  private getTodayStart(): Date {
    const today: Date = new Date();
    return new Date(today.getFullYear(), today.getMonth(), today.getDate());
  }

  private getCalendarDaysUntilTarget(): number {
    const parts: string[] = this.targetDate.split('-');
    if (parts.length !== 3) {
      return 0;
    }
    const year: number = Number(parts[0]);
    const month: number = Number(parts[1]);
    const day: number = Number(parts[2]);
    if (Number.isNaN(year) || Number.isNaN(month) || Number.isNaN(day)) {
      return 0;
    }

    const oneDayMs: number = 24 * 60 * 60 * 1000;
    const targetStart: Date = new Date(year, month - 1, day);
    return Math.max(1, Math.ceil((targetStart.getTime() - this.getTodayStart().getTime()) / oneDayMs));
  }

  private getCompletionCalendarDays(): number {
    if (this.selectedBookTotal <= 0) {
      return 0;
    }
    const dailyGoal: number = this.safeNumber(this.dailyGoalText, 20, 1, 999);
    const weeklyDays: number = this.safeNumber(this.weeklyDaysText, 5, 1, 7);
    const studyDays: number = Math.max(1, Math.ceil(this.selectedBookTotal / dailyGoal));
    return Math.max(1, Math.ceil(studyDays * 7 / weeklyDays));
  }

  private adjustGoalsByTargetDate(): void {
    const weeklyDays: number = this.weekendEnabled ? 7 : 5;
    this.adjustGoalsByTargetDateWithWeeklyDays(weeklyDays);
  }

  private adjustGoalsByTargetDateWithWeeklyDays(weeklyDays: number): void {
    const calendarDays: number = this.getCalendarDaysUntilTarget();
    if (this.selectedBookTotal <= 0 || calendarDays <= 0) {
      return;
    }

    const safeWeeklyDays: number = Math.max(1, Math.min(7, weeklyDays));
    const effectiveStudyDays: number = Math.max(1, Math.ceil(calendarDays * safeWeeklyDays / 7));
    const dailyGoal: number = Math.min(999, Math.max(1, Math.ceil(this.selectedBookTotal / effectiveStudyDays)));
    const reviewGoal: number = Math.min(999, Math.max(30, Math.ceil(dailyGoal * 1.5)));

    this.weeklyDaysText = safeWeeklyDays.toString();
    this.dailyGoalText = dailyGoal.toString();
    this.reviewGoalText = reviewGoal.toString();
  }

  private applyWeekendStudyChange(isOn: boolean): void {
    const currentDays: number = this.safeNumber(this.weeklyDaysText, 5, 1, 7);
    const nextDays: number = isOn ? Math.min(7, currentDays + 2) : Math.max(1, currentDays - 2);
    this.weeklyDaysText = nextDays.toString();
    if (!this.manualGoalMode) {
      this.adjustGoalsByTargetDateWithWeeklyDays(nextDays);
    }
    this.markPlanChanged();
  }

  private openWheelPicker(title: string, options: string[], valueText: string, onChanged: (value: string) => void): void {
    this.pickerController = new CustomDialogController({
      builder: PlanWheelPickerDialog({
        title: title,
        options: options,
        darkMode: this.darkMode,
        selectedIndex: this.selectIndex(options, valueText),
        onConfirm: (value: string) => {
          onChanged(value);
        }
      }),
      customStyle: false,
      alignment: DialogAlignment.Center
    });
    this.pickerController.open();
  }

  private openDualWheelPicker(
    title: string,
    primaryLabel: string,
    primaryOptions: string[],
    primaryValueText: string,
    groupLabel: string,
    groupOptions: string[],
    groupValueText: string,
    onChanged: (primaryValue: string, groupValue: string) => void
  ): void {
    this.pickerController = new CustomDialogController({
      builder: PlanDualWheelPickerDialog({
        title: title,
        primaryLabel: primaryLabel,
        primaryOptions: primaryOptions,
        selectedPrimaryIndex: this.selectIndex(primaryOptions, primaryValueText),
        groupLabel: groupLabel,
        groupOptions: groupOptions,
        selectedGroupIndex: this.selectIndex(groupOptions, groupValueText),
        darkMode: this.darkMode,
        onConfirm: (primaryValue: string, groupValue: string) => {
          onChanged(primaryValue, groupValue);
        }
      }),
      customStyle: false,
      alignment: DialogAlignment.Center
    });
    this.pickerController.open();
  }

  private openTargetDatePicker(valueText: string, onChanged: (value: string) => void): void {
    this.pickerController = new CustomDialogController({
      builder: TargetDatePickerDialog({
        darkMode: this.darkMode,
        selectedDate: this.parseDateValue(valueText),
        onConfirm: (value: string) => {
          onChanged(value);
        }
      }),
      customStyle: false,
      alignment: DialogAlignment.Center
    });
    this.pickerController.open();
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({
      message: message,
      duration: 2000
    });
  }

  private getEffectiveStudyDays(): number {
    const calendarDays: number = this.getCalendarDaysUntilTarget();
    if (calendarDays <= 0) {
      return 0;
    }
    const weeklyDays: number = this.safeNumber(this.weeklyDaysText, 5, 1, 7);
    return Math.max(1, Math.ceil(calendarDays * weeklyDays / 7));
  }

  private getSuggestedDailyGoal(): number {
    const studyDays: number = this.getEffectiveStudyDays();
    if (this.selectedBookTotal <= 0 || studyDays <= 0) {
      return 0;
    }
    return Math.max(1, Math.ceil(this.selectedBookTotal / studyDays));
  }

  private getSuggestionText(): string {
    if (this.selectedBookTotal <= 0) {
      return '';
    }

    if (this.manualGoalMode) {
      const completionDays: number = this.getCompletionCalendarDays();
      if (completionDays <= 0) {
        return '';
      }
      return '按照当前学习目标，预计需要 ' + completionDays.toString() + ' 天学完这本词书';
    }

    const studyDays: number = this.getEffectiveStudyDays();
    if (studyDays <= 0) {
      return '';
    }
    return '按照目标日期，已自动调整为每日新学 ' + this.dailyGoalText + ' 个新词（共 ' +
      this.selectedBookTotal.toString() + ' 词 / ' + studyDays.toString() + ' 个学习日）';
  }

  private async savePlan(): Promise<void> {
    const plan: StudyPlan = {
      dailyGoal: this.safeNumber(this.dailyGoalText, 20, 1, 999),
      reviewGoal: this.safeNumber(this.reviewGoalText, 30, 1, 999),
      newWordGroupSize: this.safeNumber(this.newWordGroupSizeText, 10, 1, 999),
      reviewGroupSize: this.safeNumber(this.reviewGroupSizeText, 10, 1, 999),
      relearnGoal: this.safeNumber(this.relearnGoalText, 30, 1, 999),
      relearnGroupSize: this.safeNumber(this.relearnGroupSizeText, 10, 1, 999),
      weeklyDays: this.safeNumber(this.weeklyDaysText, 5, 1, 7),
      weekendEnabled: this.weekendEnabled,
      targetDate: this.targetDate,
      reminderEnabled: this.reminderEnabled
    };
    await StudyPlanService.savePlan(plan);
    await PreferencesService.setSelectedBookId(this.selectedBookId);
    this.message = '学习计划已保存';
  }

  private autoSavePlan(): void {
    this.savePlan().catch((error: Error) => {
      console.error('StudyPlanPage autoSavePlan failed: ' + JSON.stringify(error));
      this.message = '学习计划保存失败';
    });
  }

  @Builder
  private buildWheelPickerRow(label: string, title: string, valueText: string, options: string[], onChanged: (value: string) => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .layoutWeight(1)

      Row() {
        Text(this.selectValue(options, valueText))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)

        Text('›')
          .fontSize(22)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .margin({ left: 8 })
      }
      .height(40)
      .padding({ left: 12, right: 10 })
      .backgroundColor(this.darkMode ? '#172554' : '#F1F6FF')
      .border({ width: 1, color: ThemeColor.get(this.darkMode).primaryLight })
      .borderRadius(10)
    }
    .width('100%')
    .margin({ top: 14 })
    .onClick(() => {
      this.openWheelPicker(title, options, valueText, onChanged);
    })
  }

  @Builder
  private buildDatePickerRow(label: string, valueText: string, onChanged: (value: string) => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .layoutWeight(1)

      Row() {
        Text(valueText.length > 0 ? valueText : this.dateValue(new Date()))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)

        Text('›')
          .fontSize(22)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .margin({ left: 8 })
      }
      .height(40)
      .padding({ left: 12, right: 10 })
      .backgroundColor(this.darkMode ? '#172554' : '#F1F6FF')
      .border({ width: 1, color: ThemeColor.get(this.darkMode).primaryLight })
      .borderRadius(10)
    }
    .width('100%')
    .margin({ top: 14 })
    .onClick(() => {
      this.openTargetDatePicker(valueText, onChanged);
    })
  }

  @Builder
  private buildPlanSelector(label: string, title: string, valueText: string, options: string[], onChanged: (value: string) => void) {
    this.buildWheelPickerRow(label, title, valueText, options, onChanged)
  }

  @Builder
  private buildPlanSelectorByPlaceholder(label: string, valueText: string, placeholder: string, onChanged: (value: string) => void) {
    if (placeholder === '20') {
      this.buildPlanSelector(label, '每日新学单词数', valueText, this.buildNumberOptions(1, 200), onChanged)
    } else if (placeholder === '30') {
      this.buildPlanSelector(label, '每日复习上限', valueText, this.buildNumberOptions(1, 300), onChanged)
    } else if (placeholder === '5') {
      this.buildPlanSelector(label, '每周学习天数', valueText, this.buildNumberOptions(1, 7), onChanged)
    } else {
      this.buildDatePickerRow(label, valueText, onChanged)
    }
  }

  private markPlanChanged(): void {
    this.message = '';
    this.refreshTick++;
  }

  private markManualGoalChanged(): void {
    this.manualGoalMode = true;
    this.markPlanChanged();
  }

  private markTargetDateChanged(): void {
    this.manualGoalMode = false;
    this.adjustGoalsByTargetDate();
    this.markPlanChanged();
  }

  @Builder
  private buildDailyGoalRow() {
    Row() {
      Text('每日新学')
        .fontSize(15)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .layoutWeight(1)

      Row() {
        Text(this.dailyGoalText + ' 个 / 每组 ' + this.newWordGroupSizeText)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)

        Text('›')
          .fontSize(22)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .margin({ left: 8 })
      }
      .height(40)
      .padding({ left: 12, right: 10 })
      .backgroundColor(this.darkMode ? '#172554' : '#F1F6FF')
      .border({ width: 1, color: ThemeColor.get(this.darkMode).primaryLight })
      .borderRadius(10)
    }
    .width('100%')
    .margin({ top: 14 })
    .onClick(() => {
      this.openDualWheelPicker('每日新学单词', '每日数量', this.buildNumberOptions(1, 200), this.dailyGoalText,
        '每组数量', this.buildNumberOptions(1, 100), this.newWordGroupSizeText, (value: string, groupValue: string) => {
        this.dailyGoalText = value;
        this.newWordGroupSizeText = groupValue;
        this.markManualGoalChanged();
        this.autoSavePlan();
      })
    })
  }

  @Builder
  private buildReviewGoalRow() {
    Row() {
      Text('每日复习')
        .fontSize(15)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .layoutWeight(1)

      Row() {
        Text(this.reviewGoalText + ' 个 / 每组 ' + this.reviewGroupSizeText)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)

        Text('›')
          .fontSize(22)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .margin({ left: 8 })
      }
      .height(40)
      .padding({ left: 12, right: 10 })
      .backgroundColor(this.darkMode ? '#172554' : '#F1F6FF')
      .border({ width: 1, color: ThemeColor.get(this.darkMode).primaryLight })
      .borderRadius(10)
    }
    .width('100%')
    .margin({ top: 14 })
    .onClick(() => {
      this.openDualWheelPicker('每日复习单词', '复习上限', this.buildNumberOptions(1, 300), this.reviewGoalText,
        '每组数量', this.buildNumberOptions(1, 100), this.reviewGroupSizeText, (value: string, groupValue: string) => {
        this.reviewGoalText = value;
        this.reviewGroupSizeText = groupValue;
        this.markManualGoalChanged();
        this.autoSavePlan();
      })
    })
  }

  @Builder
  private buildRelearnGoalRow() {
    Row() {
      Text('重新学习')
        .fontSize(15)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .layoutWeight(1)

      Row() {
        Text(this.relearnGoalText + ' 个 / 每组 ' + this.relearnGroupSizeText)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)

        Text('›')
          .fontSize(22)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .margin({ left: 8 })
      }
      .height(40)
      .padding({ left: 12, right: 10 })
      .backgroundColor(this.darkMode ? '#172554' : '#F1F6FF')
      .border({ width: 1, color: ThemeColor.get(this.darkMode).primaryLight })
      .borderRadius(10)
    }
    .width('100%')
    .margin({ top: 14 })
    .onClick(() => {
      this.openDualWheelPicker('重新学习单词', '重新学习数量', this.buildNumberOptions(1, 300), this.relearnGoalText,
        '每组数量', this.buildNumberOptions(1, 100), this.relearnGroupSizeText, (value: string, groupValue: string) => {
        this.relearnGoalText = value;
        this.relearnGroupSizeText = groupValue;
        this.markManualGoalChanged();
        this.autoSavePlan();
      })
    })
  }

  @Builder
  private buildWeeklyDaysRow() {
    Row() {
      Text('每周学习天数')
        .fontSize(15)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .layoutWeight(1)

      Row() {
        Text(this.weeklyDaysText)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)

        Text('›')
          .fontSize(22)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .margin({ left: 8 })
      }
      .height(40)
      .padding({ left: 12, right: 10 })
      .backgroundColor(this.darkMode ? '#172554' : '#F1F6FF')
      .border({ width: 1, color: ThemeColor.get(this.darkMode).primaryLight })
      .borderRadius(10)
    }
    .width('100%')
    .margin({ top: 14 })
    .onClick(() => {
      this.openWheelPicker('每周学习天数', this.buildNumberOptions(1, 7), this.weeklyDaysText, (value: string) => {
        this.weeklyDaysText = value;
        this.markManualGoalChanged();
        this.autoSavePlan();
      })
    })
  }

  @Builder
  private buildTargetDateRow() {
    Row() {
      Text('目标日期')
        .fontSize(15)
        .fontColor(this.manualGoalMode ? ThemeColor.get(this.darkMode).textSecondary :
          ThemeColor.get(this.darkMode).textPrimary)
        .layoutWeight(1)

      Row() {
        Text(this.targetDate.length > 0 ? this.targetDate : this.dateValue(new Date()))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.manualGoalMode ? ThemeColor.get(this.darkMode).textSecondary :
            ThemeColor.get(this.darkMode).textPrimary)

        Text('›')
          .fontSize(22)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .margin({ left: 8 })
      }
      .height(40)
      .padding({ left: 12, right: 10 })
      .backgroundColor(this.darkMode ? '#172554' : '#F1F6FF')
      .border({ width: 1, color: ThemeColor.get(this.darkMode).primaryLight })
      .borderRadius(10)
      .opacity(this.manualGoalMode ? 0.56 : 1)
    }
    .width('100%')
    .margin({ top: 14 })
    .onClick(() => {
      this.openTargetDatePicker(this.targetDate, (value: string) => {
        this.targetDate = value;
        this.markTargetDateChanged();
        this.autoSavePlan();
      })
    })
  }

  @Builder
  private buildStateValueRow(label: string, valueText: string, onTap: () => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .layoutWeight(1)

      Row() {
        Text(valueText)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)

        Text('›')
          .fontSize(22)
          .fontColor(ThemeColor.get(this.darkMode).textSecondary)
          .margin({ left: 8 })
      }
      .height(40)
      .padding({ left: 12, right: 10 })
      .backgroundColor(this.darkMode ? '#172554' : '#F1F6FF')
      .border({ width: 1, color: ThemeColor.get(this.darkMode).primaryLight })
      .borderRadius(10)
    }
    .width('100%')
    .margin({ top: 14 })
    .onClick(onTap)
  }

  @Builder
  private buildDivider() {
    Divider()
      .color(ThemeColor.get(this.darkMode).border)
      .margin({ top: 14 })
  }

  @Builder
  private buildBookCard() {
    Column() {
      Text('当前词书')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .width('100%')

      if (this.wordBookList.length > 0) {
        Column() {
          ForEach(this.wordBookList, (book: WordBook) => {
            Row() {
              Row()
                .width(18)
                .height(18)
                .borderRadius(9)
                .border({
                  width: 2,
                  color: book.id === this.selectedBookId
                    ? ThemeColor.get(this.darkMode).primary
                    : ThemeColor.get(this.darkMode).border
                })
                .backgroundColor(book.id === this.selectedBookId
                  ? ThemeColor.get(this.darkMode).primary
                  : Color.Transparent)
                .margin({ right: 10 })

              Column() {
                Text(book.name)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ThemeColor.get(this.darkMode).textPrimary)
                  .width('100%')
                Text(book.totalCount.toString() + ' 个单词')
                  .fontSize(12)
                  .fontColor(ThemeColor.get(this.darkMode).textSecondary)
                  .margin({ top: 2 })
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(12)
            .margin({ top: 8 })
            .backgroundColor(ThemeColor.get(this.darkMode).background)
            .borderRadius(12)
            .onClick(() => {
              this.selectedBookId = book.id;
              this.selectedBookName = book.name;
              this.selectedBookTotal = book.totalCount;
              if (!this.manualGoalMode) {
                this.adjustGoalsByTargetDate();
                this.markPlanChanged();
              }
              this.autoSavePlan();
            })
          }, (item: WordBook) => item.id.toString())
        }
        .width('100%')
        .margin({ top: 4 })
      }
    }
    .width('100%')
    .padding(18)
    .margin({ top: 12 })
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
    .borderRadius(18)
    .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
  }

  @Builder
  private buildPlanCard() {
    Column() {
      Text('学习目标')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(ThemeColor.get(this.darkMode).textPrimary)
        .width('100%')

      this.buildDailyGoalRow()
      this.buildDivider()

      this.buildReviewGoalRow()
      this.buildDivider()

      this.buildRelearnGoalRow()
      this.buildDivider()

      this.buildWeeklyDaysRow()
      this.buildDivider()

      this.buildTargetDateRow()
      this.buildDivider()

      Row() {
        Text('周末学习')
          .fontSize(15)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.weekendEnabled })
          .onChange((isOn: boolean) => {
            this.weekendEnabled = isOn;
            this.applyWeekendStudyChange(isOn);
            this.showToast(isOn ? '已开启周末学习' : '已关闭周末学习');
            this.autoSavePlan();
          })
      }
      .width('100%')
      .margin({ top: 14 })

      this.buildDivider()

      Row() {
        Text('学习提醒')
          .fontSize(15)
          .fontColor(ThemeColor.get(this.darkMode).textPrimary)
          .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.reminderEnabled })
          .onChange((isOn: boolean) => {
            this.reminderEnabled = isOn;
            this.showToast(isOn ? '已开启学习提醒' : '已关闭学习提醒');
            this.autoSavePlan();
          })
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .width('100%')
    .padding(18)
    .margin({ top: 16 })
    .backgroundColor(ThemeColor.get(this.darkMode).cardBackground)
    .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
    .borderRadius(20)
    .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
  }

  build() {
    HdsNavDestination() {
      List({ scroller: this.pageScroller }) {
        if (this.isLoading) {
          ListItem() {
            Text('正在加载学习计划...')
              .fontSize(16)
              .fontColor(ThemeColor.get(this.darkMode).textSecondary)
              .margin({ top: 16 })
          }
          .width('100%')
          .reuseId('study-plan-loading')
        } else {
          ListItem() {
            this.buildBookCard()
          }
          .width('100%')
          .reuseId('study-plan-book')

          ListItem() {
            this.buildPlanCard()
          }
          .width('100%')
          .reuseId('study-plan-form-' + this.refreshTick.toString())

          if (this.getSuggestionText().length > 0) {
            ListItem() {
              Text(this.getSuggestionText())
                .width('100%')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(ThemeColor.get(this.darkMode).primary)
                .margin({ top: 18 })
            }
            .width('100%')
            .reuseId('study-plan-suggestion')
          }


        }

        ListItem() {
          Column().width('100%').height(32)
        }
        .width('100%')
        .reuseId('study-plan-bottom-spacer')
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
    .titleBar(createHdsSubPageTitleBarOptions('学习计划', this.darkMode, this.materialEffectMode))
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .onBackPressed(() => {
      router.back();
      return true;
    })
    .bindToScrollable([this.pageScroller])
    .backgroundColor(ThemeColor.get(this.darkMode).background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
