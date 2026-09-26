export interface ImportResult {
  success: boolean;
  bookName: string;
  successCount: number;
  skipCount: number;
  failCount: number;
  message: string;
}

export interface ImportWordItem {
  word: string;
  phonetic: string;
  partOfSpeech?: string;
  pronunciationUrl?: string;
  translation: string;
  example: string;
  difficulty: number;
}
