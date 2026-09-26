export interface Word {
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
}
