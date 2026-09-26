export interface StudyRecord {
  id: number;
  wordId: number;
  correctCount: number;
  wrongCount: number;
  lastReviewTime: number;
  nextReviewTime: number;
  intervalDays: number;
  easeFactor: number;
  mastered: number;
}
