/**
 * DurationTrendCard 鈥?瀛︿範鏃堕暱瓒嬪娍缁勪欢鍥捐〃
 * 浣跨敤 ArkUI 缁勪欢鏋勫缓锛屼笉浣跨敤 Canvas 鑷粯銆? */

import { StudyDaily } from '../model/StudyStats';

interface ChartItem {
  index: number;
  slot: number;
  label: string;
  value: number;
  height: number;
}

interface SegmentItem {
  index: number;
  x: number;
  y: number;
  width: number;
  angle: number;
}

interface AreaSlice {
  index: number;
  x: number;
  y: number;
  width: number;
  height: number;
}

@Component
export struct DurationTrendCard {
  @Prop @Watch('onDataChange') dailyStats: StudyDaily[] = [];
  @Prop @Watch('onDataChange') isLoading: boolean = false;
  @Prop @Watch('onDataChange') darkMode: boolean = false;
  @Prop @Watch('onDataChange') timeTab: string = '';
  @Prop @Watch('onDataChange') refreshKey: number = 0;
  @State private selectedIndex: number = -1;
  @State private viewportStart: number = 0;
  @State private syncedChartKey: string = '';
  @State private cachedMinutes: number[] = [];
  @State private cachedAxisMode: string = 'day';
  @State private cachedYMax: number = 5;
  @State private cachedTickLabels: string[] = [];

  private get textPrimary(): string { return this.darkMode ? '#F8FAFC' : '#1A1A2E'; }
  private get textSecondary(): string { return this.darkMode ? '#94A3B8' : '#8C8CA8'; }
  private get labelColor(): string { return this.darkMode ? '#64748B' : '#8F8CAF'; }
  private get axisColor(): string { return this.darkMode ? 'rgba(100, 116, 139, 0.38)' : 'rgba(200, 192, 216, 0.42)'; }
  private get gridColor(): string { return this.darkMode ? 'rgba(75, 85, 99, 0.24)' : 'rgba(215, 210, 230, 0.34)'; }
  private get skeletonColor(): string { return this.darkMode ? '#2A2A3E' : '#E8E4F0'; }
  private get pointFillColor(): string { return '#FFFFFF'; }
  private get areaTopColor(): string { return this.darkMode ? '#5B21B6' : '#CFC5FF'; }
  private get areaMidColor(): string { return this.darkMode ? '#4338CA' : '#E6E1FF'; }
  private get areaBottomColor(): string { return this.darkMode ? '#312E81' : '#FAF8FF'; }
  private get areaBaseColor(): string { return this.darkMode ? '#312E81' : '#EFEAFF'; }
  private get areaFillColor(): string { return this.darkMode ? '#4C1D95' : '#DDD5FF'; }
  private durationTrendIcon(): Resource {
    return this.darkMode ? $r('app.media.stat_duration_trend_dark') : $r('app.media.stat_duration_trend');
  }

  private readonly lineColor: string = '#8B7CF6';
  private readonly lineInnerColor: string = '#FFFFFF';
  private readonly bubbleColor: string = '#8B5CF6';
  private readonly plotHeight: number = 150;
  private readonly plotTopPadding: number = 24;
  private readonly plotBottomPadding: number = 8;
  private readonly chartHeight: number = 178;
  private readonly windowSize: number = 8;
  private readonly pointSlotWidth: number = 32;
  private readonly pointSize: number = 18;
  private readonly xLabelWidth: number = 38;
  private readonly plotSidePadding: number = 14;
  private readonly bubbleWidth: number = 82;
  private readonly bubbleHeight: number = 28;
  private readonly yAxisWidth: number = 24;
  private readonly axisGap: number = 10;
  private areaSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private areaCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.areaSettings);
  private chartScroller: Scroller = new Scroller();
  private touchStartX: number = 0;
  private touchStartY: number = 0;
  private touchStartViewportStart: number = 0;
  private pendingDragX: number = 0;
  private cachedAllItems: ChartItem[] = [];
  private cachedVisibleItems: ChartItem[] = [];
  private cachedVisibleItemsKey: string = '';

  private onDataChange(): void {
    const previousKey: string = this.syncedChartKey;
    this.syncChartState();
    if (previousKey !== this.syncedChartKey) {
      this.scrollToDefaultViewport();
    }
  }

  private resetChartState(): void {
    const total: number = this.dailyStats ? this.dailyStats.length : 0;
    this.viewportStart = this.getDefaultViewportStart(total);
    this.selectedIndex = this.getDefaultSelectedIndex(total);
  }

  private getChartStateKey(): string {
    const firstDate: string = this.dailyStats && this.dailyStats.length > 0 ? this.dailyStats[0].date : '';
    const lastDate: string = this.dailyStats && this.dailyStats.length > 0 ? this.dailyStats[this.dailyStats.length - 1].date : '';
    return this.timeTab + '-' + this.refreshKey.toString() + '-' + (this.dailyStats ? this.dailyStats.length.toString() : '0') + '-' + firstDate + '-' + lastDate;
  }

  private syncChartState(): void {
    const nextKey: string = this.getChartStateKey();
    if (nextKey !== this.syncedChartKey) {
      this.syncedChartKey = nextKey;
      this.refreshChartDataCache();
      this.resetChartState();
    }
  }

  private refreshChartDataCache(): void {
    this.cachedMinutes = this.computeMinutes();
    this.cachedAxisMode = this.computeAxisMode();
    this.cachedYMax = this.calcYMaxForValues(this.cachedMinutes);
    this.cachedTickLabels = this.getTickLabels(this.cachedYMax);
    this.cachedAllItems = this.computeAllItems();
    this.cachedVisibleItems = [];
    this.cachedVisibleItemsKey = '';
  }

  private fmtDate(s: string): string {
    const p: string[] = s.split('-');
    if (p.length >= 3) return parseInt(p[1]) + '/' + parseInt(p[2]);
    return s;
  }

  private fmtHour(s: string): string {
    const p: string[] = s.split(':');
    if (p.length >= 1) return (parseInt(p[0]) + 1).toString() + '时';
    return s;
  }

  private fmtMonth(s: string): string {
    const p: string[] = s.split('-');
    if (p.length >= 2) return parseInt(p[1]).toString() + '月';
    return s;
  }

  private computeAxisMode(): string {
    if (!this.dailyStats || this.dailyStats.length === 0) return 'day';
    const date: string = this.dailyStats[0].date;
    if (date.indexOf(':') >= 0) return 'hour';
    if (date.length === 7 && date.indexOf('-') === 4) return 'month';
    return 'day';
  }

  private getAxisMode(): string {
    this.ensureChartStateSynced();
    return this.cachedAxisMode;
  }

  private computeMinutes(): number[] {
    if (!this.dailyStats) return [];
    return this.dailyStats.map((item: StudyDaily): number => {
      const minutes: number = item.duration < 60 ? Math.floor(item.duration / 6) / 10 : Math.round(item.duration / 6) / 10;
      return item.duration > 0 && minutes === 0 ? 0.1 : minutes;
    });
  }

  private getMinutes(): number[] {
    this.ensureChartStateSynced();
    return this.cachedMinutes;
  }

  private formatMinuteValue(value: number): string {
    if (value === 0) return '0';
    if (value < 1) return value.toFixed(1);
    if (Math.abs(value - Math.round(value)) < 0.01) return Math.round(value).toString();
    return value.toFixed(1);
  }

  private calcYMaxForValues(vals: number[]): number {
    if (vals.length === 0) return 1;
    let maxValue: number = 0;
    for (let i: number = 0; i < vals.length; i++) {
      maxValue = Math.max(maxValue, vals[i]);
    }
    if (maxValue <= 5) return 5;
    if (maxValue <= 10) return 10;
    if (maxValue <= 30) return Math.ceil(maxValue / 5) * 5;
    if (maxValue <= 60) return Math.ceil(maxValue / 10) * 10;
    return Math.ceil(maxValue / 20) * 20;
  }

  private getTickLabels(yMax: number): string[] {
    const labels: string[] = [];
    for (let i: number = 5; i >= 0; i--) {
      labels.push(Math.round(yMax * i / 5).toString());
    }
    return labels;
  }

  private getLabel(date: string): string {
    const axisMode: string = this.getAxisMode();
    if (axisMode === 'hour') return this.fmtHour(date);
    if (axisMode === 'month') return this.fmtMonth(date);
    return this.fmtDate(date);
  }

  private shouldShowLabel(index: number, total: number): boolean {
    return true;
  }

  private shouldUseViewport(total: number): boolean {
    return total > this.windowSize;
  }

  private shouldLockLatestWindow(): boolean {
    return this.timeTab === '年';
  }

  private getVisibleStart(total: number): number {
    this.ensureChartStateSynced();
    if (!this.shouldUseViewport(total)) return 0;
    const maxStart: number = Math.max(0, total - this.windowSize);
    if (this.shouldLockLatestWindow()) return maxStart;
    return Math.max(0, Math.min(this.viewportStart, maxStart));
  }

  private getVisibleEnd(total: number, visibleStart: number): number {
    return this.shouldUseViewport(total) ? Math.min(total, visibleStart + this.windowSize) : total;
  }

  private getDefaultViewportStart(total: number): number {
    if (!this.shouldUseViewport(total)) return 0;
    const maxStart: number = Math.max(0, total - this.windowSize);
    if (maxStart === 0) return 0;
    if (this.shouldLockLatestWindow()) return maxStart;
    if (this.getAxisMode() === 'hour') {
      const rightIndex: number = Math.min(total - 1, new Date().getHours() + 1);
      return Math.max(0, Math.min(maxStart, rightIndex - this.windowSize + 1));
    }
    if (this.timeTab === '月') {
      const rightIndex: number = Math.min(total - 1, new Date().getDate());
      return Math.max(0, Math.min(maxStart, rightIndex - this.windowSize + 1));
    }
    const lastValueIndex: number = this.getLastNonZeroIndex();
    if (lastValueIndex >= 0) {
      return Math.max(0, Math.min(maxStart, lastValueIndex - this.windowSize + 1));
    }
    if (this.timeTab === '日') {
      const currentHour: number = new Date().getHours();
      return Math.max(0, Math.min(maxStart, currentHour - this.windowSize + 1));
    }
    return maxStart;
  }

  private getLastNonZeroIndex(): number {
    const vals: number[] = this.getMinutes();
    for (let i: number = vals.length - 1; i >= 0; i--) {
      if (vals[i] > 0) {
        return i;
      }
    }
    return -1;
  }

  private getDefaultSelectedIndex(total: number): number {
    if (total <= 0) return -1;
    const visibleStart: number = this.getVisibleStart(total);
    const visibleEnd: number = this.getVisibleEnd(total, visibleStart);
    return Math.max(0, visibleEnd - 1);
  }

  private moveViewportTo(nextStart: number): void {
    const total: number = this.dailyStats ? this.dailyStats.length : 0;
    if (!this.shouldUseViewport(total)) return;
    if (this.shouldLockLatestWindow()) return;
    const maxStart: number = Math.max(0, total - this.windowSize);
    const clampedStart: number = Math.max(0, Math.min(maxStart, nextStart));
    if (clampedStart !== this.viewportStart) {
      this.viewportStart = clampedStart;
      this.selectedIndex = Math.max(0, Math.min(total - 1, clampedStart + this.windowSize - 1));
    }
  }

  private buildChartItems(vals: number[], startIndex: number, slotTotal: number, yMax: number): ChartItem[] {
    const items: ChartItem[] = [];
    for (let i: number = 0; i < vals.length; i++) {
      const height: number = vals[i] > 0 ? Math.max(8, Math.round(vals[i] / yMax * this.getValueRangeHeight())) : 0;
      items.push({
        index: startIndex + i,
        slot: this.getSlotIndex(i, slotTotal),
        label: this.getLabel(this.dailyStats[startIndex + i].date),
        value: vals[i],
        height: height
      });
    }
    return items;
  }

  private getVisibleItems(): ChartItem[] {
    this.ensureChartStateSynced();
    const allVals: number[] = this.getMinutes();
    if (!allVals.length || !this.dailyStats || this.dailyStats.length === 0) return [];
    const visibleStart: number = this.getVisibleStart(allVals.length);
    const visibleEnd: number = this.getVisibleEnd(allVals.length, visibleStart);
    const cacheKey: string = this.syncedChartKey + '-visible-' + visibleStart.toString() + '-' + visibleEnd.toString();
    if (cacheKey === this.cachedVisibleItemsKey) {
      return this.cachedVisibleItems;
    }
    const vals: number[] = allVals.slice(visibleStart, visibleEnd);
    const yMax: number = this.getChartYMax(vals);
    this.cachedVisibleItems = this.buildChartItems(vals, visibleStart, vals.length, yMax);
    this.cachedVisibleItemsKey = cacheKey;
    return this.cachedVisibleItems;
  }

  private getSlotIndex(index: number, total: number): number {
    if (total <= 1) return 0;
    if (total >= this.windowSize) return index;
    return index * (this.windowSize - 1) / (total - 1);
  }

  private getTopSpacerHeight(itemHeight: number): number {
    return Math.max(0, this.getPointCenterYByHeight(itemHeight) - 8);
  }

  private getStemHeight(itemHeight: number): number {
    return Math.max(0, this.plotHeight - this.plotBottomPadding - this.getPointCenterYByHeight(itemHeight) - 8);
  }

  private getPointCenterY(item: ChartItem): number {
    return this.getPointCenterYByHeight(item.height);
  }

  private getPointCenterYByHeight(itemHeight: number): number {
    return this.plotHeight - this.plotBottomPadding - itemHeight;
  }

  private getValueRangeHeight(): number {
    return this.plotHeight - this.plotTopPadding - this.plotBottomPadding;
  }

  private getPointCenterX(item: ChartItem): number {
    return this.plotSidePadding + item.slot * this.pointSlotWidth;
  }

  private getPlotContentWidth(items: ChartItem[]): number {
    const slotCount: number = this.getSlotCount(items.length);
    return Math.max(this.bubbleWidth, this.plotSidePadding * 2 + Math.max(0, slotCount - 1) * this.pointSlotWidth);
  }

  private getPlotOffsetX(): number {
    return this.yAxisWidth + this.axisGap;
  }

  private getChartContentWidth(items: ChartItem[]): number {
    return this.getPlotOffsetX() + this.getPlotContentWidth(items);
  }

  private getSlotCount(total: number): number {
    return Math.max(this.windowSize, total);
  }

  private getViewportPlotWidth(): number {
    return this.plotSidePadding * 2 + (this.windowSize - 1) * this.pointSlotWidth;
  }

  private getViewportChartContentWidth(): number {
    return this.getPlotOffsetX() + this.getViewportPlotWidth();
  }

  private shouldUseNativeHorizontalScroll(): boolean {
    return this.shouldUseViewport(this.dailyStats ? this.dailyStats.length : 0) &&
      (this.getAxisMode() === 'hour' || this.timeTab === '月');
  }

  private getDefaultScrollOffsetX(): number {
    const total: number = this.dailyStats ? this.dailyStats.length : 0;
    if (!this.shouldUseNativeHorizontalScroll()) return 0;
    return this.getVisibleStart(total) * this.pointSlotWidth;
  }

  private scrollToDefaultViewport(): void {
    if (!this.shouldUseNativeHorizontalScroll()) return;
    this.chartScroller.scrollTo({
      xOffset: this.getDefaultScrollOffsetX(),
      yOffset: 0
    });
  }

  private computeAllItems(): ChartItem[] {
    const allVals: number[] = this.getMinutes();
    if (!allVals.length || !this.dailyStats || this.dailyStats.length === 0) return [];
    return this.buildChartItems(allVals, 0, allVals.length, this.getChartYMax(allVals));
  }

  private getAllItems(): ChartItem[] {
    this.ensureChartStateSynced();
    return this.cachedAllItems;
  }

  private getSegments(items: ChartItem[]): SegmentItem[] {
    const result: SegmentItem[] = [];
    if (!this.hasVisiblePositiveValue(items)) {
      return result;
    }
    const pointRadius: number = 7;
    for (let i: number = 0; i < items.length - 1; i++) {
      const startItem: ChartItem = items[i];
      const endItem: ChartItem = items[i + 1];
      const startY: number = this.getPointCenterY(startItem);
      const endY: number = this.getPointCenterY(endItem);
      const startX: number = this.getPointCenterX(startItem);
      const endX: number = this.getPointCenterX(endItem);
      const dx: number = endX - startX;
      const dy: number = endY - startY;
      const length: number = Math.sqrt(dx * dx + dy * dy);
      if (length <= pointRadius * 2) {
        continue;
      }
      const offsetX: number = dx / length * pointRadius;
      const offsetY: number = dy / length * pointRadius;
      result.push({
        index: startItem.index,
        x: startX + offsetX,
        y: startY + offsetY,
        width: length - pointRadius * 2,
        angle: Math.atan2(dy, dx) * 180 / Math.PI
      });
    }
    return result;
  }

  private hasVisiblePositiveValue(items: ChartItem[]): boolean {
    for (let i: number = 0; i < items.length; i++) {
      if (items[i].value > 0) {
        return true;
      }
    }
    return false;
  }

  private getAreaLeft(items: ChartItem[], index: number): number {
    if (items.length === 0) return 0;
    if (index <= 0) return 0;
    return (this.getPointCenterX(items[index - 1]) + this.getPointCenterX(items[index])) / 2;
  }

  private getAreaRight(items: ChartItem[], index: number): number {
    if (items.length === 0) return 0;
    if (index >= items.length - 1) return this.getPlotContentWidth(items);
    return (this.getPointCenterX(items[index]) + this.getPointCenterX(items[index + 1])) / 2;
  }

  private getAreaWidth(items: ChartItem[], index: number): number {
    return Math.max(0, this.getAreaRight(items, index) - this.getAreaLeft(items, index) + 1);
  }

  private getAreaY(item: ChartItem): number {
    return this.getPointCenterY(item) + 2;
  }

  private getAreaHeight(item: ChartItem): number {
    return Math.max(0, this.plotHeight - this.plotBottomPadding - this.getAreaY(item));
  }

  private getAreaFillX(items: ChartItem[]): number {
    if (items.length === 0) return 0;
    const firstX: number = this.getPointCenterX(items[0]);
    return Math.max(0, firstX - this.pointSlotWidth / 2);
  }

  private getAreaFillWidth(items: ChartItem[]): number {
    if (items.length === 0) return 0;
    const left: number = this.getAreaFillX(items);
    const lastX: number = this.getPointCenterX(items[items.length - 1]);
    const right: number = Math.min(this.getPlotContentWidth(items), lastX + this.pointSlotWidth / 2);
    return Math.max(0, right - left);
  }

  private getAreaFillTopY(items: ChartItem[]): number {
    if (items.length === 0) return this.plotHeight - this.plotBottomPadding;
    const baselineY: number = this.plotHeight - this.plotBottomPadding;
    let topY: number = baselineY;
    for (let i: number = 0; i < items.length; i++) {
      topY = Math.min(topY, this.getPointCenterY(items[i]) + 2);
    }
    return Math.max(this.plotTopPadding, Math.min(topY, baselineY - 48));
  }

  private getAreaFillHeight(items: ChartItem[]): number {
    const baselineY: number = this.plotHeight - this.plotBottomPadding;
    return Math.max(0, baselineY - this.getAreaFillTopY(items));
  }

  private getAreaBandHeight(items: ChartItem[], ratio: number): number {
    return Math.max(1, Math.round(this.getAreaFillHeight(items) * ratio));
  }

  private getSliceBandHeight(slice: AreaSlice, ratio: number): number {
    return Math.max(1, Math.round(slice.height * ratio));
  }

  private getAreaSlices(items: ChartItem[]): AreaSlice[] {
    const slices: AreaSlice[] = [];
    if (items.length < 2) return slices;
    const baselineY: number = this.plotHeight - this.plotBottomPadding;
    let sliceIndex: number = 0;
    for (let i: number = 0; i < items.length - 1; i++) {
      const startX: number = this.getPointCenterX(items[i]);
      const endX: number = this.getPointCenterX(items[i + 1]);
      const startY: number = this.getPointCenterY(items[i]);
      const endY: number = this.getPointCenterY(items[i + 1]);
      const dx: number = endX - startX;
      const count: number = Math.max(1, Math.ceil(Math.abs(dx) / 4));
      const sliceWidth: number = Math.abs(dx) / count + 2;
      for (let s: number = 0; s < count; s++) {
        const t: number = (s + 0.5) / count;
        const y: number = startY + (endY - startY) * t + 2;
        slices.push({
          index: sliceIndex,
          x: startX + dx * s / count,
          y: y,
          width: sliceWidth,
          height: Math.max(0, baselineY - y)
        });
        sliceIndex++;
      }
    }
    return slices;
  }

  private drawAreaGradient(items: ChartItem[]): void {
    const ctx: CanvasRenderingContext2D = this.areaCtx;
    const width: number = this.getPlotContentWidth(items);
    const height: number = this.plotHeight;
    ctx.clearRect(0, 0, width, height);
    if (items.length < 2 || !this.hasVisiblePositiveValue(items)) return;

    const baselineY: number = this.plotHeight - this.plotBottomPadding;
    const gradient: CanvasGradient = ctx.createLinearGradient(0, this.plotTopPadding, 0, baselineY);
    gradient.addColorStop(0, this.darkMode ? 'rgba(216, 207, 249, 0.38)' : 'rgba(216, 207, 249, 0.56)');
    gradient.addColorStop(0.55, this.darkMode ? 'rgba(216, 207, 249, 0.18)' : 'rgba(216, 207, 249, 0.30)');
    gradient.addColorStop(1, 'rgba(216, 207, 249, 0.00)');

    ctx.beginPath();
    ctx.moveTo(this.getPointCenterX(items[0]), this.getPointCenterY(items[0]));
    for (let i: number = 1; i < items.length; i++) {
      ctx.lineTo(this.getPointCenterX(items[i]), this.getPointCenterY(items[i]));
    }
    ctx.lineTo(this.getPointCenterX(items[items.length - 1]), baselineY);
    ctx.lineTo(this.getPointCenterX(items[0]), baselineY);
    ctx.closePath();
    ctx.fillStyle = gradient;
    ctx.fill();
  }

  private getVisibleYMax(): number {
    this.ensureChartStateSynced();
    return this.cachedYMax;
  }

  private getVisibleTickLabels(): string[] {
    this.ensureChartStateSynced();
    return this.cachedTickLabels;
  }

  private getChartYMax(vals: number[]): number {
    return this.calcYMaxForValues(vals);
  }

  private getSelectedItem(): ChartItem | null {
    const items: ChartItem[] = this.getVisibleItems();
    for (let i: number = 0; i < items.length; i++) {
      if (items[i].index === this.selectedIndex) return items[i];
    }
    return null;
  }

  private getSelectedText(item?: ChartItem): string {
    if (item !== undefined) return this.formatMinuteValue(item.value);
    const selectedItem: ChartItem | null = this.getSelectedItem();
    if (selectedItem === null) return '';
    return this.formatMinuteValue(selectedItem.value);
  }

  private getBubbleX(item: ChartItem, items: ChartItem[]): number {
    const centerX: number = this.getPointCenterX(item);
    const maxX: number = this.getPlotContentWidth(items) - this.bubbleWidth;
    return Math.max(0, Math.min(maxX, centerX - this.bubbleWidth / 2));
  }

  private getBubbleY(item: ChartItem): number {
    const aboveY: number = this.getPointCenterY(item) - this.bubbleHeight - 12;
    if (aboveY >= 0) return aboveY;
    return Math.min(this.plotHeight - this.bubbleHeight, this.getPointCenterY(item) + 14);
  }

  private getBubbleAnchorX(item: ChartItem): number {
    return this.getPointCenterX(item);
  }

  private getBubbleAnchorY(item: ChartItem): number {
    const aboveY: number = this.getPointCenterY(item) - this.bubbleHeight - 12;
    return aboveY >= 0 ? this.getPointCenterY(item) - 6 : this.getPointCenterY(item) + 8;
  }

  private getBubbleAnchorHeight(item: ChartItem): number {
    return this.getPointCenterY(item) - this.bubbleHeight - 12 >= 0 ? 6 : 0;
  }

  private getBubbleAnchorOpacity(item: ChartItem): number {
    return this.getPointCenterY(item) - this.bubbleHeight - 12 >= 0 ? 1 : 0;
  }

  private getGuideX(item: ChartItem): number {
    return this.getPointCenterX(item) - 1;
  }

  private getGuideY(item: ChartItem): number {
    return this.getPointCenterY(item) + 8;
  }

  private getGuideHeight(item: ChartItem): number {
    return Math.max(0, this.plotHeight - this.getGuideY(item));
  }

  private shouldShowSelectedGuide(item: ChartItem, items: ChartItem[]): boolean {
    return item.index === this.selectedIndex &&
      item.value > 0 &&
      items.length > 0 &&
      item.index === items[items.length - 1].index;
  }

  private getGuideDashOffsets(item: ChartItem): number[] {
    const offsets: number[] = [];
    const dashHeight: number = 5;
    const dashGap: number = 4;
    const guideHeight: number = this.getGuideHeight(item);
    for (let y: number = 0; y < guideHeight; y += dashHeight + dashGap) {
      offsets.push(y);
    }
    return offsets;
  }

  private getGuideDashHeight(item: ChartItem, offset: number): number {
    return Math.max(0, Math.min(5, this.getGuideHeight(item) - offset));
  }

  private getGridLineY(index: number): number {
    const lineHeight: number = index === 5 ? 2 : 1.5;
    const step: number = this.getValueRangeHeight() / 5;
    const centerY: number = this.plotTopPadding + step * index;
    return Math.max(0, Math.min(this.plotHeight - lineHeight, Math.round(centerY - lineHeight / 2)));
  }

  private getYAxisLabelY(index: number): number {
    const step: number = this.getValueRangeHeight() / 5;
    const centerY: number = this.plotTopPadding + step * index;
    return Math.max(0, Math.min(this.plotHeight - 18, Math.round(centerY - 9)));
  }

  private shouldShowPointValue(item: ChartItem): boolean {
    return true;
  }

  private ensureChartStateSynced(): void {
    const nextKey: string = this.getChartStateKey();
    if (nextKey !== this.syncedChartKey) {
      this.syncedChartKey = nextKey;
      this.refreshChartDataCache();
      this.resetChartState();
    }
  }

  private moveViewportByDrag(dx: number): void {
    if (Math.abs(dx) <= this.pointSlotWidth / 2) return;
    const offset: number = dx > 0 ?
      Math.floor((dx + this.pointSlotWidth / 2) / this.pointSlotWidth) :
      Math.ceil((dx - this.pointSlotWidth / 2) / this.pointSlotWidth);
    this.moveViewportTo(this.touchStartViewportStart - offset);
  }

  private rememberDrag(dx: number): void {
    this.pendingDragX = dx;
  }

  private commitDrag(): void {
    this.moveViewportByDrag(this.pendingDragX);
    this.pendingDragX = 0;
    this.touchStartViewportStart = this.viewportStart;
  }

  private handleChartTouch(event: TouchEvent): void {
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.commitDrag();
      return;
    }
    if (!event.touches || event.touches.length === 0) return;
    const touchX: number = event.touches[0].x;
    const touchY: number = event.touches[0].y;

    if (event.type === TouchType.Down) {
      this.touchStartX = touchX;
      this.touchStartY = touchY;
      this.touchStartViewportStart = this.viewportStart;
      this.pendingDragX = 0;
      return;
    }

    if (event.type === TouchType.Move) {
      const dx: number = touchX - this.touchStartX;
      const dy: number = touchY - this.touchStartY;
      if (Math.abs(dx) > 12 && Math.abs(dx) > Math.abs(dy)) {
        this.rememberDrag(dx);
      }
    }
  }

  private handlePanStart(): void {
    this.ensureChartStateSynced();
    this.touchStartViewportStart = this.viewportStart;
    this.pendingDragX = 0;
  }

  private handlePanUpdate(event: GestureEvent): void {
    this.rememberDrag(event.offsetX);
  }

  private handlePanEnd(): void {
    this.commitDrag();
  }

  private selectItem(index: number): void {
    this.selectedIndex = index;
  }

  @Builder
  private buildSkeleton() {
    Column() {
      ForEach([0, 1, 2, 3], (): void => {
        Row() {
          Column().width(28).height(8).borderRadius(4).backgroundColor(this.skeletonColor)
          Blank()
        }.width('100%').height(36).alignItems(VerticalAlign.Center)
      }, (_: number, i: number): string => i.toString())
    }
    .opacity(0.5)
    .width('100%')
    .height(this.chartHeight)
  }

  @Builder
  private buildEmptyChart() {
    Column() {
      Text('暂无学习数据')
        .fontSize(14)
        .fontColor(this.textSecondary)
    }
    .width('100%')
    .height(this.chartHeight)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildAxisGrid(items: ChartItem[]) {
    Stack({ alignContent: Alignment.Start }) {
      ForEach(this.getVisibleTickLabels(), (label: string, i: number): void => {
        Row() {
          Text(label)
            .fontSize(10)
            .fontColor(this.labelColor)
            .width(this.yAxisWidth)
            .height(18)
            .textAlign(TextAlign.End)
            .translate({ x: -4, y: 0 })

          Blank()
            .width(this.axisGap)

          Blank()
            .width(this.getPlotContentWidth(items))
            .height(1)
        }
        .width(this.getChartContentWidth(items))
        .height(18)
        .alignItems(VerticalAlign.Center)
        .position({ x: 0, y: this.getYAxisLabelY(i) })
      }, (label: string, i: number): string => label + i.toString())
    }
    .width(this.getChartContentWidth(items))
    .height(this.plotHeight)
  }

  @Builder
  private buildYAxisOnly() {
    Stack({ alignContent: Alignment.Start }) {
      ForEach(this.getVisibleTickLabels(), (label: string, i: number): void => {
        Text(label)
          .fontSize(10)
          .fontColor(this.labelColor)
          .width(this.yAxisWidth)
          .height(18)
          .textAlign(TextAlign.End)
          .translate({ x: -4, y: 0 })
          .position({ x: 0, y: this.getYAxisLabelY(i) })
      }, (label: string, i: number): string => label + '-scroll-y-' + i.toString())
    }
    .width(this.getPlotOffsetX())
    .height(this.plotHeight)
  }

  @Builder
  private buildLineSegments(items: ChartItem[]) {
    Stack({ alignContent: Alignment.Start }) {
      ForEach(this.getSegments(items), (segment: SegmentItem): void => {
        Row()
          .width(segment.width)
          .height(2.4)
          .borderRadius(2)
          .backgroundColor(this.lineColor)
          .position({ x: segment.x, y: segment.y - 1.2 })
          .rotate({ angle: segment.angle, centerX: 0, centerY: 1.2 })
      }, (segment: SegmentItem): string => this.getChartStateKey() + '-line-' + segment.index.toString())
    }
    .width(this.getPlotContentWidth(items))
    .height(this.plotHeight)
  }

  @Builder
  private buildPlotGridLines(items: ChartItem[]) {
    Stack({ alignContent: Alignment.Start }) {
      ForEach(this.getVisibleTickLabels(), (_: string, i: number): void => {
        Divider()
          .width(this.getPlotContentWidth(items))
          .color(i === 5 ? this.axisColor : this.gridColor)
          .strokeWidth(i === 5 ? 1.4 : 1)
          .position({ x: 0, y: this.getGridLineY(i) })
      }, (_: string, i: number): string => this.getChartStateKey() + '-grid-' + i.toString())
    }
    .width(this.getPlotContentWidth(items))
    .height(this.plotHeight)
  }

  @Builder
  private buildAreaGradient(items: ChartItem[]) {
    Canvas(this.areaCtx)
      .width(this.getPlotContentWidth(items))
      .height(this.plotHeight)
      .onReady((): void => {
        this.drawAreaGradient(items);
      })
      .onAreaChange((): void => {
        this.drawAreaGradient(items);
      })
    .width(this.getPlotContentWidth(items))
    .height(this.plotHeight)
  }

  @Builder
  private buildPointSeries(items: ChartItem[]) {
    Stack({ alignContent: Alignment.Start }) {
      ForEach(items, (item: ChartItem, i: number): void => {
        Column() {
          Blank()
            .height(this.getTopSpacerHeight(item.height))

          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width(item.index === this.selectedIndex ? 11 : 9)
              .height(item.index === this.selectedIndex ? 11 : 9)
              .borderRadius(item.index === this.selectedIndex ? 6 : 5)
              .backgroundColor(this.pointFillColor)
              .border({ width: 2, color: item.index === this.selectedIndex ? this.bubbleColor : this.lineColor })
          }
            .width(16)
            .height(16)
            .onClick((): void => {
              this.selectItem(item.index);
            })
            .onTouch((event: TouchEvent): void => {
              this.handleChartTouch(event);
              if (event.type === TouchType.Down) {
                this.selectItem(item.index);
              }
            })

          Column()
            .width(2)
            .height(this.getStemHeight(item.height))
            .borderRadius(2)
            .backgroundColor(Color.Transparent)
            .opacity(0)
        }
        .width(this.pointSize)
        .height(this.plotHeight)
        .alignItems(HorizontalAlign.Center)
        .position({ x: this.getPointCenterX(item) - this.pointSize / 2, y: 0 })
        .onClick((): void => {
          this.selectItem(item.index);
        })
        .onTouch((event: TouchEvent): void => {
          this.handleChartTouch(event);
          if (event.type === TouchType.Down) {
            this.selectItem(item.index);
          }
        })
      }, (item: ChartItem): string => this.getChartStateKey() + '-point-' + item.index.toString())
    }
    .width(this.getPlotContentWidth(items))
    .height(this.plotHeight)
    .onTouch((event: TouchEvent): void => {
      this.handleChartTouch(event);
    })
  }

  @Builder
  private buildPointValueLabels(items: ChartItem[]) {
    Stack({ alignContent: Alignment.Start }) {
      ForEach(items, (item: ChartItem): void => {
        if (this.shouldShowPointValue(item)) {
          Text(this.formatMinuteValue(item.value))
            .fontSize(12)
            .fontColor(this.textSecondary)
            .width(this.xLabelWidth)
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .position({
              x: this.getPointCenterX(item) - this.xLabelWidth / 2,
              y: Math.max(0, this.getPointCenterY(item) - 24)
            })
        }
      }, (item: ChartItem): string => this.getChartStateKey() + '-label-' + item.index.toString())
    }
    .width(this.getPlotContentWidth(items))
    .height(this.plotHeight)
  }

  @Builder
  private buildSelectedBubble(items: ChartItem[]) {
    Stack({ alignContent: Alignment.Start }) {}
    .width(this.getPlotContentWidth(items))
    .height(this.plotHeight)
  }

  @Builder
  private buildSelectedGuide(items: ChartItem[]) {
    Stack({ alignContent: Alignment.Start }) {
      ForEach(items, (item: ChartItem): void => {
        if (this.shouldShowSelectedGuide(item, items)) {
          Stack({ alignContent: Alignment.Start }) {
            ForEach(this.getGuideDashOffsets(item), (offset: number): void => {
              Column()
                .width(2)
                .height(this.getGuideDashHeight(item, offset))
                .borderRadius(1)
                .backgroundColor(this.bubbleColor)
                .opacity(0.62)
                .position({ x: 0, y: offset })
            }, (offset: number): string => this.getChartStateKey() + '-guide-dash-' + item.index.toString() + '-' + offset.toString())
          }
          .width(2)
          .height(this.getGuideHeight(item))
          .position({ x: this.getGuideX(item), y: this.getGuideY(item) })
        }
      }, (item: ChartItem): string => this.getChartStateKey() + '-guide-' + item.index.toString())
    }
    .width(this.getPlotContentWidth(items))
    .height(this.plotHeight)
  }

  @Builder
  private buildXAxis(items: ChartItem[]) {
    Stack({ alignContent: Alignment.Start }) {
      ForEach(items, (item: ChartItem, i: number): void => {
        Text(this.shouldShowLabel(i, items.length) ? item.label : ' ')
          .fontSize(11)
          .fontColor(this.textSecondary)
          .width(this.xLabelWidth)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .position({ x: this.getPointCenterX(item) - this.xLabelWidth / 2, y: 6 })
      }, (item: ChartItem): string => this.getChartStateKey() + '-x-' + item.index.toString())
    }
    .width(this.getPlotContentWidth(items))
    .height(30)
  }

  @Builder
  private buildComponentChart() {
    if (this.shouldUseNativeHorizontalScroll()) {
      this.buildScrollableComponentChart()
    } else {
      this.buildWindowComponentChart()
    }
  }

  @Builder
  private buildWindowComponentChart() {
    this.buildWindowComponentChartItems(this.getVisibleItems())
  }

  @Builder
  private buildWindowComponentChartItems(items: ChartItem[]) {
    Column() {
      Row() {
        Blank()

        Column() {
        Stack({ alignContent: Alignment.Start }) {
          this.buildAxisGrid(items)

            Stack({ alignContent: Alignment.Start }) {
              this.buildPlotGridLines(items)
              this.buildAreaGradient(items)
              this.buildLineSegments(items)
              this.buildSelectedGuide(items)
              this.buildPointValueLabels(items)
              this.buildPointSeries(items)
              this.buildSelectedBubble(items)
            }
            .width(this.getPlotContentWidth(items))
            .height(this.plotHeight)
            .position({ x: this.getPlotOffsetX(), y: 0 })
            .onTouch((event: TouchEvent): void => {
              this.handleChartTouch(event);
            })
            .priorityGesture(
              PanGesture({ direction: PanDirection.Horizontal, distance: 2 })
                .onActionStart((): void => {
                  this.handlePanStart();
                })
                .onActionUpdate((event: GestureEvent): void => {
                  this.handlePanUpdate(event);
                })
                .onActionEnd((): void => {
                  this.handlePanEnd();
                }),
              GestureMask.IgnoreInternal
            )
        }
        .width(this.getChartContentWidth(items))
        .height(this.plotHeight)

        Row() {
            Blank()
              .width(this.getPlotOffsetX())
            this.buildXAxis(items)
        }
        .width(this.getChartContentWidth(items))
        .height(30)
        }
        .width(this.getChartContentWidth(items))
        .height(this.chartHeight)

        Blank()
      }
      .width('100%')
      .height(this.chartHeight)
    }
    .width('100%')
    .height(this.chartHeight)
    .translate({ x: -8, y: 0 })
    .onTouch((event: TouchEvent): void => {
      this.handleChartTouch(event);
    })
    .priorityGesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 2 })
        .onActionStart((): void => {
          this.handlePanStart();
        })
        .onActionUpdate((event: GestureEvent): void => {
          this.handlePanUpdate(event);
        })
        .onActionEnd((): void => {
          this.handlePanEnd();
        }),
      GestureMask.IgnoreInternal
    )
  }

  @Builder
  private buildScrollableComponentChart() {
    this.buildScrollableComponentChartItems(this.getAllItems())
  }

  @Builder
  private buildScrollableComponentChartItems(items: ChartItem[]) {
    Column() {
      Row() {
        Blank()

        Column() {
          Row() {
            this.buildYAxisOnly()

            Scroll(this.chartScroller) {
              Column() {
                Stack({ alignContent: Alignment.Start }) {
                  this.buildPlotGridLines(items)
                  this.buildAreaGradient(items)
                  this.buildLineSegments(items)
                  this.buildSelectedGuide(items)
                  this.buildPointValueLabels(items)
                  this.buildPointSeries(items)
                  this.buildSelectedBubble(items)
                }
                .width(this.getPlotContentWidth(items))
                .height(this.plotHeight)

                this.buildXAxis(items)
              }
              .width(this.getPlotContentWidth(items))
              .height(this.chartHeight)
            }
            .width(this.getViewportPlotWidth())
            .height(this.chartHeight)
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .enableScrollInteraction(true)
            .onAppear((): void => {
              this.scrollToDefaultViewport();
            })
          }
          .width(this.getViewportChartContentWidth())
          .height(this.chartHeight)
          .alignItems(VerticalAlign.Top)
        }
        .width(this.getViewportChartContentWidth())
        .height(this.chartHeight)

        Blank()
      }
      .width('100%')
      .height(this.chartHeight)
    }
    .width('100%')
    .height(this.chartHeight)
    .translate({ x: -8, y: 0 })
  }

  build() {
    Column() {
      Row() {
        Row() {
          Image(this.durationTrendIcon())
            .width(20)
            .height(20)
            .objectFit(ImageFit.Contain)
          .width(20)
          .height(20)
          Text('学习时长趋势')
            .fontSize(15)
            .fontWeight(600)
            .fontColor(this.textPrimary)
            .margin({ left: 8 })
        }
        .alignItems(VerticalAlign.Center)

        Blank()
      }
      .width('100%')
      .margin({ bottom: 10 })

      if (this.isLoading) {
        this.buildSkeleton()
      } else if (!this.dailyStats || this.dailyStats.length === 0) {
        this.buildEmptyChart()
      } else {
        this.buildComponentChart()
      }
    }
    .width('100%')
    .padding({ top: 14, right: 16, bottom: 14, left: 16 })
    .backgroundColor(this.darkMode ? '#111827' : Color.White)
    .borderRadius(22)
    .border({ width: 1, color: this.darkMode ? '#334155' : '#E2E8F0' })
    .shadow({ radius: 14, color: 'rgba(15, 23, 42, 0.06)', offsetY: 6 })
    .margin({ top: 16 })
  }
}
