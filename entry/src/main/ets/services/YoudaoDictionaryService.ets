import { http } from '@kit.NetworkKit';
import {
  DictionaryDefinition,
  DictionaryEnglishDefinition,
  DictionaryExample,
  DictionaryLookupResult,
  DictionaryNetworkDefinition,
  DictionaryPhrase,
  DictionarySpecialDefinition
} from '../model/DictionaryResult';
import { AudioService } from './AudioService';

interface YoudaoSimpleWord {
  usphone?: string;
  ukphone?: string;
  phone?: string;
}

interface YoudaoSimple {
  word?: YoudaoSimpleWord[];
}

interface YoudaoSentence {
  sentOrig?: string;
  sentTrans?: string;
}

interface YoudaoTranslationContent {
  detailPos?: string;
  sents?: YoudaoSentence[];
}

interface YoudaoTranslation {
  trans?: string;
  content?: YoudaoTranslationContent;
}

interface YoudaoExpandedWord {
  pos?: string;
  transList?: YoudaoTranslation[];
}

interface YoudaoExpandedDictionary {
  word?: YoudaoExpandedWord[];
}

interface YoudaoChineseText {
  i?: string[];
}

interface YoudaoChineseTranslation {
  l?: YoudaoChineseText;
}

interface YoudaoChineseTranslationGroup {
  tr?: YoudaoChineseTranslation[];
}

interface YoudaoChineseWord {
  phone?: string;
  trs?: YoudaoChineseTranslationGroup[];
}

interface YoudaoChineseDictionary {
  word?: YoudaoChineseWord[];
}

interface YoudaoLegacyChineseTextObject {
  text?: string;
}

type YoudaoLegacyChineseTextValue = string | YoudaoLegacyChineseTextObject;

interface YoudaoLegacyChineseText {
  i?: string | YoudaoLegacyChineseTextValue[];
  pos?: string;
  translation?: string;
}

interface YoudaoLegacyChineseTranslation {
  l?: YoudaoLegacyChineseText;
}

interface YoudaoLegacyChineseTranslationGroup {
  tr?: YoudaoLegacyChineseTranslation[];
}

interface YoudaoLegacyChineseWord {
  phone?: string;
  trs?: YoudaoLegacyChineseTranslationGroup[];
}

interface YoudaoLegacyChineseDictionary {
  word?: YoudaoLegacyChineseWord[];
}

interface YoudaoWebTranslation {
  value?: string;
  summary?: YoudaoWebTranslationSummary;
}

interface YoudaoWebTranslationSummary {
  line?: string[];
}

interface YoudaoWebTranslationGroup {
  key?: string;
  trans?: YoudaoWebTranslation[];
}

interface YoudaoWebTranslationDictionary {
  webTranslation?: YoudaoWebTranslationGroup[];
}

interface YoudaoPhraseText {
  i?: string;
}

interface YoudaoPhraseValue {
  l?: YoudaoPhraseText;
}

interface YoudaoPhraseTranslation {
  tr?: YoudaoPhraseValue;
}

interface YoudaoPhraseData {
  headword?: YoudaoPhraseValue;
  trs?: YoudaoPhraseTranslation[];
}

interface YoudaoPhraseEntry {
  phr?: YoudaoPhraseData;
}

interface YoudaoPhraseDictionary {
  phrs?: YoudaoPhraseEntry[];
}

interface YoudaoEtymologyItem {
  value?: string;
}

interface YoudaoEtymologyLanguages {
  zh?: YoudaoEtymologyItem[];
}

interface YoudaoEtymologyDictionary {
  etyms?: YoudaoEtymologyLanguages;
}

interface YoudaoBilingualSentence {
  sentence?: string;
  sentenceTranslation?: string;
  sentenceSpeech?: string;
  sentenceTranslationSpeech?: string;
  source?: string;
}

interface YoudaoBilingualSentencePart {
  sentencePair?: YoudaoBilingualSentence[];
}

interface YoudaoMediaSnippet {
  streamUrl?: string;
  source?: string;
  name?: string;
}

interface YoudaoMediaSnippets {
  snippet?: YoudaoMediaSnippet[];
}

interface YoudaoMediaSentence {
  mediaType?: string;
  eng?: string;
  chn?: string;
  snippets?: YoudaoMediaSnippets;
}

interface YoudaoMediaSentencePart {
  sent?: YoudaoMediaSentence[];
}

interface YoudaoAuthoritySentence {
  foreign?: string;
  source?: string;
  speech?: string;
}

interface YoudaoAuthoritySentencePart {
  sent?: YoudaoAuthoritySentence[];
}

interface YoudaoEnglishDefinitionText {
  i?: string;
}

interface YoudaoEnglishDefinition {
  l?: YoudaoEnglishDefinitionText;
}

interface YoudaoEnglishPart {
  pos?: string;
  tr?: YoudaoEnglishDefinition[];
}

interface YoudaoEnglishWord {
  trs?: YoudaoEnglishPart[];
}

interface YoudaoEnglishDictionary {
  word?: YoudaoEnglishWord;
}

interface YoudaoSpecialTranslation {
  nat?: string;
}

interface YoudaoSpecialTranslationGroup {
  tr?: YoudaoSpecialTranslation;
}

interface YoudaoSpecialEntryContent {
  major?: string;
  trs?: YoudaoSpecialTranslationGroup[];
}

interface YoudaoSpecialEntry {
  entry?: YoudaoSpecialEntryContent;
}

interface YoudaoSpecialDictionary {
  entries?: YoudaoSpecialEntry[];
}

interface YoudaoResponse {
  simple?: YoudaoSimple;
  expand_ec?: YoudaoExpandedDictionary;
  ce?: YoudaoLegacyChineseDictionary;
  ce_new?: YoudaoChineseDictionary;
  web_trans?: YoudaoWebTranslationDictionary;
  phrs?: YoudaoPhraseDictionary;
  etym?: YoudaoEtymologyDictionary;
  blng_sents_part?: YoudaoBilingualSentencePart;
  media_sents_part?: YoudaoMediaSentencePart;
  auth_sents_part?: YoudaoAuthoritySentencePart;
  ee?: YoudaoEnglishDictionary;
  special?: YoudaoSpecialDictionary;
}

export class YoudaoDictionaryService {
  private static readonly API_URL: string = 'https://dict.youdao.com/jsonapi?q=';
  private static readonly RESULT_URL: string = 'https://dict.youdao.com/result?word=';
  private static readonly MAX_TRANSLATIONS: number = 8;
  private static readonly MAX_EXAMPLES: number = 5;
  private static readonly MAX_SPECIAL_MAJORS: number = 4;
  private static readonly MAX_SPECIAL_TERMS_PER_MAJOR: number = 3;
  private static readonly MAX_ENGLISH_DEFINITIONS: number = 8;

  public static async lookup(keyword: string): Promise<DictionaryLookupResult> {
    const query: string = keyword.trim();
    if (query.length === 0) {
      return YoudaoDictionaryService.emptyResult(query, '请输入要查询的单词或中文释义');
    }

    const request = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(
        YoudaoDictionaryService.API_URL + encodeURIComponent(query),
        {
          method: http.RequestMethod.GET,
          header: {
            'User-Agent': 'Mozilla/5.0 WordFlowHarmony',
            'Accept': 'application/json',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8'
          },
          connectTimeout: 30000,
          readTimeout: 30000
        }
      );
      if (response.responseCode < 200 || response.responseCode >= 400) {
        console.error('Youdao request failed responseCode=' + response.responseCode.toString());
        return YoudaoDictionaryService.emptyResult(query, '有道词典查询失败，请检查网络');
      }
      return YoudaoDictionaryService.parseResponse(query, String(response.result));
    } catch (error) {
      console.error('Youdao lookup failed: ' + JSON.stringify(error));
      return YoudaoDictionaryService.emptyResult(query, '有道词典查询失败，请检查网络');
    } finally {
      request.destroy();
    }
  }

  private static parseResponse(query: string, responseText: string): DictionaryLookupResult {
    try {
      // ArkTS does not allow indexed access to the upstream "web-translation" field.
      const normalizedResponseText: string = responseText
        .replace(/"web-translation"\s*:/g, '"webTranslation":')
        .replace(/"#text"\s*:/g, '"text":')
        .replace(/"#tran"\s*:/g, '"translation":')
        .replace(/"sentence-pair"\s*:/g, '"sentencePair":')
        .replace(/"sentence-translation"\s*:/g, '"sentenceTranslation":')
        .replace(/"sentence-speech"\s*:/g, '"sentenceSpeech":')
        .replace(/"sentence-translation-speech"\s*:/g, '"sentenceTranslationSpeech":')
        .replace(/"@mediatype"\s*:/g, '"mediaType":');
      const response: YoudaoResponse = JSON.parse(normalizedResponseText) as YoudaoResponse;
      const translations: string[] = [];
      const definitionPairs: DictionaryDefinition[] = [];
      const fallbackBilingualExamples: DictionaryExample[] = [];
      const bilingualExamples: DictionaryExample[] = [];
      const mediaExamples: DictionaryExample[] = [];
      const authorityExamples: DictionaryExample[] = [];
      const partsOfSpeech: string[] = [];
      const networkDefinitions: DictionaryNetworkDefinition[] =
        YoudaoDictionaryService.collectNetworkDefinitions(response.web_trans);
      const specialDefinitions: DictionarySpecialDefinition[] =
        YoudaoDictionaryService.collectSpecialDefinitions(response.special);
      const englishDefinitions: DictionaryEnglishDefinition[] =
        YoudaoDictionaryService.collectEnglishDefinitions(response.ee);
      const phrases: DictionaryPhrase[] = YoudaoDictionaryService.collectPhrases(response.phrs);
      YoudaoDictionaryService.collectWebPhrases(response.web_trans, query, phrases);
      const etymology: string = YoudaoDictionaryService.readEtymology(response.etym);
      YoudaoDictionaryService.collectExpandedEntries(
        response.expand_ec, translations, definitionPairs, fallbackBilingualExamples, partsOfSpeech);
      YoudaoDictionaryService.collectChineseEntries(response.ce_new, translations, definitionPairs);
      YoudaoDictionaryService.collectLegacyChineseEntries(
        response.ce, translations, definitionPairs, YoudaoDictionaryService.containsChinese(query));
      const isChineseQuery: boolean = YoudaoDictionaryService.containsChinese(query);
      YoudaoDictionaryService.collectBilingualExamples(
        response.blng_sents_part, bilingualExamples, isChineseQuery);
      if (bilingualExamples.length === 0) {
        YoudaoDictionaryService.copyExamples(fallbackBilingualExamples, bilingualExamples);
      }
      YoudaoDictionaryService.collectMediaExamples(response.media_sents_part, mediaExamples);
      YoudaoDictionaryService.collectAuthorityExamples(response.auth_sents_part, authorityExamples);

      const phonetic: string = YoudaoDictionaryService.readPhonetic(response.simple, response.ce_new, response.ce);
      const success: boolean = translations.length > 0 || bilingualExamples.length > 0 ||
        mediaExamples.length > 0 || authorityExamples.length > 0 ||
        networkDefinitions.length > 0 || specialDefinitions.length > 0 || englishDefinitions.length > 0 ||
        phrases.length > 0 || etymology.length > 0;
      if (!success) {
        return YoudaoDictionaryService.emptyResult(query, '有道词典未找到相关结果');
      }

      return {
        success: true,
        sourceName: '有道词典',
        query: query,
        word: query,
        phonetic: phonetic.length > 0 ? '/' + phonetic + '/' : '',
        partOfSpeech: partsOfSpeech.join(' / '),
        audioUrl: isChineseQuery ? '' :
          AudioService.buildYoudaoPronunciationUrl(query, 2),
        definitionPairs: definitionPairs,
        definitions: [],
        translations: translations,
        bilingualExamples: bilingualExamples,
        mediaExamples: mediaExamples,
        authorityExamples: authorityExamples,
        networkDefinitions: networkDefinitions,
        specialDefinitions: specialDefinitions,
        englishDefinitions: englishDefinitions,
        phrases: phrases,
        etymology: etymology,
        suggestions: [],
        sourceUrl: YoudaoDictionaryService.RESULT_URL + encodeURIComponent(query) +
          (YoudaoDictionaryService.containsChinese(query) ? '&lang=zh-CHS' : '&lang=en'),
        message: ''
      };
    } catch (error) {
      console.error('Youdao parseResponse failed: ' + JSON.stringify(error));
      return YoudaoDictionaryService.emptyResult(query, '有道词典返回内容无法解析');
    }
  }

  private static collectExpandedEntries(dictionary: YoudaoExpandedDictionary | undefined,
    translations: string[], definitionPairs: DictionaryDefinition[], examples: DictionaryExample[],
    partsOfSpeech: string[]): void {
    if (!dictionary || !dictionary.word) {
      return;
    }
    for (let wordIndex: number = 0; wordIndex < dictionary.word.length; wordIndex++) {
      const word: YoudaoExpandedWord = dictionary.word[wordIndex];
      const partOfSpeech: string = YoudaoDictionaryService.cleanText(word.pos);
      YoudaoDictionaryService.pushUnique(partsOfSpeech, partOfSpeech, 6);
      if (!word.transList) {
        continue;
      }
      for (let transIndex: number = 0; transIndex < word.transList.length; transIndex++) {
        const translationItem: YoudaoTranslation = word.transList[transIndex];
        const translation: string = YoudaoDictionaryService.cleanText(translationItem.trans);
        if (translation.length > 0 && translations.length < YoudaoDictionaryService.MAX_TRANSLATIONS) {
          const displayTranslation: string = partOfSpeech.length > 0 ? partOfSpeech + ' ' + translation : translation;
          if (YoudaoDictionaryService.pushUnique(
            translations, displayTranslation, YoudaoDictionaryService.MAX_TRANSLATIONS)) {
            definitionPairs.push({ definition: '', translation: displayTranslation });
          }
        }
        YoudaoDictionaryService.collectExamples(translationItem.content, examples);
      }
    }
  }

  private static collectChineseEntries(dictionary: YoudaoChineseDictionary | undefined,
    translations: string[], definitionPairs: DictionaryDefinition[]): void {
    if (!dictionary || !dictionary.word) {
      return;
    }
    for (let wordIndex: number = 0; wordIndex < dictionary.word.length; wordIndex++) {
      const word: YoudaoChineseWord = dictionary.word[wordIndex];
      if (!word.trs) {
        continue;
      }
      for (let groupIndex: number = 0; groupIndex < word.trs.length; groupIndex++) {
        const group: YoudaoChineseTranslationGroup = word.trs[groupIndex];
        if (!group.tr) {
          continue;
        }
        for (let translationIndex: number = 0; translationIndex < group.tr.length; translationIndex++) {
          const translation: YoudaoChineseTranslation = group.tr[translationIndex];
          if (!translation.l || !translation.l.i) {
            continue;
          }
          for (let textIndex: number = 0; textIndex < translation.l.i.length; textIndex++) {
            const text: string = YoudaoDictionaryService.cleanText(translation.l.i[textIndex]);
            if (YoudaoDictionaryService.pushUnique(
              translations, text, YoudaoDictionaryService.MAX_TRANSLATIONS)) {
              definitionPairs.push({ definition: '', translation: text });
            }
          }
        }
      }
    }
  }

  private static collectLegacyChineseEntries(dictionary: YoudaoLegacyChineseDictionary | undefined,
    translations: string[], definitionPairs: DictionaryDefinition[], isChineseQuery: boolean): void {
    if (!dictionary || !dictionary.word) {
      return;
    }
    for (let wordIndex: number = 0; wordIndex < dictionary.word.length; wordIndex++) {
      const word: YoudaoLegacyChineseWord = dictionary.word[wordIndex];
      if (!word.trs) {
        continue;
      }
      for (let groupIndex: number = 0; groupIndex < word.trs.length; groupIndex++) {
        const group: YoudaoLegacyChineseTranslationGroup = word.trs[groupIndex];
        if (!group.tr) {
          continue;
        }
        for (let translationIndex: number = 0; translationIndex < group.tr.length; translationIndex++) {
          const content: YoudaoLegacyChineseText | undefined = group.tr[translationIndex].l;
          const headword: string = YoudaoDictionaryService.readLegacyChineseText(content);
          const explanation: string = YoudaoDictionaryService.cleanText(content?.translation);
          if (YoudaoDictionaryService.pushUnique(
            translations, headword, YoudaoDictionaryService.MAX_TRANSLATIONS)) {
            definitionPairs.push({
              definition: explanation,
              translation: headword,
              pronunciationUrl: isChineseQuery && YoudaoDictionaryService.isEnglishPronounceable(headword)
                ? AudioService.buildYoudaoPronunciationUrl(headword, 2) : ''
            });
          }
        }
      }
    }
  }

  private static readLegacyChineseText(content: YoudaoLegacyChineseText | undefined): string {
    if (!content || !content.i) {
      return '';
    }
    if (typeof content.i === 'string') {
      return YoudaoDictionaryService.cleanText(content.i);
    }
    let text: string = '';
    for (let index: number = 0; index < content.i.length; index++) {
      const item: YoudaoLegacyChineseTextValue = content.i[index];
      if (typeof item === 'string') {
        text += item;
      } else {
        text += YoudaoDictionaryService.cleanText(item.text);
      }
    }
    return YoudaoDictionaryService.cleanText(text);
  }

  private static collectExamples(content: YoudaoTranslationContent | undefined,
    examples: DictionaryExample[]): void {
    if (!content || !content.sents || examples.length >= YoudaoDictionaryService.MAX_EXAMPLES) {
      return;
    }
    for (let index: number = 0; index < content.sents.length; index++) {
      if (examples.length >= YoudaoDictionaryService.MAX_EXAMPLES) {
        return;
      }
      const sentence: string = YoudaoDictionaryService.cleanText(content.sents[index].sentOrig);
      const translation: string = YoudaoDictionaryService.cleanText(content.sents[index].sentTrans);
      if (sentence.length > 0 && !YoudaoDictionaryService.containsExample(examples, sentence)) {
        examples.push({ sentence: sentence, translation: translation });
      }
    }
  }

  private static collectBilingualExamples(dictionary: YoudaoBilingualSentencePart | undefined,
    examples: DictionaryExample[], isChineseQuery: boolean): void {
    if (!dictionary || !dictionary.sentencePair || examples.length >= YoudaoDictionaryService.MAX_EXAMPLES) {
      return;
    }
    for (let index: number = 0; index < dictionary.sentencePair.length; index++) {
      if (examples.length >= YoudaoDictionaryService.MAX_EXAMPLES) {
        return;
      }
      const item: YoudaoBilingualSentence = dictionary.sentencePair[index];
      const sentence: string = YoudaoDictionaryService.cleanText(
        isChineseQuery ? item.sentenceTranslation : item.sentence);
      const translation: string = YoudaoDictionaryService.cleanText(
        isChineseQuery ? item.sentence : item.sentenceTranslation);
      if (sentence.length > 0 && !YoudaoDictionaryService.containsExample(examples, sentence)) {
        examples.push({
          sentence: sentence,
          translation: translation,
          source: YoudaoDictionaryService.cleanText(item.source),
          audioUrl: YoudaoDictionaryService.buildSentenceAudioUrl(
            isChineseQuery ? item.sentenceTranslationSpeech : item.sentenceSpeech)
        });
      }
    }
  }

  private static collectMediaExamples(dictionary: YoudaoMediaSentencePart | undefined,
    examples: DictionaryExample[]): void {
    if (!dictionary || !dictionary.sent) {
      return;
    }
    for (let index: number = 0;
      index < dictionary.sent.length && examples.length < YoudaoDictionaryService.MAX_EXAMPLES;
      index++) {
      const item: YoudaoMediaSentence = dictionary.sent[index];
      const sentence: string = YoudaoDictionaryService.cleanText(item.eng);
      if (sentence.length === 0 || YoudaoDictionaryService.containsExample(examples, sentence)) {
        continue;
      }
      const snippet: YoudaoMediaSnippet | undefined = YoudaoDictionaryService.firstMediaSnippet(item.snippets);
      const mediaType: string = YoudaoDictionaryService.cleanText(item.mediaType).toLowerCase();
      examples.push({
        sentence: sentence,
        translation: YoudaoDictionaryService.cleanText(item.chn),
        source: YoudaoDictionaryService.buildMediaSource(snippet),
        audioUrl: mediaType === 'audio' ? YoudaoDictionaryService.cleanText(snippet?.streamUrl) : ''
      });
    }
  }

  private static collectAuthorityExamples(dictionary: YoudaoAuthoritySentencePart | undefined,
    examples: DictionaryExample[]): void {
    if (!dictionary || !dictionary.sent) {
      return;
    }
    for (let index: number = 0;
      index < dictionary.sent.length && examples.length < YoudaoDictionaryService.MAX_EXAMPLES;
      index++) {
      const item: YoudaoAuthoritySentence = dictionary.sent[index];
      const sentence: string = YoudaoDictionaryService.cleanText(item.foreign);
      if (sentence.length > 0 && !YoudaoDictionaryService.containsExample(examples, sentence)) {
        examples.push({
          sentence: sentence,
          translation: '',
          source: YoudaoDictionaryService.cleanText(item.source),
          audioUrl: YoudaoDictionaryService.buildSentenceAudioUrl(item.speech)
        });
      }
    }
  }

  private static firstMediaSnippet(snippets: YoudaoMediaSnippets | undefined): YoudaoMediaSnippet | undefined {
    if (!snippets || !snippets.snippet || snippets.snippet.length === 0) {
      return undefined;
    }
    return snippets.snippet[0];
  }

  private static buildMediaSource(snippet: YoudaoMediaSnippet | undefined): string {
    const source: string = YoudaoDictionaryService.cleanText(snippet?.source);
    const name: string = YoudaoDictionaryService.cleanText(snippet?.name);
    if (source.length > 0 && name.length > 0) {
      return source + '：' + name;
    }
    return source.length > 0 ? source : name;
  }

  private static buildSentenceAudioUrl(audioKey?: string): string {
    const key: string = YoudaoDictionaryService.cleanText(audioKey);
    return key.length > 0 ? 'https://dict.youdao.com/dictvoice?audio=' + key : '';
  }

  private static copyExamples(source: DictionaryExample[], target: DictionaryExample[]): void {
    for (let index: number = 0;
      index < source.length && target.length < YoudaoDictionaryService.MAX_EXAMPLES;
      index++) {
      if (!YoudaoDictionaryService.containsExample(target, source[index].sentence)) {
        target.push(source[index]);
      }
    }
  }

  private static collectNetworkDefinitions(dictionary: YoudaoWebTranslationDictionary | undefined):
    DictionaryNetworkDefinition[] {
    const result: DictionaryNetworkDefinition[] = [];
    if (!dictionary || !dictionary.webTranslation) {
      return result;
    }
    const groups: YoudaoWebTranslationGroup[] = dictionary.webTranslation;
    for (let groupIndex: number = 0; groupIndex < groups.length; groupIndex++) {
      const group: YoudaoWebTranslationGroup = groups[groupIndex];
      if (!group.trans) {
        continue;
      }
      for (let translationIndex: number = 0; translationIndex < group.trans.length; translationIndex++) {
        const translation: YoudaoWebTranslation = group.trans[translationIndex];
        const term: string = YoudaoDictionaryService.cleanText(translation.value);
        const summary: string = YoudaoDictionaryService.readWebSummary(translation.summary);
        if (term.length > 0 && !YoudaoDictionaryService.containsNetworkDefinition(result, term)) {
          result.push({
            term: term,
            summary: summary
          });
        }
        if (result.length >= 2) {
          return result;
        }
      }
    }
    return result;
  }

  private static collectSpecialDefinitions(dictionary: YoudaoSpecialDictionary | undefined):
    DictionarySpecialDefinition[] {
    const result: DictionarySpecialDefinition[] = [];
    if (!dictionary || !dictionary.entries) {
      return result;
    }
    for (let entryIndex: number = 0;
      entryIndex < dictionary.entries.length && result.length < YoudaoDictionaryService.MAX_SPECIAL_MAJORS;
      entryIndex++) {
      const entry: YoudaoSpecialEntryContent | undefined = dictionary.entries[entryIndex].entry;
      const major: string = YoudaoDictionaryService.cleanText(entry?.major);
      if (major.length === 0 || !entry?.trs) {
        continue;
      }
      const terms: string[] = [];
      for (let translationIndex: number = 0;
        translationIndex < entry.trs.length && terms.length < YoudaoDictionaryService.MAX_SPECIAL_TERMS_PER_MAJOR;
        translationIndex++) {
        const term: string = YoudaoDictionaryService.cleanText(entry.trs[translationIndex].tr?.nat);
        YoudaoDictionaryService.pushUnique(terms, term, YoudaoDictionaryService.MAX_SPECIAL_TERMS_PER_MAJOR);
      }
      if (terms.length > 0) {
        result.push({ major: major, terms: terms });
      }
    }
    return result;
  }

  private static collectEnglishDefinitions(dictionary: YoudaoEnglishDictionary | undefined):
    DictionaryEnglishDefinition[] {
    const result: DictionaryEnglishDefinition[] = [];
    if (!dictionary || !dictionary.word || !dictionary.word.trs) {
      return result;
    }
    for (let partIndex: number = 0;
      partIndex < dictionary.word.trs.length && result.length < YoudaoDictionaryService.MAX_ENGLISH_DEFINITIONS;
      partIndex++) {
      const part: YoudaoEnglishPart = dictionary.word.trs[partIndex];
      const partOfSpeech: string = YoudaoDictionaryService.cleanText(part.pos);
      if (!part.tr) {
        continue;
      }
      for (let definitionIndex: number = 0;
        definitionIndex < part.tr.length && result.length < YoudaoDictionaryService.MAX_ENGLISH_DEFINITIONS;
        definitionIndex++) {
        const definition: string = YoudaoDictionaryService.cleanText(part.tr[definitionIndex].l?.i);
        if (definition.length > 0 && !YoudaoDictionaryService.containsEnglishDefinition(result, definition)) {
          result.push({ partOfSpeech: partOfSpeech, definition: definition });
        }
      }
    }
    return result;
  }

  private static readWebSummary(summary: YoudaoWebTranslationSummary | undefined): string {
    if (!summary || !summary.line) {
      return '';
    }
    return YoudaoDictionaryService.cleanText(summary.line.join(' '));
  }

  private static collectPhrases(dictionary: YoudaoPhraseDictionary | undefined): DictionaryPhrase[] {
    const result: DictionaryPhrase[] = [];
    if (!dictionary || !dictionary.phrs) {
      return result;
    }
    for (let index: number = 0; index < dictionary.phrs.length; index++) {
      if (result.length >= 3) {
        return result;
      }
      const phraseData: YoudaoPhraseData | undefined = dictionary.phrs[index].phr;
      if (!phraseData || !phraseData.headword || !phraseData.headword.l) {
        continue;
      }
      const phrase: string = YoudaoDictionaryService.cleanText(phraseData.headword.l.i);
      let translation: string = '';
      if (phraseData.trs && phraseData.trs.length > 0 && phraseData.trs[0].tr && phraseData.trs[0].tr?.l) {
        translation = YoudaoDictionaryService.cleanText(phraseData.trs[0].tr?.l?.i);
      }
      if (phrase.length > 0 && !YoudaoDictionaryService.containsPhrase(result, phrase)) {
        result.push({ phrase: phrase, translation: translation });
      }
    }
    return result;
  }

  private static collectWebPhrases(dictionary: YoudaoWebTranslationDictionary | undefined, query: string,
    phrases: DictionaryPhrase[]): void {
    if (!dictionary || !dictionary.webTranslation || phrases.length >= 3) {
      return;
    }
    for (let groupIndex: number = 0; groupIndex < dictionary.webTranslation.length; groupIndex++) {
      if (phrases.length >= 3) {
        return;
      }
      const group: YoudaoWebTranslationGroup = dictionary.webTranslation[groupIndex];
      const phrase: string = YoudaoDictionaryService.cleanText(group.key);
      if (phrase.length === 0 || phrase === query || !group.trans ||
        YoudaoDictionaryService.containsPhrase(phrases, phrase)) {
        continue;
      }
      const values: string[] = [];
      for (let translationIndex: number = 0; translationIndex < group.trans.length; translationIndex++) {
        YoudaoDictionaryService.pushUnique(
          values, YoudaoDictionaryService.cleanText(group.trans[translationIndex].value), 3);
      }
      phrases.push({ phrase: phrase, translation: values.join('; ') });
    }
  }

  private static readEtymology(dictionary: YoudaoEtymologyDictionary | undefined): string {
    if (!dictionary || !dictionary.etyms || !dictionary.etyms.zh || dictionary.etyms.zh.length === 0) {
      return '';
    }
    return YoudaoDictionaryService.cleanText(dictionary.etyms.zh[0].value);
  }

  private static readPhonetic(simple: YoudaoSimple | undefined,
    chineseDictionary: YoudaoChineseDictionary | undefined,
    legacyChineseDictionary: YoudaoLegacyChineseDictionary | undefined): string {
    if (simple && simple.word && simple.word.length > 0) {
      const simpleWord: YoudaoSimpleWord = simple.word[0];
      const simplePhonetic: string = YoudaoDictionaryService.cleanText(
        simpleWord.usphone || simpleWord.ukphone || simpleWord.phone);
      if (simplePhonetic.length > 0) {
        return simplePhonetic;
      }
    }
    if (chineseDictionary && chineseDictionary.word && chineseDictionary.word.length > 0) {
      return YoudaoDictionaryService.cleanText(chineseDictionary.word[0].phone);
    }
    if (legacyChineseDictionary && legacyChineseDictionary.word && legacyChineseDictionary.word.length > 0) {
      return YoudaoDictionaryService.cleanText(legacyChineseDictionary.word[0].phone);
    }
    return '';
  }

  private static pushUnique(items: string[], value: string, limit: number): boolean {
    if (value.length === 0 || items.length >= limit) {
      return false;
    }
    for (let index: number = 0; index < items.length; index++) {
      if (items[index] === value) {
        return false;
      }
    }
    items.push(value);
    return true;
  }

  private static containsExample(items: DictionaryExample[], sentence: string): boolean {
    for (let index: number = 0; index < items.length; index++) {
      if (items[index].sentence === sentence) {
        return true;
      }
    }
    return false;
  }

  private static containsPhrase(items: DictionaryPhrase[], phrase: string): boolean {
    for (let index: number = 0; index < items.length; index++) {
      if (items[index].phrase === phrase) {
        return true;
      }
    }
    return false;
  }

  private static containsNetworkDefinition(items: DictionaryNetworkDefinition[], term: string): boolean {
    for (let index: number = 0; index < items.length; index++) {
      if (items[index].term === term) {
        return true;
      }
    }
    return false;
  }

  private static containsEnglishDefinition(items: DictionaryEnglishDefinition[], definition: string): boolean {
    for (let index: number = 0; index < items.length; index++) {
      if (items[index].definition === definition) {
        return true;
      }
    }
    return false;
  }

  private static containsChinese(value: string): boolean {
    return /[\u3400-\u9FFF]/.test(value);
  }

  private static isEnglishPronounceable(value: string): boolean {
    return /[A-Za-z]/.test(value) && !YoudaoDictionaryService.containsChinese(value);
  }

  private static cleanText(value?: string): string {
    if (!value) {
      return '';
    }
    return value
      .replace(/<[^>]+>/g, '')
      .replace(/&quot;/g, '"')
      .replace(/&#39;|&apos;/g, "'")
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private static emptyResult(query: string, message: string): DictionaryLookupResult {
    return {
      success: false,
      sourceName: '有道词典',
      query: query,
      word: '',
      phonetic: '',
      partOfSpeech: '',
      audioUrl: '',
      definitionPairs: [],
      definitions: [],
      translations: [],
      bilingualExamples: [],
      mediaExamples: [],
      authorityExamples: [],
      networkDefinitions: [],
      specialDefinitions: [],
      englishDefinitions: [],
      phrases: [],
      etymology: '',
      suggestions: [],
      sourceUrl: '',
      message: message
    };
  }
}
