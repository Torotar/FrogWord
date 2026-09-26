export interface StudySession {
  id: number;
  date: string;       // YYYY-MM-DD
  startTime: number;  // 开始时间戳（ms）
  endTime: number;    // 结束时间戳（ms）
  duration: number;   // 学习时长（秒）
  scene: string;      // 'learn' | 'review'
  wordCount: number;  // 本次学习的单词数
}
