import { relationalStore } from '@kit.ArkData';
import { DateUtil } from '../utils/DateUtil';
import { DatabaseService } from './DatabaseService';

export class StudySessionService {
  private static activeSessionId: number = 0;
  private static activeSessionStart: number = 0;
  private static activeWordCount: number = 0;

  /**
   * 开始一个学习/复习会话，插入一条记录并返回 sessionId（使用 store.insert 确保返回真实 ID）
   */
  public static async startSession(scene: 'learn' | 'review'): Promise<number> {
    const now: number = Date.now();
    const date: string = DateUtil.todayKey();
    const values: relationalStore.ValuesBucket = {
      'date': date,
      'start_time': now,
      'end_time': now,
      'duration': 0,
      'scene': scene,
      'word_count': 0
    };
    try {
      const rowId: number = await DatabaseService.insert('study_session', values);
      StudySessionService.markActiveSession(rowId, now, 0);
      console.info('startSession success scene=' + scene + ', id=' + rowId.toString());
      return rowId;
    } catch (error) {
      console.error('startSession failed: ' + JSON.stringify(error));
      return 0;
    }
  }

  /**
   * 增量更新会话时长：记录到当前时刻的累计秒数
   * 每次答题后调用，确保即使页面异常退出也有时长记录
   */
  public static async updateSessionDuration(sessionId: number, startTime: number): Promise<void> {
    await StudySessionService.updateSessionProgress(sessionId, startTime, -1);
  }

  public static async updateSessionProgress(sessionId: number, startTime: number, wordCount: number): Promise<void> {
    if (sessionId <= 0) {
      return;
    }
    const now: number = Date.now();
    const elapsed: number = Math.max(0, Math.floor((now - startTime) / 1000));
    if (sessionId === StudySessionService.activeSessionId) {
      StudySessionService.activeSessionStart = startTime;
      if (wordCount >= 0) {
        StudySessionService.activeWordCount = wordCount;
      }
    }
    try {
      if (wordCount >= 0) {
        await DatabaseService.executeSql(
          'UPDATE study_session SET end_time = ?, duration = ?, word_count = ? WHERE id = ?',
          [now, elapsed, wordCount, sessionId]
        );
      } else {
        await DatabaseService.executeSql(
          'UPDATE study_session SET end_time = ?, duration = ? WHERE id = ?',
          [now, elapsed, sessionId]
        );
      }
    } catch (error) {
      console.error('updateSessionProgress failed: ' + JSON.stringify(error));
    }
  }

  public static async flushActiveSessionDuration(): Promise<void> {
    if (StudySessionService.activeSessionId <= 0 || StudySessionService.activeSessionStart <= 0) {
      return;
    }
    await StudySessionService.updateSessionProgress(
      StudySessionService.activeSessionId,
      StudySessionService.activeSessionStart,
      StudySessionService.activeWordCount
    );
  }

  /**
   * 结束一个会话：更新结束时间、时长、学习单词数
   */
  public static async endSession(sessionId: number, wordCount: number, startTime: number): Promise<void> {
    if (sessionId <= 0) {
      return;
    }
    const now: number = Date.now();
    const duration: number = Math.max(0, Math.floor((now - startTime) / 1000));
    try {
      await DatabaseService.executeSql(
        'UPDATE study_session SET end_time = ?, duration = ?, word_count = ? WHERE id = ?',
        [now, duration, wordCount, sessionId]
      );
      StudySessionService.clearActiveSession(sessionId);
      console.info('endSession success id=' + sessionId.toString() +
        ', duration=' + duration.toString() + 's, wordCount=' + wordCount.toString());
    } catch (error) {
      console.error('endSession failed: ' + JSON.stringify(error));
    }
  }

  private static markActiveSession(sessionId: number, startTime: number, wordCount: number): void {
    StudySessionService.activeSessionId = sessionId;
    StudySessionService.activeSessionStart = startTime;
    StudySessionService.activeWordCount = wordCount;
  }

  private static clearActiveSession(sessionId: number): void {
    if (sessionId !== StudySessionService.activeSessionId) {
      return;
    }
    StudySessionService.activeSessionId = 0;
    StudySessionService.activeSessionStart = 0;
    StudySessionService.activeWordCount = 0;
  }

  /**
   * 获取指定日期范围内的总学习时长（秒）
   */
  public static async getDurationSum(startDate: string, endDate: string): Promise<number> {
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(
        'SELECT IFNULL(SUM(duration),0) AS d FROM study_session WHERE date >= ? AND date <= ?',
        [startDate, endDate]
      );
      if (resultSet.goToFirstRow()) {
        return resultSet.getLong(resultSet.getColumnIndex('d'));
      }
    } catch (error) {
      console.error('getDurationSum failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return 0;
  }

  /**
   * 获取全部总学习时长（秒）
   */
  public static async getTotalDuration(): Promise<number> {
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(
        'SELECT IFNULL(SUM(duration),0) AS d FROM study_session'
      );
      if (resultSet.goToFirstRow()) {
        return resultSet.getLong(resultSet.getColumnIndex('d'));
      }
    } catch (error) {
      console.error('getTotalDuration failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return 0;
  }

  /**
   * 获取最近 N 天的每日学习时长（秒），返回日期→时长的映射
   */
  public static async getDailyDurations(days: number): Promise<Map<string, number>> {
    const result: Map<string, number> = new Map();
    const keys: string[] = DateUtil.recentDateKeys(days);
    for (let i: number = 0; i < keys.length; i++) {
      result.set(keys[i], 0);
    }
    let resultSet: relationalStore.ResultSet | undefined = undefined;
    try {
      resultSet = await DatabaseService.querySql(
        'SELECT date, SUM(duration) AS d FROM study_session WHERE date >= ? GROUP BY date ORDER BY date ASC',
        [keys[0]]
      );
      while (resultSet.goToNextRow()) {
        const date: string = resultSet.getString(resultSet.getColumnIndex('date'));
        const dur: number = resultSet.getLong(resultSet.getColumnIndex('d'));
        result.set(date, dur);
      }
    } catch (error) {
      console.error('getDailyDurations failed: ' + JSON.stringify(error));
    } finally {
      if (resultSet) {
        resultSet.close();
      }
    }
    return result;
  }
}
