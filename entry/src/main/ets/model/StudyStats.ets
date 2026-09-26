export interface StudyStats {
  todayLearnCount: number;
  todayReviewCount: number;
  todayCorrectCount: number;
  todayWrongCount: number;
  pendingReviewCount: number;
  unknownWordCount: number;   // 学过且答错过（wrong_count > 0）
  masteredCount: number;
  totalWordCount: number;
  unmasteredCount: number;   // 所有未掌握（含未学过的）
  inLearningCount: number;   // 学过但未答错过（mastered=0 AND wrong_count=0）
  totalCorrectCount: number;
  totalWrongCount: number;
  accuracyRate: number;
  studyDuration: number; // 学习时长（秒）
}

export interface StudyDaily {
  date: string;
  learnCount: number;
  reviewCount: number;
  correctCount: number;
  wrongCount: number;
  duration: number; // 学习时长（秒）
}
