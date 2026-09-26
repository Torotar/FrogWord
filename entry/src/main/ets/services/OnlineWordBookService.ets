import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { buffer } from '@kit.ArkTS';
import { zlib } from '@kit.BasicServicesKit';
import { ImportResult, ImportWordItem } from '../model/ImportResult';
import { OnlineWordBook } from '../model/OnlineWordBook';
import { YoudaoWordParser } from '../utils/YoudaoWordParser';
import { JsonParser } from '../utils/JsonParser';
import { ImportService } from './ImportService';
import { WordBookService } from './WordBookService';

interface YoudaoBookTag {
  tagName?: string;
}

interface YoudaoBookInfo {
  id?: string;
  title?: string;
  introduce?: string;
  wordNum?: number;
  size?: number;
  offlinedata?: string;
  tags?: YoudaoBookTag[];
}

interface YoudaoBookListData {
  normalBooksInfo?: YoudaoBookInfo[];
}

interface YoudaoBookListResponse {
  data?: YoudaoBookListData;
}

export class OnlineWordBookService {
  private static readonly BOOK_LIST_URL: string =
    'https://raw.githubusercontent.com/kajweb/dict/master/bookLists.txt';
  private static readonly BOOK_LIST_FALLBACK_URL: string =
    'https://cdn.jsdelivr.net/gh/kajweb/dict@master/bookLists.txt';
  private static readonly RAW_BOOK_BASE_URL: string =
    'https://raw.githubusercontent.com/kajweb/dict/master/book/';
  private static readonly RAW_BOOK_FALLBACK_BASE_URL: string =
    'https://cdn.jsdelivr.net/gh/kajweb/dict@master/book/';
  private static cachedBooks: OnlineWordBook[] = [];

  public static async fetchOnlineBooks(forceRefresh: boolean = false): Promise<OnlineWordBook[]> {
    if (!forceRefresh && OnlineWordBookService.cachedBooks.length > 0) {
      return OnlineWordBookService.cachedBooks;
    }

    // 尝试主地址，失败时尝试备用 CDN 地址
    const content: string = await OnlineWordBookService.tryFetchString([
      OnlineWordBookService.BOOK_LIST_URL,
      OnlineWordBookService.BOOK_LIST_FALLBACK_URL
    ]);
    if (content.length === 0) {
      console.error('fetchOnlineBooks: all URLs failed');
      return [];
    }

    try {
      const parsed: YoudaoBookListResponse = JSON.parse(content) as YoudaoBookListResponse;
      const sourceBooks: YoudaoBookInfo[] = parsed.data?.normalBooksInfo || [];
      const books: OnlineWordBook[] = [];
      for (let index: number = 0; index < sourceBooks.length; index++) {
        const book: OnlineWordBook | null = OnlineWordBookService.toOnlineBook(sourceBooks[index]);
        if (book) {
          books.push(book);
        }
      }
      OnlineWordBookService.cachedBooks = books;
      return books;
    } catch (error) {
      console.error('fetchOnlineBooks failed: ' + JSON.stringify(error));
      return [];
    }
  }

  public static async importOnlineBook(context: common.Context, book: OnlineWordBook): Promise<ImportResult> {
    const workDir: string = context.cacheDir + '/wordflow_online_' + book.id + '_' + Date.now().toString();
    const zipPath: string = workDir + '/' + book.id + '.zip';
    const outputDir: string = workDir + '/output';
    try {
      OnlineWordBookService.mkdir(workDir);
      OnlineWordBookService.mkdir(outputDir);
      // 下载 ZIP：最多重试 2 次，超时递增
      let downloaded: boolean = false;
      const maxRetries: number = 2;
      const downloadUrls: string[] = OnlineWordBookService.buildDownloadUrls(book.downloadUrl);
      for (let retry: number = 0; retry <= maxRetries; retry++) {
        if (retry > 0) {
          console.info('retry download attempt ' + (retry + 1).toString() + '/' + (maxRetries + 1).toString());
        }
        downloaded = await OnlineWordBookService.tryDownloadFile(downloadUrls, zipPath, 60000 * (retry + 1));
        if (downloaded) {
          break;
        }
        console.warn('download attempt ' + (retry + 1).toString() + ' failed, ' +
          (retry < maxRetries ? 'retrying...' : 'no more retries'));
      }
      if (!downloaded) {
        return OnlineWordBookService.failResult('词书下载失败（已重试' + (maxRetries + 1).toString() + '次）：' + book.title);
      }
      try {
        await zlib.unzipFile(zipPath, outputDir, {});
      } catch (unzipError) {
        console.error('unzipFile failed: ' + JSON.stringify(unzipError));
        return OnlineWordBookService.failResult('词书解压失败，请检查压缩包格式：' + book.title);
      }

      const extractedFiles: string[] = fileIo.listFileSync(outputDir, { recursion: true });
      console.info('extracted ' + extractedFiles.length.toString() + ' files: ' + JSON.stringify(extractedFiles));

      const jsonPath: string = OnlineWordBookService.findJsonPath(outputDir, book.id);
      if (jsonPath.length === 0) {
        return OnlineWordBookService.failResult('下载成功，但压缩包中没有找到 JSON 词书文件：' + book.title);
      }
      const content: string = OnlineWordBookService.readText(jsonPath);
      console.info('read json file size=' + content.length.toString() + ', first 200 chars=' + content.substring(0, 200));
      if (content.trim().length === 0) {
        return OnlineWordBookService.failResult('下载成功，但没有读取到词书内容：' + book.title);
      }

      const words: ImportWordItem[] = YoudaoWordParser.parseJsonLines(content);
      console.info('parsed ' + words.length.toString() + ' words from ' + book.title + ' via YoudaoWordParser');
      if (words.length === 0) {
        // 如果 JSON Lines 解析失败，尝试作为标准 JSON 数组解析
        try {
          const fallbackWords: ImportWordItem[] = JsonParser.parse(content);
          console.info('fallback JsonParser gave ' + fallbackWords.length.toString() + ' words');
          if (fallbackWords.length > 0) {
            words.push(...fallbackWords);
          }
        } catch (fallbackError) {
          console.warn('JsonParser fallback also failed: ' + JSON.stringify(fallbackError));
        }
      }
      if (words.length === 0) {
        return OnlineWordBookService.failResult('词书解析失败：' + book.title);
      }

      await WordBookService.deleteEmptyWordBooksByName(book.title);
      console.info('start importWords: ' + book.title + ', words=' + words.length.toString());
      return await ImportService.importWords(
        book.title,
        '在线导入：kajweb/dict，原始词书 ' + book.id,
        words
      );
    } catch (error) {
      console.error('importOnlineBook failed at step=' + book.title + ', error=' + JSON.stringify(error));
      return OnlineWordBookService.failResult('在线词书导入失败：' + JSON.stringify(error));
    }
  }

  private static toOnlineBook(source: YoudaoBookInfo): OnlineWordBook | null {
    const id: string = OnlineWordBookService.safeString(source.id);
    const title: string = OnlineWordBookService.safeString(source.title);
    const offlineData: string = OnlineWordBookService.safeString(source.offlinedata);
    if (id.length === 0 || title.length === 0 || offlineData.length === 0) {
      return null;
    }

    return {
      id: id,
      title: title,
      description: OnlineWordBookService.safeString(source.introduce),
      wordNum: source.wordNum ? source.wordNum : 0,
      size: source.size ? source.size : 0,
      downloadUrl: OnlineWordBookService.buildGitHubDownloadUrl(offlineData),
      tags: OnlineWordBookService.buildTags(source.tags)
    };
  }

  private static buildGitHubDownloadUrl(offlineData: string): string {
    const lastSlashIndex: number = offlineData.lastIndexOf('/');
    const fileName: string = lastSlashIndex >= 0 ? offlineData.substring(lastSlashIndex + 1) : offlineData;
    return OnlineWordBookService.RAW_BOOK_BASE_URL + fileName;
  }

  private static buildDownloadUrls(primaryUrl: string): string[] {
    const fileName: string = OnlineWordBookService.extractFileName(primaryUrl);
    const fallbackUrl: string = OnlineWordBookService.RAW_BOOK_FALLBACK_BASE_URL + fileName;
    return primaryUrl === fallbackUrl ? [primaryUrl] : [primaryUrl, fallbackUrl];
  }

  private static buildTags(tags?: YoudaoBookTag[]): string {
    if (!tags || tags.length === 0) {
      return '';
    }

    const names: string[] = [];
    for (let index: number = 0; index < tags.length; index++) {
      const name: string = OnlineWordBookService.safeString(tags[index].tagName);
      if (name.length > 0) {
        names.push(name);
      }
    }
    return names.join(' / ');
  }

  private static async downloadFile(url: string, path: string, readTimeoutMs: number = 60000): Promise<boolean> {
    const request = http.createHttp();
    try {
      console.info('start download: ' + url);
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; HarmonyOS) AppleWebKit/537.36'
        },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 30000,
        readTimeout: readTimeoutMs
      });

      if (response.responseCode < 200 || response.responseCode >= 300) {
        console.error('download online book failed responseCode=' + response.responseCode.toString() + ', url=' + url);
        return false;
      }

      const data: ArrayBuffer = response.result as ArrayBuffer;
      console.info('download success, size=' + data.byteLength.toString() + ', url=' + url);
      let file: fileIo.File | undefined = undefined;
      try {
        file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.READ_WRITE);
        fileIo.writeSync(file.fd, data);
      } finally {
        if (file) {
          fileIo.closeSync(file);
        }
      }
      return true;
    } catch (error) {
      console.error('downloadFile failed: ' + JSON.stringify(error) + ', url=' + url);
      return false;
    } finally {
      request.destroy();
    }
  }

  private static async tryDownloadFile(urls: string[], path: string, readTimeoutMs: number): Promise<boolean> {
    for (let index: number = 0; index < urls.length; index++) {
      if (await OnlineWordBookService.downloadFile(urls[index], path, readTimeoutMs)) {
        return true;
      }
    }
    return false;
  }

  /**
   * 依次尝试多个 URL，返回第一个成功响应的文本内容
   */
  private static async tryFetchString(urls: string[]): Promise<string> {
    for (let index: number = 0; index < urls.length; index++) {
      const url: string = urls[index];
      const request = http.createHttp();
      try {
        console.info('tryFetchString: ' + url);
        const response: http.HttpResponse = await request.request(url, {
          method: http.RequestMethod.GET,
          header: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10; HarmonyOS) AppleWebKit/537.36'
          },
          connectTimeout: 15000,
          readTimeout: 30000
        });
        if (response.responseCode >= 200 && response.responseCode < 300) {
          const text: string = String(response.result);
          if (text.length > 0) {
            return text;
          }
        }
        console.warn('tryFetchString failed responseCode=' + response.responseCode.toString() + ', url=' + url);
      } catch (error) {
        console.warn('tryFetchString error url=' + url + ', error=' + JSON.stringify(error));
      } finally {
        request.destroy();
      }
    }
    return '';
  }

  /**
   * 从 URL 中提取文件名（最后一个 / 之后的部分）
   */
  private static extractFileName(url: string): string {
    const lastSlashIndex: number = url.lastIndexOf('/');
    return lastSlashIndex >= 0 ? url.substring(lastSlashIndex + 1) : url;
  }

  private static readText(path: string): string {
    let file: fileIo.File | undefined = undefined;
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(path);
      const arrayBuffer: ArrayBuffer = new ArrayBuffer(stat.size);
      const readLength: number = fileIo.readSync(file.fd, arrayBuffer);
      const rawText: string = buffer.from(arrayBuffer, 0, readLength).toString();
      // 去除 BOM (Byte Order Mark) 字符
      if (rawText.charCodeAt(0) === 0xFEFF) {
        return rawText.substring(1);
      }
      return rawText;
    } catch (error) {
      console.error('read online book text failed: ' + JSON.stringify(error));
      return '';
    } finally {
      if (file) {
        fileIo.closeSync(file);
      }
    }
  }

  private static findJsonPath(outputDir: string, bookId: string): string {
    const preferredPath: string = outputDir + '/' + bookId + '.json';
    if (OnlineWordBookService.existsFile(preferredPath)) {
      return preferredPath;
    }

    try {
      const files: string[] = fileIo.listFileSync(outputDir, { recursion: true });
      let firstJsonPath: string = '';
      for (let index: number = 0; index < files.length; index++) {
        const fileName: string = files[index];
        if (fileName.toLowerCase().endsWith('.json')) {
          const fullPath: string = OnlineWordBookService.joinPath(outputDir, fileName);
          if (fileName.indexOf(bookId) >= 0) {
            return fullPath;
          }
          if (firstJsonPath.length === 0) {
            firstJsonPath = fullPath;
          }
        }
      }
      return firstJsonPath;
    } catch (error) {
      console.error('findJsonPath failed: ' + JSON.stringify(error));
      return '';
    }
  }

  private static existsFile(path: string): boolean {
    try {
      fileIo.statSync(path);
      return true;
    } catch (error) {
      return false;
    }
  }

  private static joinPath(dir: string, fileName: string): string {
    if (fileName.startsWith('/')) {
      return dir + fileName;
    }
    return dir + '/' + fileName;
  }

  private static mkdir(path: string): void {
    try {
      fileIo.mkdirSync(path);
    } catch (error) {
      console.info('mkdir skipped: ' + path + ', ' + JSON.stringify(error));
    }
  }

  private static safeString(value?: string): string {
    return value ? value.trim() : '';
  }

  private static failResult(message: string): ImportResult {
    return {
      success: false,
      bookName: '',
      successCount: 0,
      skipCount: 0,
      failCount: 0,
      message: message
    };
  }
}
