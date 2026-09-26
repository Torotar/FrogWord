import { http } from '@kit.NetworkKit';
import { DictionaryDefinition, DictionaryExample, DictionaryLookupResult } from '../model/DictionaryResult';

interface RegexMatch {
  text: string;
  index: number;
}

export class CambridgeDictionaryService {
  private static readonly BASE_URL: string = 'https://dictionary.cambridge.org';
  private static readonly EN_ZH_PATH: string = '/zhs/词典/英语-汉语-简体/';
  private static readonly ZH_EN_PATH: string = '/zhs/词典/汉语-简体-英语/';

  public static async lookup(keyword: string): Promise<DictionaryLookupResult> {
    const query: string = keyword.trim();
    if (query.length === 0) {
      return CambridgeDictionaryService.emptyResult(query, '请输入要查询的单词或中文释义');
    }

    if (CambridgeDictionaryService.containsChinese(query)) {
      return await CambridgeDictionaryService.lookupChinese(query);
    }
    return await CambridgeDictionaryService.lookupEnglish(query);
  }

  private static async lookupEnglish(word: string): Promise<DictionaryLookupResult> {
    const url: string = CambridgeDictionaryService.BASE_URL + CambridgeDictionaryService.EN_ZH_PATH + encodeURIComponent(word);
    const html: string = await CambridgeDictionaryService.requestHtml(url);
    if (html.length === 0) {
      return CambridgeDictionaryService.emptyResult(word, '剑桥词典查询失败，请检查网络');
    }

    const result: DictionaryLookupResult = CambridgeDictionaryService.parseEnglishPage(word, url, html);
    if (!result.success) {
      result.message = '剑桥词典未找到该单词';
    }
    return result;
  }

  private static async lookupChinese(keyword: string): Promise<DictionaryLookupResult> {
    const url: string = CambridgeDictionaryService.BASE_URL + CambridgeDictionaryService.ZH_EN_PATH + encodeURIComponent(keyword);
    const html: string = await CambridgeDictionaryService.requestHtml(url);
    if (html.length === 0) {
      return CambridgeDictionaryService.emptyResult(keyword, '剑桥词典查询失败，请检查网络');
    }

    const suggestions: string[] = CambridgeDictionaryService.extractChineseSuggestions(html);
    if (suggestions.length === 0) {
      return CambridgeDictionaryService.emptyResult(keyword, '剑桥词典未找到相关英文词');
    }

    const result: DictionaryLookupResult = await CambridgeDictionaryService.lookupEnglish(suggestions[0]);
    result.query = keyword;
    result.suggestions = suggestions;
    result.message = result.success ? '根据中文释义匹配到：' + suggestions[0] : result.message;
    return result;
  }

  private static async requestHtml(url: string): Promise<string> {
    const request = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0 WordFlowHarmony',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8'
        },
        connectTimeout: 30000,
        readTimeout: 30000
      });
      if (response.responseCode < 200 || response.responseCode >= 400) {
        console.error('Cambridge request failed responseCode=' + response.responseCode.toString() + ', url=' + url);
        return '';
      }
      return String(response.result);
    } catch (error) {
      console.error('Cambridge requestHtml failed: ' + JSON.stringify(error));
      return '';
    } finally {
      request.destroy();
    }
  }

  private static parseEnglishPage(query: string, url: string, html: string): DictionaryLookupResult {
    const word: string = CambridgeDictionaryService.firstText(html, /<span class="hw dhw">([\s\S]*?)<\/span>/);
    const partOfSpeech: string = CambridgeDictionaryService.firstText(html, /<span class="pos dpos"[\s\S]*?>([\s\S]*?)<\/span>/);
    const phonetic: string = CambridgeDictionaryService.firstText(html, /<span class="ipa dipa[^"]*">([\s\S]*?)<\/span>/);
    const audioUrl: string = CambridgeDictionaryService.extractAudioUrl(html);
    const definitionPairs: DictionaryDefinition[] = CambridgeDictionaryService.extractDefinitionPairs(html);
    const definitions: string[] = CambridgeDictionaryService.collectDefinitionTexts(definitionPairs);
    const translations: string[] = CambridgeDictionaryService.collectTranslationTexts(definitionPairs);
    const bilingualExamples: DictionaryExample[] = CambridgeDictionaryService.extractExamples(html);
    const success: boolean = word.length > 0 || definitions.length > 0 || translations.length > 0;

    return {
      success: success,
      sourceName: '剑桥词典',
      query: query,
      word: word.length > 0 ? word : query,
      phonetic: phonetic.length > 0 ? '/' + phonetic + '/' : '',
      partOfSpeech: partOfSpeech,
      audioUrl: audioUrl,
      definitionPairs: definitionPairs,
      definitions: definitions,
      translations: translations,
      bilingualExamples: bilingualExamples,
      mediaExamples: [],
      authorityExamples: [],
      networkDefinitions: [],
      specialDefinitions: [],
      englishDefinitions: [],
      phrases: [],
      etymology: '',
      suggestions: [],
      sourceUrl: url,
      message: ''
    };
  }

  private static extractAudioUrl(html: string): string {
    const audioMatches: RegexMatch[] = CambridgeDictionaryService.collectRawMatches(
      html,
      /<source type="audio\/mpeg" src="([^"]+\.mp3)"\/>/g,
      8
    );
    if (audioMatches.length === 0) {
      return '';
    }

    for (let index: number = 0; index < audioMatches.length; index++) {
      if (audioMatches[index].text.indexOf('/us_pron/') >= 0) {
        return CambridgeDictionaryService.absoluteUrl(audioMatches[index].text);
      }
    }
    return CambridgeDictionaryService.absoluteUrl(audioMatches[0].text);
  }

  private static extractDefinitionPairs(html: string): DictionaryDefinition[] {
    const result: DictionaryDefinition[] = [];
    const blockMatches: RegexMatch[] = CambridgeDictionaryService.collectRawMatches(
      html,
      /<div class="def-block ddef_block[\s\S]*?">([\s\S]*?)(?=<div class="def-block ddef_block|<div class="pr entry-body__el|<\/article>)/g,
      12
    );
    for (let index: number = 0; index < blockMatches.length && result.length < 6; index++) {
      const block: string = blockMatches[index].text;
      const definition: string = CambridgeDictionaryService.firstText(block, /<div class="def ddef_d db">([\s\S]*?)<\/div>/);
      const translation: string = CambridgeDictionaryService.firstText(
        block,
        /<span class="trans dtrans dtrans-se[^"]*"[^>]*>([\s\S]*?)<\/span>/
      );
      if ((definition.length > 0 || translation.length > 0) &&
        !CambridgeDictionaryService.containsDefinition(result, definition, translation)) {
        result.push({
          definition: definition,
          translation: translation
        });
      }
    }

    if (result.length === 0) {
      const definitions: string[] = CambridgeDictionaryService.collectTexts(html, /<div class="def ddef_d db">([\s\S]*?)<\/div>/g, 5);
      const translations: string[] = CambridgeDictionaryService.collectTexts(html, /<span class="trans dtrans dtrans-se[^"]*"[^>]*>([\s\S]*?)<\/span>/g, 6);
      const maxLength: number = definitions.length > translations.length ? definitions.length : translations.length;
      for (let index: number = 0; index < maxLength && result.length < 6; index++) {
        const definition: string = index < definitions.length ? definitions[index] : '';
        const translation: string = index < translations.length ? translations[index] : '';
        if (definition.length > 0 || translation.length > 0) {
          result.push({
            definition: definition,
            translation: translation
          });
        }
      }
    }
    return result;
  }

  private static collectDefinitionTexts(pairs: DictionaryDefinition[]): string[] {
    const result: string[] = [];
    for (let index: number = 0; index < pairs.length; index++) {
      if (pairs[index].definition.length > 0 && !CambridgeDictionaryService.containsText(result, pairs[index].definition)) {
        result.push(pairs[index].definition);
      }
    }
    return result;
  }

  private static collectTranslationTexts(pairs: DictionaryDefinition[]): string[] {
    const result: string[] = [];
    for (let index: number = 0; index < pairs.length; index++) {
      if (pairs[index].translation.length > 0 && !CambridgeDictionaryService.containsText(result, pairs[index].translation)) {
        result.push(pairs[index].translation);
      }
    }
    return result;
  }

  private static extractExamples(html: string): DictionaryExample[] {
    const examples: DictionaryExample[] = [];
    const blockRegex: RegExp = /<div class="examp dexamp">([\s\S]*?)<\/div>/g;
    let match: RegExpExecArray | null = blockRegex.exec(html);
    while (match !== null && examples.length < 4) {
      const block: string = match[1];
      const sentence: string = CambridgeDictionaryService.firstText(block, /<span class="eg deg">([\s\S]*?)<\/span>/);
      const translation: string = CambridgeDictionaryService.firstText(
        block,
        /<span class="trans dtrans dtrans-se[^"]*"[^>]*>([\s\S]*?)<\/span>/
      );
      if (sentence.length > 0) {
        examples.push({
          sentence: sentence,
          translation: translation
        });
      }
      match = blockRegex.exec(html);
    }
    return examples;
  }

  private static extractChineseSuggestions(html: string): string[] {
    const suggestions: string[] = [];
    const matches: RegexMatch[] = CambridgeDictionaryService.collectRawMatches(
      html,
      /<span class="trans dtranszh[^"]*"[^>]*>([\s\S]*?)<\/span>/g,
      20
    );
    for (let index: number = 0; index < matches.length; index++) {
      const text: string = CambridgeDictionaryService.cleanText(matches[index].text);
      if (text.length > 0 && CambridgeDictionaryService.isEnglishCandidate(text) &&
        !CambridgeDictionaryService.containsText(suggestions, text)) {
        suggestions.push(text);
      }
      if (suggestions.length >= 8) {
        break;
      }
    }
    return suggestions;
  }

  private static collectTexts(html: string, regex: RegExp, limit: number): string[] {
    const texts: string[] = [];
    const matches: RegexMatch[] = CambridgeDictionaryService.collectRawMatches(html, regex, limit * 2);
    for (let index: number = 0; index < matches.length; index++) {
      const text: string = CambridgeDictionaryService.cleanText(matches[index].text);
      if (text.length > 0 && !CambridgeDictionaryService.containsText(texts, text)) {
        texts.push(text);
      }
      if (texts.length >= limit) {
        break;
      }
    }
    return texts;
  }

  private static collectRawMatches(html: string, regex: RegExp, limit: number): RegexMatch[] {
    const matches: RegexMatch[] = [];
    let match: RegExpExecArray | null = regex.exec(html);
    while (match !== null && matches.length < limit) {
      matches.push({
        text: match[1],
        index: match.index
      });
      match = regex.exec(html);
    }
    return matches;
  }

  private static firstText(html: string, regex: RegExp): string {
    const match: RegExpExecArray | null = regex.exec(html);
    if (!match || match.length < 2) {
      return '';
    }
    return CambridgeDictionaryService.cleanText(match[1]);
  }

  private static cleanText(html: string): string {
    let text: string = html.replace(/<[^>]+>/g, '');
    text = CambridgeDictionaryService.decodeEntities(text);
    text = text.replace(/\s+/g, ' ').trim();
    return text;
  }

  private static decodeEntities(value: string): string {
    let text: string = value
      .replace(/&nbsp;/g, ' ')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'");

    const decimalRegex: RegExp = /&#(\d+);/g;
    let match: RegExpExecArray | null = decimalRegex.exec(text);
    while (match !== null) {
      const code: number = Number(match[1]);
      text = text.replace(match[0], String.fromCharCode(code));
      match = decimalRegex.exec(text);
    }
    return text;
  }

  private static containsChinese(text: string): boolean {
    return /[\u4e00-\u9fa5]/.test(text);
  }

  private static isEnglishCandidate(text: string): boolean {
    return /^[A-Za-z][A-Za-z\s.'()-]*$/.test(text);
  }

  private static containsText(items: string[], text: string): boolean {
    const lowerText: string = text.toLowerCase();
    for (let index: number = 0; index < items.length; index++) {
      if (items[index].toLowerCase() === lowerText) {
        return true;
      }
    }
    return false;
  }

  private static containsDefinition(items: DictionaryDefinition[], definition: string, translation: string): boolean {
    const lowerDefinition: string = definition.toLowerCase();
    const lowerTranslation: string = translation.toLowerCase();
    for (let index: number = 0; index < items.length; index++) {
      if (items[index].definition.toLowerCase() === lowerDefinition &&
        items[index].translation.toLowerCase() === lowerTranslation) {
        return true;
      }
    }
    return false;
  }

  private static absoluteUrl(path: string): string {
    if (path.startsWith('https://')) {
      return path;
    }
    return CambridgeDictionaryService.BASE_URL + path;
  }

  private static emptyResult(query: string, message: string): DictionaryLookupResult {
    return {
      success: false,
      sourceName: '剑桥词典',
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
