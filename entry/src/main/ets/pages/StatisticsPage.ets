import { common } from '@kit.AbilityKit';
import { SegmentButton, SegmentButtonOptions } from '@kit.ArkUI';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import router from '@ohos.router';
import { DateUtil } from '../utils/DateUtil';
import { ThemeColor } from '../utils/ThemeColor';
import { DatabaseService } from '../services/DatabaseService';
import { PreferencesService } from '../services/PreferencesService';
import { StatisticsService } from '../services/StatisticsService';
import { ThemeService } from '../services/ThemeService';
import { WordService } from '../services/WordService';
import { Word } from '../model/Word';
import { StudyDaily, StudyStats } from '../model/StudyStats';
import { DurationTrendCard } from '../components/DurationTrendCard';
import { createHdsTabTitleBarOptions } from '../components/HdsTabTitleBarOptions';
import { Constants } from '../utils/Constants';

interface DonutSegment {
  label: string;
  value: number;
  color: string;
}

interface RingSegment {
  color: string;
  dash: number[];
  offset: number;
}

@Component
export struct StatisticsPage {
  @Prop @Watch('onRefresh') refreshToken: number = 0;
  @Prop @Watch('onReselect') reselectToken: number = 0;
  @State private isLoading: boolean = true;
  @StorageLink('statisticsTimeTab') timeTab: string = '日';
  @State private timeTabSelectedIndexes: number[] = [1];
  @State private timeSegmentOptions: SegmentButtonOptions = SegmentButtonOptions.tab({
    buttons: [
      { text: '全部' },
      { text: '日' },
      { text: '周' },
      { text: '月' },
      { text: '年' }
    ],
    fontSize: 14,
    selectedFontSize: 14,
    fontWeight: FontWeight.Normal,
    selectedFontWeight: FontWeight.Medium,
    fontColor: '#64748B',
    selectedFontColor: Color.White,
    backgroundColor: '#F5F3FD',
    selectedBackgroundColor: '#8B5CF6'
  });
  @State private currentMonthYear: string = new Date().getFullYear().toString() + '年' + (new Date().getMonth() + 1).toString() + '月';
  @State private stats: StudyStats = {
    todayLearnCount: 0,
    todayReviewCount: 0,
    todayCorrectCount: 0,
    todayWrongCount: 0,
    pendingReviewCount: 0,
    unknownWordCount: 0,
    masteredCount: 0,
    totalWordCount: 0,
    unmasteredCount: 0,
    inLearningCount: 0,
    totalCorrectCount: 0,
    totalWrongCount: 0,
    accuracyRate: 0,
    studyDuration: 0
  };
  @State private dailyStats: StudyDaily[] = [];
  @State private hourlyStats: StudyDaily[] = [];
  @State private trendChartDataAll: StudyDaily[] = [];
  @State private trendChartDataDay: StudyDaily[] = [];
  @State private trendChartDataWeek: StudyDaily[] = [];
  @State private trendChartDataMonth: StudyDaily[] = [];
  @State private trendChartDataYear: StudyDaily[] = [];
  @State private currentTrendChartData: StudyDaily[] = [];
  @State private currentTrendChartTab: string = '日';
  @State private chartVersion: number = 0;
  @StorageLink('resolvedDarkMode') @Watch('refreshTimeSegmentOptions') darkMode: boolean = false;
  @State private selectedBookId: number = 0;
  @State private wordPeriod: string = '全部';
  @State private showWordPeriodMenu: boolean = false;
  @State private calendarDays: number[] = [];
  @State private currentYear: number = new Date().getFullYear();
  @State private currentMonth: number = new Date().getMonth() + 1;
  @State private calendarDailyStats: StudyDaily[] = [];
  @State private calendarDailyGoal: number = Constants.DEFAULT_DAILY_GOAL;
  @State private selectedDateKey: string = DateUtil.todayKey();
  @State private ringSegmentData: RingSegment[] = [];
  @State private unmasteredWordCount: number = 0;
  @State private reviewWordCount: number = 0;
  @State private masteredWordCount: number = 0;
  @State private learningWordCount: number = 0;
  @State private todayReviewedCount: number = 0;
  @StorageLink('materialEffectMode') materialEffectMode: number = Constants.DEFAULT_MATERIAL_EFFECT_MODE;
  private timeTabs: string[] = ['全部', '日', '周', '月', '年'];
  private weekHeaders: string[] = ['一', '二', '三', '四', '五', '六', '日'];
  private wordPeriods: string[] = ['全部', '日', '周', '月', '年'];
  @State private statsLoadToken: number = 0;
  @State private activeStatsTab: string = '日';
  private pageScroller: Scroller = new Scroller();
  private isRefreshingTimeSegmentStyle: boolean = false;
  private calendarLoadToken: number = 0;

  private onReselect(): void {
    this.pageScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
    this.loadStats(this.timeTab);
  }

  private onRefresh(): void {
    this.loadStats(this.timeTab);
  }

  aboutToAppear(): void {
    this.refreshTimeSegmentOptions();
    // 验证日历：打印当前月份天数和首日星期
    const now: Date = new Date();
    const y: number = now.getFullYear();
    const m: number = now.getMonth() + 1;
    const firstDay: number = new Date(y, now.getMonth(), 1).getDay();
    const daysInMonth: number = new Date(y, m, 0).getDate();
    const weekNames: string[] = ['日', '一', '二', '三', '四', '五', '六'];
    console.info('[Calendar] 当前 ' + y + '年' + m + '月, 天数=' + daysInMonth + ', 首日=星期' + weekNames[firstDay]);

    this.loadStats(this.timeTab);
  }

  onPageShow(): void {
    const context = getContext(this) as common.Context;
    ThemeService.applySystemBars(context, this.darkMode);
    this.refreshTimeSegmentOptions();
    this.loadStats(this.timeTab);
  }

  private isActiveStatsLoad(token: number, tab: string): boolean {
    return token === this.statsLoadToken && tab === this.activeStatsTab;
  }

  private async loadStats(tab: string = this.timeTab): Promise<void> {
    const loadToken: number = ++this.statsLoadToken;
    this.activeStatsTab = tab;
    this.isLoading = true;
    try {
      const context = getContext(this) as common.Context;
      await DatabaseService.init(context);
      await PreferencesService.init(context);
      const bookId: number = await PreferencesService.getSelectedBookId();
      const dailyGoal: number = await PreferencesService.getDailyGoal();
      if (!this.isActiveStatsLoad(loadToken, tab)) return;
      this.selectedBookId = bookId;
      this.calendarDailyGoal = Math.max(1, dailyGoal);
      const targetDate: string = tab === '日' ? this.selectedDateKey : DateUtil.todayKey();
      // 计算目标日期已复习的去重单词数（当前词书），在 loadPeriodData 前执行
      if (bookId > 0) {
        const reviewedIds: number[] = await PreferencesService.getReviewedWordIds(targetDate);
        const reviewedCount: number = await WordService.getTodayReviewedCountByBookId(bookId, reviewedIds);
        if (!this.isActiveStatsLoad(loadToken, tab)) return;
        this.todayReviewedCount = reviewedCount;
      } else {
        this.todayReviewedCount = 0;
      }
      await this.loadPeriodData(tab, loadToken, bookId, targetDate);
      if (!this.isActiveStatsLoad(loadToken, tab)) return;
      await this.loadCalendarMonth(this.currentYear, this.currentMonth);
    } catch (error) {
      console.error('StatisticsPage loadStats failed: ' + JSON.stringify(error));
    } finally {
      if (this.isActiveStatsLoad(loadToken, tab)) {
        this.isLoading = false;
      }
    }
  }

  private async loadPeriodData(
    tab: string, loadToken: number, bookId: number, targetDate: string
  ): Promise<void> {
    if (tab === '全部') {
      const nextStats: StudyStats = await StatisticsService.getTotalOverviewStats(bookId);
      const nextReviewWordCount: number = (await WordService.getWordsByStatType('recent')).length;
      if (!this.isActiveStatsLoad(loadToken, tab)) return;
      this.stats = nextStats;
      this.reviewWordCount = nextReviewWordCount;
      this.masteredWordCount = Math.max(0, nextStats.totalWordCount - nextReviewWordCount);
    } else {
      const nextStats: StudyStats = tab === '日' ?
        await StatisticsService.getDateOverviewStats(targetDate, bookId) :
        await StatisticsService.getPeriodOverviewStats(tab, bookId);
      const startDate: string = tab === '日' ? targetDate : DateUtil.periodStartKey(tab);
      const endDate: string = tab === '日' ? targetDate : DateUtil.periodEndKey(tab);
      // 期间内已复习的单词数（与导航 mode='recent' 同源）
      const periodWords: Word[] = await WordService.getWordsByPeriod('recent', startDate, endDate, bookId);
      if (!this.isActiveStatsLoad(loadToken, tab)) return;
      this.stats = nextStats;
      this.reviewWordCount = periodWords.length;
      this.masteredWordCount = 0;
    }
    this.unmasteredWordCount = 0;
    this.learningWordCount = 0;
    this.updateRingData();
    // 日视图下额外加载目标日期的逐小时数据
    if (tab === '日') {
      const nextDailyCompareStats: StudyDaily[] = await StatisticsService.getDailyComparisonStats(targetDate);
      const nextHourlyStats: StudyDaily[] = await StatisticsService.getHourlyStats(targetDate);
      if (!this.isActiveStatsLoad(loadToken, tab)) return;
      this.hourlyStats = nextHourlyStats;
      this.dailyStats = nextDailyCompareStats;
      this.trendChartDataDay = nextHourlyStats.slice();
      this.currentTrendChartData = nextHourlyStats.slice();
      this.currentTrendChartTab = tab;
      this.isLoading = false;
      this.chartVersion++;
    } else {
      let nextDailyStats: StudyDaily[] = [];
      if (tab === '全部') {
        nextDailyStats = await StatisticsService.getAllDailyStats();
      } else if (tab === '周') {
        nextDailyStats = await StatisticsService.getPeriodDailyStats('日', 7);
      } else if (tab === '月') {
        nextDailyStats = await StatisticsService.getCurrentMonthDailyStats();
      } else if (tab === '年') {
        nextDailyStats = await StatisticsService.getPeriodDailyStats('月', 12);
      } else if (this.wordPeriod === '全部') {
        nextDailyStats = await StatisticsService.getPeriodDailyStats(tab, 7);
      } else {
        nextDailyStats = await StatisticsService.getPeriodDailyStats(this.wordPeriod, 7);
      }
      if (!this.isActiveStatsLoad(loadToken, tab)) return;
      this.hourlyStats = [];
      if (tab === '月') {
        this.dailyStats = await StatisticsService.getPeriodDailyStats('月', 2);
        if (!this.isActiveStatsLoad(loadToken, tab)) return;
      } else {
        this.dailyStats = nextDailyStats;
      }
      if (tab === '全部') {
        this.trendChartDataAll = nextDailyStats.slice();
      } else if (tab === '周') {
        this.trendChartDataWeek = nextDailyStats.slice();
      } else if (tab === '月') {
        this.trendChartDataMonth = nextDailyStats.slice();
      } else if (tab === '年') {
        this.trendChartDataYear = nextDailyStats.slice();
      }
      this.currentTrendChartData = nextDailyStats.slice();
      this.currentTrendChartTab = tab;
      this.isLoading = false;
      this.chartVersion++;
    }
  }

  private onTimeTabChange(tab: string): void {
    if (this.isRefreshingTimeSegmentStyle && tab !== this.timeTab) {
      this.syncTimeTabSelectedIndexes();
      return;
    }
    if (tab === this.timeTab) {
      return;
    }
    this.timeTab = tab;
    this.timeTabSelectedIndexes = [this.timeTabs.indexOf(tab)];
    this.activeStatsTab = tab;
    this.isLoading = true;
    this.dailyStats = [];
    this.hourlyStats = [];
    this.currentTrendChartData = [];
    this.currentTrendChartTab = tab;
    this.clearTrendChartData(tab);
    this.chartVersion++;
    this.loadStats(tab);
  }

  private syncTimeTabSelectedIndexes(): void {
    this.timeTabSelectedIndexes = [Math.max(0, this.timeTabs.indexOf(this.timeTab))];
  }

  private onWordPeriodChange(period: string): void {
    this.wordPeriod = period;
    this.showWordPeriodMenu = false;
    this.chartVersion++;
    this.loadStats(this.timeTab);
  }

  private getTrendChartData(): StudyDaily[] {
    if (this.isLoading) return [];
    if (this.currentTrendChartTab !== this.timeTab) return [];
    return this.currentTrendChartData;
  }

  private getTrendChartRenderKey(): string {
    const chartData: StudyDaily[] = this.getTrendChartData();
    const firstDate: string = chartData.length > 0 ? chartData[0].date : '';
    const lastDate: string = chartData.length > 0 ? chartData[chartData.length - 1].date : '';
    return this.timeTab + '-' +
      this.currentTrendChartTab + '-' +
      this.chartVersion.toString() + '-' +
      (this.isLoading ? 'loading' : 'ready') + '-' +
      chartData.length.toString() + '-' +
      firstDate + '-' +
      lastDate;
  }

  private clearTrendChartData(tab: string): void {
    this.trendChartDataAll = [];
    this.trendChartDataDay = [];
    this.trendChartDataWeek = [];
    this.trendChartDataMonth = [];
    this.trendChartDataYear = [];
  }

  // ---- 日历导航 ----
  private navigateMonth(delta: number): void {
    let nextYear: number = this.currentYear;
    let nextMonth: number = this.currentMonth + delta;
    if (nextMonth > 12) {
      nextMonth = 1;
      nextYear++;
    } else if (nextMonth < 1) {
      nextMonth = 12;
      nextYear--;
    }
    this.currentYear = nextYear;
    this.currentMonth = nextMonth;
    this.currentMonthYear = nextYear.toString() + '年' + nextMonth.toString() + '月';
    this.loadCalendarMonth(nextYear, nextMonth);
  }

  private async loadCalendarMonth(year: number, month: number): Promise<void> {
    const loadToken: number = ++this.calendarLoadToken;
    this.calendarDays = DateUtil.monthDays(year, month);
    try {
      const monthStats: StudyDaily[] = await StatisticsService.getMonthDailyStats(year, month);
      if (loadToken === this.calendarLoadToken &&
        year === this.currentYear && month === this.currentMonth) {
        this.calendarDailyStats = monthStats;
      }
    } catch (error) {
      console.error('StatisticsPage loadCalendarMonth failed: ' + JSON.stringify(error));
      if (loadToken === this.calendarLoadToken) {
        this.calendarDailyStats = [];
      }
    }
  }

  // 将平坦日期数组分割为周数组（每行7个）
  private generateCalendarWeeks(days: number[]): number[][] {
    const weeks: number[][] = [];
    for (let i: number = 0; i < days.length; i += 7) {
      const week: number[] = days.slice(i, i + 7);
      // 最后一周不足7格的用0补齐，保证每行7列等宽不错位
      while (week.length < 7) {
        week.push(0);
      }
      weeks.push(week);
    }
    return weeks;
  }

  /** 格式化日期键 */
  private formatDateKey(year: number, month: number, day: number): string {
    const mo: string = month < 10 ? '0' + month.toString() : month.toString();
    const dy: string = day < 10 ? '0' + day.toString() : day.toString();
    return year.toString() + '-' + mo + '-' + dy;
  }

  private isToday(dayNum: number): boolean {
    const now: Date = new Date();
    return dayNum === now.getDate() &&
      this.currentMonth === (now.getMonth() + 1) &&
      this.currentYear === now.getFullYear();
  }

  private isStudiedDay(dayNum: number): boolean {
    const stats: StudyDaily | undefined = this.getCalendarDayStats(dayNum);
    return stats !== undefined && (stats.learnCount + stats.reviewCount > 0 || stats.duration > 0);
  }

  private getCalendarDayStats(dayNum: number): StudyDaily | undefined {
    if (dayNum <= 0) {
      return undefined;
    }
    const key: string = this.formatDateKey(this.currentYear, this.currentMonth, dayNum);
    for (let index: number = 0; index < this.calendarDailyStats.length; index++) {
      if (this.calendarDailyStats[index].date === key) {
        return this.calendarDailyStats[index];
      }
    }
    return undefined;
  }

  private calendarStudyCount(dayNum: number): number {
    const stats: StudyDaily | undefined = this.getCalendarDayStats(dayNum);
    return stats === undefined ? 0 : stats.learnCount + stats.reviewCount;
  }

  private calendarLevel(dayNum: number): string {
    const count: number = this.calendarStudyCount(dayNum);
    if (count <= 0) {
      return 'none';
    }
    if (count < this.calendarDailyGoal) {
      return 'below';
    }
    if (count < Math.ceil(this.calendarDailyGoal * 1.5)) {
      return 'goal';
    }
    return 'exceed';
  }

  private calendarLevelLabel(dayNum: number): string {
    const level: string = this.calendarLevel(dayNum);
    if (level === 'below') {
      return '未达标';
    }
    if (level === 'goal') {
      return '完成目标';
    }
    if (level === 'exceed') {
      return '远超目标';
    }
    return '无学习记录';
  }

  private calendarLevelColor(level: string): string {
    if (level === 'below') {
      return this.darkMode ? '#8C6264' : '#F7B8B1';
    }
    if (level === 'goal') {
      return this.darkMode ? '#956778' : '#F3B0C1';
    }
    if (level === 'exceed') {
      return this.darkMode ? '#746C9D' : '#C5B8F2';
    }
    return '#00000000';
  }

  private calendarDayTextColor(dayNum: number): string {
    if (this.calendarLevel(dayNum) !== 'none') {
      return '#FFFFFF';
    }
    return this.darkMode ? '#F8FAFC' : '#1A1A2E';
  }

  private calendarDayBorderWidth(dayNum: number): number {
    return this.isSelectedDay(dayNum) && !this.isToday(dayNum) ? 1 : 0;
  }

  private calendarDayBorderColor(dayNum: number): string {
    if (this.isSelectedDay(dayNum) && !this.isToday(dayNum)) {
      return this.darkMode ? '#F1E8FF' : '#7A5AB5';
    }
    return '#00000000';
  }

  private calendarDayAccessibilityText(dayNum: number): string {
    if (dayNum <= 0) {
      return '';
    }
    const count: number = this.calendarStudyCount(dayNum);
    const date: string = this.formatDateKey(this.currentYear, this.currentMonth, dayNum);
    return date + '，学习 ' + count.toString() + ' 词，每日目标 ' +
      this.calendarDailyGoal.toString() + ' 词，' + this.calendarLevelLabel(dayNum);
  }

  @Builder
  private buildCalendarLegendItem(label: string, color: string) {
    Row() {
      Column()
        .width(8)
        .height(8)
        .borderRadius(4)
        .backgroundColor(color)
      Text(label)
        .fontSize(11)
        .fontColor(this.darkMode ? '#94A3B8' : '#64748B')
        .margin({ left: 4 })
    }
    .alignItems(VerticalAlign.Center)
  }

  private isSelectedDay(dayNum: number): boolean {
    return dayNum > 0 &&
      this.selectedDateKey === this.formatDateKey(this.currentYear, this.currentMonth, dayNum);
  }

  private onCalendarDayClick(dayNum: number): void {
    if (dayNum <= 0 || !this.isStudiedDay(dayNum)) {
      return;
    }
    const dateKey: string = this.formatDateKey(this.currentYear, this.currentMonth, dayNum);
    if (this.timeTab === '日' && this.selectedDateKey === dateKey) {
      return;
    }
    this.selectedDateKey = dateKey;
    this.timeTab = '日';
    this.timeTabSelectedIndexes = [this.timeTabs.indexOf('日')];
    this.activeStatsTab = '日';
    this.isLoading = true;
    this.dailyStats = [];
    this.hourlyStats = [];
    this.currentTrendChartData = [];
    this.currentTrendChartTab = '日';
    this.clearTrendChartData('日');
    this.chartVersion++;
    this.loadStats('日');
    this.pageScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true });
  }

  private dayOverviewLabel(): string {
    if (this.selectedDateKey === DateUtil.todayKey()) {
      return '今日数据';
    }
    const parts: string[] = this.selectedDateKey.split('-');
    if (parts.length !== 3) {
      return this.selectedDateKey;
    }
    return parseInt(parts[1]) + '月' + parseInt(parts[2]) + '日数据';
  }

  // ---- 学习概览环比辅助 ----  // 计算与上一周期的差值：index 0=新学 1=时长 2=复习 3=掌握率
  private calcCompare(index: number): number {
    if (this.dailyStats.length < 2) {
      return 0;
    }
    const curr: StudyDaily = this.dailyStats[this.dailyStats.length - 1];
    const prev: StudyDaily = this.dailyStats[this.dailyStats.length - 2];
    if (index === 0) {
      return curr.learnCount - prev.learnCount;
    } else if (index === 1) {
      return Math.round((curr.duration - prev.duration) / 60);
    } else if (index === 2) {
      return curr.reviewCount - prev.reviewCount;
    } else {
      const currRate: number = (curr.correctCount + curr.wrongCount) > 0 ?
        Math.round(curr.correctCount * 1000 / (curr.correctCount + curr.wrongCount)) / 10 : 0;
      const prevRate: number = (prev.correctCount + prev.wrongCount) > 0 ?
        Math.round(prev.correctCount * 1000 / (prev.correctCount + prev.wrongCount)) / 10 : 0;
      return Math.round((currRate - prevRate) * 10) / 10;
    }
  }

  // 环比显示格式：正数+"+", 负数直接显示, 0显示"—"
  private formatCompareValue(val: number, suffix: string = ''): string {
    if (val === 0) {
      return '—';
    }
    const prefix: string = val > 0 ? '+' : '';
    return prefix + val.toString() + suffix;
  }

  private compareColor(val: number): string {
    if (val > 0) {
      return '#10B981';
    } else if (val < 0) {
      return '#EF4444';
    }
    return this.darkMode ? '#64748B' : '#B0B0C8';
  }

  private newWordsIcon(): Resource {
    return this.darkMode ? $r('app.media.stat_new_words_dark') : $r('app.media.stat_new_words');
  }

  private studyDurationIcon(): Resource {
    return this.darkMode ? $r('app.media.stat_study_duration_dark') : $r('app.media.stat_study_duration');
  }

  private reviewWordsIcon(): Resource {
    return this.darkMode ? $r('app.media.stat_review_words_dark') : $r('app.media.stat_review_words');
  }

  private masteryRateIcon(): Resource {
    return this.darkMode ? $r('app.media.stat_mastery_rate_dark') : $r('app.media.stat_mastery_rate');
  }

  private wordOverviewIcon(): Resource {
    return this.darkMode ? $r('app.media.stat_word_overview_dark') : $r('app.media.stat_word_overview');
  }

  private calendarIcon(): Resource {
    return this.darkMode ? $r('app.media.stat_calendar_dark') : $r('app.media.stat_calendar');
  }

  // ---- 环形图数据驱动 ----

  private readonly donutRadius: number = 44;
  private readonly donutStroke: number = 16;
  private readonly gapPx: number = 3;

  private getDonutSegments(): DonutSegment[] {
    const palette = ThemeColor.get(this.darkMode);
    const learned: number = this.stats.todayLearnCount;
    const reviewed: number = this.todayReviewedCount;
    const notLearned: number = Math.max(0,
      this.stats.totalWordCount - learned);
    return [
      { label: '已学习', value: learned, color: palette.primary },
      { label: '不认识', value: this.stats.unknownWordCount, color: '#EF9A9A' },
      { label: '已复习', value: reviewed, color: palette.success },
      { label: '未学习', value: notLearned, color: '#B0BEC5' },
    ];
  }

  // 根据四项词数自动计算占比 + dash/offset
  private computeSegments(data: DonutSegment[]): RingSegment[] {
    const total: number = data.reduce((sum: number, d: DonutSegment) => sum + d.value, 0);
    if (total === 0) {
      return [];
    }
    const circ: number = 2 * Math.PI * this.donutRadius;
    let accumulated: number = 0;
    return data.map((d: DonutSegment) => {
      const frac: number = d.value / total;
      const segLen: number = circ * frac;
      const visibleLen: number = Math.max(segLen - this.gapPx, 0);
      const seg: RingSegment = {
        color: d.color,
        dash: [visibleLen, circ - visibleLen],
        offset: -accumulated
      };
      accumulated += segLen;
      return seg;
    });
  }

  // 返回标签实际显示的词数
  private getLabelCount(seg: DonutSegment): number {
    if (seg.label === '已学习') {
      return this.stats.todayLearnCount;
    }
    if (seg.label === '不认识') {
      return this.stats.unknownWordCount;
    }
    if (seg.label === '已复习') {
      return this.todayReviewedCount;
    }
    if (seg.label === '未学习') {
      return Math.max(0, this.stats.totalWordCount - this.stats.todayLearnCount);
    }
    return seg.value;
  }

  // 当 stats 更新后刷新环形图
  private updateRingData(): void {
    this.ringSegmentData = this.computeSegments(this.getDonutSegments());
  }

  private refreshTimeSegmentOptions(): void {
    this.isRefreshingTimeSegmentStyle = true;
    this.timeSegmentOptions.fontColor = this.darkMode ? '#CBD5E1' : '#64748B';
    this.timeSegmentOptions.selectedFontColor = Color.White;
    this.timeSegmentOptions.backgroundColor = this.darkMode ? '#111827' : '#F5F3FD';
    this.timeSegmentOptions.selectedBackgroundColor = '#8B5CF6';
    this.syncTimeTabSelectedIndexes();
    setTimeout(() => {
      this.syncTimeTabSelectedIndexes();
    }, 0);
    setTimeout(() => {
      this.syncTimeTabSelectedIndexes();
    }, 80);
    setTimeout(() => {
      this.syncTimeTabSelectedIndexes();
      this.isRefreshingTimeSegmentStyle = false;
    }, 240);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      HdsNavigation() {
        List({ scroller: this.pageScroller }) {
          ListItem() {
          // 时间 Tab
          SegmentButton({
            options: this.timeSegmentOptions,
            selectedIndexes: $timeTabSelectedIndexes,
            onItemClicked: (index: number) => {
              this.onTimeTabChange(this.timeTabs[index]);
            }
          })
          .width('100%')
          .borderRadius(22)
          .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
          .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
          .margin({ top: 136 })
          }
          .width('100%')
          .reuseId('statistics-time-tabs')

          ListItem() {
          // 学习概览
          Column() {
            // 头部栏
            Row() {
              Image(this.newWordsIcon())
                .width(18)
                .height(18)
                .objectFit(ImageFit.Contain)
              .width(18)
              .height(18)
              Text('学习概览')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')
                .margin({ left: 6 })
              Blank()
              Text(this.timeTab === '日' ? this.dayOverviewLabel() :
                this.timeTab === '全部' ? '全部数据' : this.timeTab + '度数据')
                .fontSize(14)
                .fontColor(this.darkMode ? '#94A3B8' : '#8C8CA8')
              Text(' ›')
                .fontSize(14)
                .fontColor(this.darkMode ? '#94A3B8' : '#8C8CA8')
                .margin({ left: 2 })
                .onClick(() => {
                  router.pushUrl({ url: 'pages/StudyPage' });
                })
            }
            .width('100%')

            // 四列数据
            Row() {
              // 新学单词
              Column() {
                Image(this.newWordsIcon())
                  .width(20)
                  .height(20)
                  .objectFit(ImageFit.Contain)
                .width(20)
                .height(20)
                Text(this.stats.todayLearnCount.toString())
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')
                  .margin({ top: 6 })
                Text('新学单词')
                  .fontSize(13)
                  .fontColor(this.darkMode ? '#94A3B8' : '#8C8CA8')
                  .margin({ top: 4 })
                Text(this.formatCompareValue(this.calcCompare(0)))
                  .fontSize(12)
                  .fontColor(this.compareColor(this.calcCompare(0)))
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Center)
              .justifyContent(FlexAlign.Center)
              .layoutWeight(1)
              .onClick(() => {
                const spLearn: Record<string, Object> = {};
                spLearn['mode'] = 'learnToday';
                spLearn['title'] = '新学单词';
                spLearn['timeTab'] = this.timeTab;
                spLearn['bookId'] = this.selectedBookId;
                router.pushUrl({
                  url: 'pages/SearchPage',
                  params: spLearn
                });
              })

              Column().width(1).height(60).backgroundColor(this.darkMode ? '#334155' : '#EAE6F0')

              // 学习时长
              Column() {
                Image(this.studyDurationIcon())
                  .width(20)
                  .height(20)
                  .objectFit(ImageFit.Contain)
                .width(20)
                .height(20)
                Text((this.stats.studyDuration / 60).toFixed(1))
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')
                  .margin({ top: 6 })
                Text('学习时长')
                  .fontSize(13)
                  .fontColor(this.darkMode ? '#94A3B8' : '#8C8CA8')
                  .margin({ top: 4 })
                Text(this.formatCompareValue(this.calcCompare(1), ' 分钟'))
                  .fontSize(12)
                  .fontColor(this.compareColor(this.calcCompare(1)))
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Center)
              .justifyContent(FlexAlign.Center)
              .layoutWeight(1)
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/StudyDurationPage',
                  params: { timeTab: this.timeTab }
                });
              })

              Column().width(1).height(60).backgroundColor(this.darkMode ? '#334155' : '#EAE6F0')

              // 复习单词
              Column() {
                Image(this.reviewWordsIcon())
                  .width(20)
                  .height(20)
                  .objectFit(ImageFit.Contain)
                .width(20)
                .height(20)
                Text(this.todayReviewedCount.toString())
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')
                  .margin({ top: 6 })
                Text('复习单词')
                  .fontSize(13)
                  .fontColor(this.darkMode ? '#94A3B8' : '#8C8CA8')
                  .margin({ top: 4 })
                Text(this.formatCompareValue(this.calcCompare(2)))
                  .fontSize(12)
                  .fontColor(this.compareColor(this.calcCompare(2)))
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Center)
              .justifyContent(FlexAlign.Center)
              .layoutWeight(1)
              .onClick(() => {
                const rp: Record<string, Object> = {};
                if (this.selectedBookId > 0) {
                  rp['bookId'] = this.selectedBookId;
                }
                rp['timeTab'] = this.timeTab;
                router.pushUrl({ url: 'pages/ReviewPage', params: rp });
              })

              Column().width(1).height(60).backgroundColor(this.darkMode ? '#334155' : '#EAE6F0')

              // 掌握率
              Column() {
                Image(this.masteryRateIcon())
                  .width(20)
                  .height(20)
                  .objectFit(ImageFit.Contain)
                .width(20)
                .height(20)
                Text(this.stats.accuracyRate.toString() + '%')
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')
                  .margin({ top: 6 })
                Text('掌握率')
                  .fontSize(13)
                  .fontColor(this.darkMode ? '#94A3B8' : '#8C8CA8')
                  .margin({ top: 4 })
                Text(this.formatCompareValue(this.calcCompare(3), '%'))
                  .fontSize(12)
                  .fontColor(this.compareColor(this.calcCompare(3)))
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Center)
              .justifyContent(FlexAlign.Center)
              .layoutWeight(1)
              .onClick(() => {
                const spMast: Record<string, Object> = {};
                spMast['mode'] = 'mastered';
                spMast['title'] = '已掌握单词';
                spMast['timeTab'] = this.timeTab;
                spMast['bookId'] = this.selectedBookId;
                router.pushUrl({ url: 'pages/SearchPage', params: spMast });
              })
            }
            .width('100%')
            .margin({ top: 14 })
          }
          .width('100%')
          .padding({ top: 16, right: 16, bottom: 16, left: 16 })
          .borderRadius(22)
          .backgroundColor(this.darkMode ? '#111827' : '#F5F3FD')
          .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
          .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
          .margin({ top: 16 })
          }
          .width('100%')
          .reuseId('statistics-overview')

          ListItem() {
          // 学习时长趋势 — 折线图卡片
          if (this.timeTab === '全部') {
            DurationTrendCard({
              dailyStats: this.trendChartDataAll,
              isLoading: this.isLoading,
              darkMode: this.darkMode,
              timeTab: '全部',
              refreshKey: this.chartVersion
            })
          } else if (this.timeTab === '日') {
            DurationTrendCard({
              dailyStats: this.trendChartDataDay,
              isLoading: this.isLoading,
              darkMode: this.darkMode,
              timeTab: '日',
              refreshKey: this.chartVersion
            })
          } else if (this.timeTab === '周') {
            DurationTrendCard({
              dailyStats: this.trendChartDataWeek,
              isLoading: this.isLoading,
              darkMode: this.darkMode,
              timeTab: '周',
              refreshKey: this.chartVersion
            })
          } else if (this.timeTab === '月') {
            DurationTrendCard({
              dailyStats: this.trendChartDataMonth,
              isLoading: this.isLoading,
              darkMode: this.darkMode,
              timeTab: '月',
              refreshKey: this.chartVersion
            })
          } else {
            DurationTrendCard({
              dailyStats: this.trendChartDataYear,
              isLoading: this.isLoading,
              darkMode: this.darkMode,
              timeTab: '年',
              refreshKey: this.chartVersion
            })
          }
          }
          .width('100%')
          .reuseId('statistics-duration-trend')

          ListItem() {
          // 单词学习情况
          Column() {
            // 头部栏
            Row() {
              Image(this.wordOverviewIcon())
                .width(18)
                .height(18)
                .objectFit(ImageFit.Contain)
              .width(18)
              .height(18)
              Text('单词学习情况')
                .fontSize(15)
                .fontWeight(600)
                .fontColor(this.darkMode ? '#F8FAFC' : '#333333')
                .margin({ left: 6 })
              Blank()
            }
            .width('100%')

            // 主体：环形图 + 图例
            Row() {
              // 左侧环形图（Circle 组件，数据驱动）
              Stack() {
                // 环形段
                ForEach(this.ringSegmentData, (seg: RingSegment, i: number) => {
                  Circle()
                    .width(88)
                    .height(88)
                    .stroke(seg.color)
                    .strokeWidth(16)
                    .fill(Color.Transparent)
                    .strokeDashArray(seg.dash)
                    .strokeDashOffset(seg.offset)
                    .rotate({ angle: -90 })
                }, (seg: RingSegment, i: number) => i.toString())

                // 中心文字：期间学习总词量
                Column() {
                  Text(this.stats.totalWordCount.toString())
                    .fontSize(20)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.darkMode ? '#F8FAFC' : '#333333')
                  Text('总学习')
                    .fontSize(11)
                    .fontColor(this.darkMode ? '#94A3B8' : '#999999')
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Center)
              }
              .width(120)
              .height(120)

              // 右侧图例列表（数据驱动，零值显示灰）
              Column() {
                ForEach(this.getDonutSegments(), (seg: DonutSegment) => {
                  Row() {
                    // 色点 + 分类名
                    Row() {
                      Row()
                        .width(9)
                        .height(9)
                        .backgroundColor(this.getLabelCount(seg) > 0 ? seg.color : (this.darkMode ? '#475569' : '#D0D0D0'))
                        .borderRadius(5)
                      Text(seg.label)
                        .fontSize(13)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.getLabelCount(seg) > 0
                          ? (this.darkMode ? '#CBD5E1' : '#444444')
                          : (this.darkMode ? '#475569' : '#D0D0D0'))
                        .margin({ left: 8 })
                        .maxLines(1)
                    }
                    .alignItems(VerticalAlign.Center)

                    Blank()

                    // 词数
                    Text(this.getLabelCount(seg).toString() + ' 词')
                      .fontSize(13)
                      .fontWeight(600)
                      .fontColor(this.getLabelCount(seg) > 0
                        ? (this.darkMode ? '#F8FAFC' : '#333333')
                        : (this.darkMode ? '#475569' : '#D0D0D0'))
                      .width(52)
                      .textAlign(TextAlign.End)
                      .margin({ right: 12 })
                      .maxLines(1)

                    // 百分比（已复习用掌握词数做分母，其余用总词数）
                    Text(
                      ((seg.label === '已复习' ? this.stats.masteredCount : this.stats.totalWordCount) > 0
                        ? Math.round(this.getLabelCount(seg) * 1000 / (seg.label === '已复习' ? this.stats.masteredCount : this.stats.totalWordCount)) / 10
                        : 0).toString() + '%'
                    )
                      .fontSize(11)
                      .fontColor(this.getLabelCount(seg) > 0
                        ? (this.darkMode ? '#94A3B8' : '#8C8CA8')
                        : (this.darkMode ? '#475569' : '#DDDDDD'))
                      .width(36)
                      .textAlign(TextAlign.End)
                      .margin({ right: 16 })
                      .maxLines(1)
                  }
                  .width('100%')
                  .height(28)
                  .padding({ right: 8 })
                  .alignItems(VerticalAlign.Center)
                  .margin({ bottom: 8 })
                  .onClick(() => {
                    const spSeg: Record<string, Object> = {};
                    spSeg['timeTab'] = this.timeTab;
                    spSeg['bookId'] = this.selectedBookId;
                    if (seg.label === '已学习') {
                      spSeg['mode'] = 'learnToday';
                      spSeg['title'] = '新学单词';
                      router.pushUrl({ url: 'pages/SearchPage', params: spSeg });
                    } else if (seg.label === '不认识') {
                      spSeg['mode'] = 'unknown';
                      spSeg['title'] = '不认识单词';
                      router.pushUrl({ url: 'pages/SearchPage', params: spSeg });
                    } else if (seg.label === '已复习') {
                      const rp: Record<string, Object> = {};
                      if (this.selectedBookId > 0) {
                        rp['bookId'] = this.selectedBookId;
                      }
                      rp['timeTab'] = this.timeTab;
                      router.pushUrl({ url: 'pages/ReviewPage', params: rp });
                    } else if (seg.label === '未学习') {
                      spSeg['mode'] = 'unstudied';
                      spSeg['title'] = '未学习单词';
                      router.pushUrl({ url: 'pages/SearchPage', params: spSeg });
                    }
                  })
                }, (seg: DonutSegment, i: number) => seg.label + i.toString())
              }
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
              .margin({ left: 8 })
            }
            .width('100%')
            .margin({ top: 12 })
          }
          .width('100%')
          .padding({ top: 14, right: 16, bottom: 14, left: 16 })
          .borderRadius(22)
          .backgroundColor(this.darkMode ? '#111827' : Color.White)
          .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
          .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
          .margin({ top: 16 })
          }
          .width('100%')
          .reuseId('statistics-word-overview')

          ListItem() {
          // 学习打卡日历
          Column() {
            Row() {
              Image(this.calendarIcon())
                .width(20)
                .height(20)
                .objectFit(ImageFit.Contain)
              .width(20)
              .height(20)
              Text('学习打卡日历')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')
                .margin({ left: 8 })
              Blank()
              Row() {
                Image(this.darkMode ? $r('app.media.back_dark') : $r('app.media.back_light'))
                  .width(11)
                  .height(11)
                  .objectFit(ImageFit.Contain)
                  .onClick(() => {
                    this.navigateMonth(-1);
                  })
                Text(' ' + this.currentMonthYear + ' ')
                  .fontSize(14)
                  .fontColor(this.darkMode ? '#F8FAFC' : '#1A1A2E')
                  .fontWeight(FontWeight.Medium)
                Image(this.darkMode ? $r('app.media.back_dark') : $r('app.media.back_light'))
                  .width(11)
                  .height(11)
                  .objectFit(ImageFit.Contain)
                  .scale({ x: -1, y: 1 })
                  .onClick(() => {
                    this.navigateMonth(1);
                  })
              }
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')

            // 星期行
            Row() {
              ForEach(this.weekHeaders, (day: string) => {
                Text(day)
                  .fontSize(11)
                  .fontColor(this.darkMode ? '#64748B' : '#B0B0C8')
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)
                  .padding({ top: 4, bottom: 4 })
              }, (day: string) => day)
            }
            .width('100%')
            .margin({ top: 14 })

            Row({ space: 12 }) {
              this.buildCalendarLegendItem('未达标', this.calendarLevelColor('below'))
              this.buildCalendarLegendItem('完成目标', this.calendarLevelColor('goal'))
              this.buildCalendarLegendItem('远超目标', this.calendarLevelColor('exceed'))
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ top: 8 })

            // 日历网格 — 手动按7列分行，保证空白占位格不塌缩
            Column() {
              ForEach(this.generateCalendarWeeks(this.calendarDays), (week: number[], weekIndex: number) => {
                Row() {
                  ForEach([0, 1, 2, 3, 4, 5, 6], (di: number) => {
                    Column() {
                      Column() {
                        Text(week[di] === 0 ? ' ' : week[di].toString())
                          .fontSize(13)
                          .fontColor(week[di] === 0 ? Color.Transparent : this.calendarDayTextColor(week[di]))
                          .fontWeight(week[di] > 0 && this.calendarLevel(week[di]) !== 'none' ?
                            FontWeight.Bold : FontWeight.Normal)
                      }
                      .width(36)
                      .height(36)
                      .alignItems(HorizontalAlign.Center)
                      .justifyContent(FlexAlign.Center)
                      .borderRadius(18)
                      .backgroundColor(this.calendarLevelColor(this.calendarLevel(week[di])))
                      .border({
                        width: this.calendarDayBorderWidth(week[di]),
                        color: this.calendarDayBorderColor(week[di])
                      })
                    }
                    .alignItems(HorizontalAlign.Center)
                    .justifyContent(FlexAlign.Center)
                    .layoutWeight(1)
                    .height(48)
                    .focusable(week[di] > 0 && this.isStudiedDay(week[di]))
                    .accessibilityText(this.calendarDayAccessibilityText(week[di]))
                    .onClick(() => {
                      this.onCalendarDayClick(week[di]);
                    })
                  }, (di: number) => this.currentYear.toString() + '-' + this.currentMonth.toString() + '-' + weekIndex.toString() + '-' + di.toString() + '-' + week[di].toString())
                }
                .width('100%')
              }, (week: number[], wi: number) => this.currentYear.toString() + '-' + this.currentMonth.toString() + '-' + wi.toString() + '-' + week.join(','))
            }
            .width('100%')
            .margin({ top: 8 })
          }
          .width('100%')
          .padding(20)
          .borderRadius(22)
          .backgroundColor(this.darkMode ? '#111827' : Color.White)
          .border({ width: 1, color: ThemeColor.get(this.darkMode).border })
          .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
          .margin({ top: 16 })
          }
          .width('100%')
          .reuseId('statistics-calendar')

          ListItem() {
            Column().width('100%').height(120)
          }
          .width('100%')
          .reuseId('statistics-bottom-spacer')
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
      .titleBar(createHdsTabTitleBarOptions('学习统计', '数据记录成长，点滴成就未来',
        this.darkMode, this.materialEffectMode))
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

