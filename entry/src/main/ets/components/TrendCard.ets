/**
 * TrendCard — 学习时长趋势折线图卡片
 * 使用 Canvas 绘制 + 原生 ArkTS 组件拼装卡片。支持深色模式。
 */

import { StudyDaily } from '../model/StudyStats';

@Component
export struct TrendCard {
  @Prop @Watch('onDataChange') dailyStats: StudyDaily[] = [];
  @Prop isLoading: boolean = false;
  @Prop darkMode: boolean = false;
  @Prop cardTitle: string = '学习时长趋势';
  @Prop cardBackground: string = '';
  @Prop textPrimary: string = '';

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  // ── 颜色（深色模式自适应） ──
  private get bgColor(): string { return this.cardBackground || (this.darkMode ? '#111827' : '#FFFFFF'); }
  private get titleColor(): string { return this.textPrimary || (this.darkMode ? '#F8FAFC' : '#333333'); }
  private get labelColor(): string { return this.darkMode ? '#94A3B8' : '#999999'; }
  private get axisColor(): string { return this.darkMode ? '#334155' : '#E8E8E8'; }
  private get gridColor(): string { return this.darkMode ? '#334155' : '#F0F0F0'; }
  private get skeletonColor(): string { return this.darkMode ? '#2A2A3E' : '#E8E4F0'; }
  private get dotFillColor(): string { return this.darkMode ? '#111827' : '#FFFFFF'; }
  private readonly lineColor: string = '#B39DDB';
  private readonly areaTop: string = 'rgba(179,157,219,0.25)';
  private readonly areaBottom: string = 'rgba(179,157,219,0.02)';
  private readonly dotStroke: string = '#B39DDB';

  // ── 布局 ──
  private readonly L = 36; private readonly R = 16;
  private readonly T = 20; private readonly B = 30;
  private readonly CH = 160;
  private dw(w: number): number { return Math.max(w - this.L - this.R, 10); }
  private get dh(): number { return this.CH - this.T - this.B; }

  private fmtDate(s: string): string {
    const p: string[] = s.split('-');
    if (p.length >= 3) return parseInt(p[1]) + '/' + parseInt(p[2]);
    return s;
  }

  private get minutes(): number[] {
    if (!this.dailyStats) return [];
    return this.dailyStats.map((d: StudyDaily): number => Math.floor(d.duration / 60));
  }

  private onDataChange(): void {
    this.drawChart();
  }

  private drawChart(): void {
    const ctx = this.ctx;
    const W = ctx.width;
    const H = ctx.height;
    ctx.clearRect(0, 0, W, H);

    const vals = this.minutes || [];
    const stats = this.dailyStats || [];

    if (!vals.length || !stats.length) {
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.font = '14px sans-serif'; ctx.fillStyle = this.labelColor;
      ctx.fillText('暂无学习数据', W / 2, H / 2);
      return;
    }

    const dw = this.dw(W);
    const dh = this.dh;
    const last = vals.length - 1;
    const xp = (i: number): number => this.L + (i / Math.max(last, 1)) * dw;
    const yp = (v: number): number => this.T + dh - (v / 50) * dh;

    // 网格 + Y轴
    ctx.textAlign = 'right'; ctx.textBaseline = 'middle'; ctx.font = '12px sans-serif';
    for (let i = 0; i <= 50; i += 10) {
      const y = yp(i);
      if (i > 0) {
        ctx.beginPath(); ctx.setLineDash([3, 3]);
        ctx.moveTo(this.L, y); ctx.lineTo(W - this.R, y);
        ctx.strokeStyle = this.gridColor; ctx.lineWidth = 1; ctx.stroke(); ctx.setLineDash([]);
      }
      ctx.fillStyle = this.labelColor;
      ctx.fillText(i.toString(), this.L - 6, y);
    }
    ctx.font = '11px sans-serif'; ctx.textAlign = 'left'; ctx.textBaseline = 'bottom';
    ctx.fillStyle = this.labelColor;
    ctx.fillText('学习时长（分钟）', this.L, this.T - 4);

    // X轴
    ctx.textAlign = 'center'; ctx.textBaseline = 'top'; ctx.font = '12px sans-serif';
    ctx.fillStyle = this.labelColor;
    for (let i = 0; i <= last; i++) ctx.fillText(this.fmtDate(stats[i].date), xp(i), this.T + dh + 6);

    // 坐标轴
    ctx.beginPath(); ctx.setLineDash([]);
    ctx.strokeStyle = this.axisColor; ctx.lineWidth = 1;
    ctx.moveTo(this.L, this.T + dh); ctx.lineTo(W - this.R, this.T + dh);
    ctx.moveTo(this.L, this.T); ctx.lineTo(this.L, this.T + dh);
    ctx.stroke();

    // 面积 + 折线
    if (vals.length >= 2) {
      const g = ctx.createLinearGradient(0, this.T, 0, this.T + dh);
      g.addColorStop(0, this.areaTop); g.addColorStop(1, this.areaBottom);
      ctx.beginPath(); ctx.moveTo(xp(0), yp(vals[0]));
      for (let i = 1; i < vals.length; i++) {
        ctx.bezierCurveTo(xp(i - 1) + (xp(i) - xp(i - 1)) / 2, yp(vals[i - 1]),
          xp(i) - (xp(i) - xp(i - 1)) / 2, yp(vals[i]), xp(i), yp(vals[i]));
      }
      ctx.lineTo(xp(last), this.T + dh); ctx.lineTo(xp(0), this.T + dh); ctx.closePath();
      ctx.fillStyle = g; ctx.fill();

      ctx.beginPath(); ctx.moveTo(xp(0), yp(vals[0]));
      for (let i = 1; i < vals.length; i++) {
        ctx.bezierCurveTo(xp(i - 1) + (xp(i) - xp(i - 1)) / 2, yp(vals[i - 1]),
          xp(i) - (xp(i) - xp(i - 1)) / 2, yp(vals[i]), xp(i), yp(vals[i]));
      }
      ctx.strokeStyle = this.lineColor; ctx.lineWidth = 2.5; ctx.lineCap = 'round'; ctx.stroke();
    }

    // 数据点
    for (let i = 0; i < vals.length; i++) {
      ctx.beginPath(); ctx.arc(xp(i), yp(vals[i]), 3.5, 0, Math.PI * 2);
      ctx.fillStyle = this.dotFillColor; ctx.fill();
      ctx.strokeStyle = this.dotStroke; ctx.lineWidth = 2; ctx.stroke();
    }
  }

  @Builder
  private buildSkeleton() {
    Column() {
      ForEach([0, 1, 2, 3], (): void => {
        Row() {
          Column().width(28).height(8).borderRadius(4).backgroundColor(this.skeletonColor)
          Blank()
        }.width('100%').height(28).alignItems(VerticalAlign.Center)
      }, (_: number, i: number): string => i.toString())
    }.opacity(0.5).padding({ left: this.L, right: this.R }).width('100%').height(this.CH)
  }

  build() {
    Column() {
      Text(this.cardTitle).fontSize(15).fontWeight(600).fontColor(this.titleColor).width('100%')

      if (this.isLoading) {
        this.buildSkeleton()
      } else {
        Canvas(this.ctx)
          .width('100%').height(this.CH)
          .onReady((): void => { this.drawChart(); })
      }
    }
    .width('100%')
    .padding({ top: 14, right: 16, bottom: 14, left: 16 })
    .backgroundColor(this.bgColor).borderRadius(8)
    .shadow({ radius: 4, color: 'rgba(0,0,0,0.06)', offsetY: 1 })
  }
}
