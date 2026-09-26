export interface DictionaryExample {
  sentence: string;
  translation: string;
  source?: string;
  audioUrl?: string;
}

export interface DictionaryDefinition {
  definition: string;
  translation: string;
  pronunciationUrl?: string;
}

export interface DictionaryPhrase {
  phrase: string;
  translation: string;
}

export interface DictionaryNetworkDefinition {
  term: string;
  summary: string;
}

export interface DictionarySpecialDefinition {
  major: string;
  terms: string[];
}

export interface DictionaryEnglishDefinition {
  partOfSpeech: string;
  definition: string;
}

export interface DictionaryLookupResult {
  success: boolean;
  sourceName: string;
  query: string;
  word: string;
  phonetic: string;
  partOfSpeech: string;
  audioUrl: string;
  definitionPairs: DictionaryDefinition[];
  definitions: string[];
  translations: string[];
  bilingualExamples: DictionaryExample[];
  mediaExamples: DictionaryExample[];
  authorityExamples: DictionaryExample[];
  networkDefinitions: DictionaryNetworkDefinition[];
  specialDefinitions: DictionarySpecialDefinition[];
  englishDefinitions: DictionaryEnglishDefinition[];
  phrases: DictionaryPhrase[];
  etymology: string;
  suggestions: string[];
  sourceUrl: string;
  message: string;
}
