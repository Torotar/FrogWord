export class DateUtil {
  public static readonly ONE_DAY_MILLISECONDS: number = 24 * 60 * 60 * 1000;

  public static todayKey(): string {
    return DateUtil.formatDateKey(new Date());
  }

  public static formatDateKey(date: Date): string {
    const year: number = date.getFullYear();
    const month: string = DateUtil.pad(date.getMonth() + 1);
    const day: string = DateUtil.pad(date.getDate());
    return year.toString() + '-' + month + '-' + day;
  }

  public static addDaysTimestamp(days: number): number {
    return Date.now() + days * DateUtil.ONE_DAY_MILLISECONDS;
  }

  public static todayStartTimestamp(): number {
    const date: Date = new Date();
    date.setHours(0, 0, 0, 0);
    return date.getTime();
  }

  public static formatTimestamp(timestamp: number): string {
    if (timestamp <= 0) {
      return '暂无';
    }
    const date: Date = new Date(timestamp);
    return DateUtil.formatDateKey(date) + ' ' + DateUtil.pad(date.getHours()) + ':' + DateUtil.pad(date.getMinutes());
  }

  public static recentDateKeys(days: number): string[] {
    const keys: string[] = [];
    const today: Date = new Date();
    today.setHours(0, 0, 0, 0);
    for (let index: number = days - 1; index >= 0; index--) {
      const date: Date = new Date(today.getTime() - index * DateUtil.ONE_DAY_MILLISECONDS);
      keys.push(DateUtil.formatDateKey(date));
    }
    return keys;
  }

  // ---- 周期计算辅助 ----

  // 当前周期起始日期
  public static periodStartKey(period: string): string {
    const now: Date = new Date();
    if (period === '日') {
      return DateUtil.formatDateKey(now);
    } else if (period === '周') {
      const day: number = now.getDay(); // 0=周日
      const diff: number = day === 0 ? 6 : day - 1; // 距周一
      const monday: Date = new Date(now.getTime() - diff * DateUtil.ONE_DAY_MILLISECONDS);
      return DateUtil.formatDateKey(monday);
    } else if (period === '月') {
      return now.getFullYear().toString() + '-' + DateUtil.pad(now.getMonth() + 1) + '-01';
    } else if (period === '年') {
      return now.getFullYear().toString() + '-01-01';
    }
    return DateUtil.formatDateKey(now);
  }

  // 当前周期结束日期
  public static periodEndKey(period: string): string {
    const now: Date = new Date();
    if (period === '日') {
      return DateUtil.formatDateKey(now);
    } else if (period === '周') {
      const day: number = now.getDay();
      const diff: number = day === 0 ? 0 : 7 - day;
      const sunday: Date = new Date(now.getTime() + diff * DateUtil.ONE_DAY_MILLISECONDS);
      return DateUtil.formatDateKey(sunday);
    } else if (period === '月') {
      const lastDay: number = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
      return now.getFullYear().toString() + '-' + DateUtil.pad(now.getMonth() + 1) + '-' + DateUtil.pad(lastDay);
    } else if (period === '年') {
      return now.getFullYear().toString() + '-12-31';
    }
    return DateUtil.formatDateKey(now);
  }

  // 获取最近 N 个周期的起止日期对（用于图表）
  public static recentPeriodRanges(period: string, count: number): string[][] {
    const ranges: string[][] = [];
    const now: Date = new Date();
    if (period === '日') {
      for (let i: number = count - 1; i >= 0; i--) {
        const d: Date = new Date(now.getTime() - i * DateUtil.ONE_DAY_MILLISECONDS);
        const key: string = DateUtil.formatDateKey(d);
        ranges.push([key, key]);
      }
    } else if (period === '周') {
      for (let i: number = count - 1; i >= 0; i--) {
        const d: Date = new Date(now);
        const dow: number = d.getDay();
        const monDiff: number = dow === 0 ? 6 : dow - 1;
        d.setDate(d.getDate() - monDiff - i * 7);
        const startKey: string = DateUtil.formatDateKey(d);
        d.setDate(d.getDate() + 6);
        const endKey: string = DateUtil.formatDateKey(d);
        ranges.push([startKey, endKey]);
      }
    } else if (period === '月') {
      for (let i: number = count - 1; i >= 0; i--) {
        const d: Date = new Date(now.getFullYear(), now.getMonth() - i, 1);
        const startKey: string = DateUtil.formatDateKey(d);
        const lastDay: number = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
        const endD: Date = new Date(d.getFullYear(), d.getMonth(), lastDay);
        const endKey: string = DateUtil.formatDateKey(endD);
        ranges.push([startKey, endKey]);
      }
    } else if (period === '年') {
      for (let i: number = count - 1; i >= 0; i--) {
        const year: number = now.getFullYear() - i;
        ranges.push([year.toString() + '-01-01', year.toString() + '-12-31']);
      }
    }
    return ranges;
  }

  // 获取某个月份的所有日期（用于日历）
  // 每周以周一为一列，周日为最后一列
  public static monthDays(year: number, month: number): number[] {
    const firstDayOfWeek: number = new Date(year, month - 1, 1).getDay();
    // 将 getDay() (0=周日) 转换为以周一为第一列的偏移：(day + 6) % 7
    // 周一→0, 周二→1, ..., 周六→5, 周日→6
    const firstCol: number = (firstDayOfWeek + 6) % 7;
    const daysInMonth: number = new Date(year, month, 0).getDate();
    const days: number[] = [];
    // 填充前导空白（0 表示空白）
    for (let i: number = 0; i < firstCol; i++) {
      days.push(0);
    }
    for (let d: number = 1; d <= daysInMonth; d++) {
      days.push(d);
    }
    while (days.length % 7 !== 0) {
      days.push(0);
    }
    return days;
  }

  private static pad(value: number): string {
    return value < 10 ? '0' + value.toString() : value.toString();
  }
}
