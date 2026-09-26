export interface DueReviewWord {
  id: number;
  word: string;
  phonetic: string;
  partOfSpeech?: string;
  pronunciationUrl?: string;
  translation: string;
  example: string;
  bookId: number;
  difficulty: number;
  createdAt: number;
  /** 上次复习时间戳 */
  lastReviewTime: number;
  /** 下次复习时间戳 */
  nextReviewTime: number;
  /** 正确次数 */
  correctCount: number;
  /** 错误次数 */
  wrongCount: number;
  /** 当前复习间隔天数 */
  intervalDays: number;
  /** 当前记忆稳定系数 */
  easeFactor: number;
  /** 是否已掌握 (0/1) */
  mastered: number;
}
