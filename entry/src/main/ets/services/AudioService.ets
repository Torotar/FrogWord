import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { media } from '@kit.MediaKit';

export class AudioService {
  private static player?: media.AVPlayer;
  private static audioFile?: fileIo.File;
  private static readonly YOUDAO_VOICE_URL: string = 'http://dict.youdao.com/dictvoice?audio=';
  private static readonly PLAYBACK_FALLBACK_TIMEOUT_MS: number = 3000;
  private static readonly PLAYBACK_TIMEOUT_PADDING_MS: number = 800;
  private static playbackId: number = 0;

  public static async playWord(word: string, pronunciationUrl: string = '', context?: common.Context): Promise<string> {
    if (word.trim().length === 0) {
      return '单词为空，无法播放发音';
    }

    const url: string = pronunciationUrl.trim().length > 0
      ? AudioService.normalizePronunciationUrl(pronunciationUrl.trim())
      : AudioService.buildYoudaoPronunciationUrl(word.trim(), 2);
    const urls: string[] = AudioService.buildFallbackUrls(url);
    try {
      if (context) {
        try {
          await AudioService.playDownloadedFirstAvailable(urls, context);
        } catch (downloadPlayError) {
          console.warn('play downloaded audio failed, fallback to remote url: ' + AudioService.errorMessage(downloadPlayError));
          await AudioService.playFirstAvailable(urls);
        }
      } else {
        await AudioService.playFirstAvailable(urls);
      }
      console.info('playWord success word=' + word + ', url=' + urls[0]);
      return '';
    } catch (error) {
      console.error('playWord failed word=' + word + ', urls=' + JSON.stringify(urls) + ', error=' + JSON.stringify(error));
      await AudioService.stop();
      return '发音播放失败：' + AudioService.errorMessage(error);
    }
  }

  public static async playUrl(url: string, context?: common.Context): Promise<string> {
    if (url.trim().length === 0) {
      return '发音地址为空';
    }

    const urls: string[] = AudioService.buildFallbackUrls(AudioService.normalizePronunciationUrl(url.trim()));
    try {
      if (context) {
        try {
          await AudioService.playDownloadedFirstAvailable(urls, context);
        } catch (downloadPlayError) {
          console.warn('play downloaded audio failed, fallback to remote url: ' + AudioService.errorMessage(downloadPlayError));
          await AudioService.playFirstAvailable(urls);
        }
      } else {
        await AudioService.playFirstAvailable(urls);
      }
      console.info('playUrl success url=' + urls[0]);
      return '';
    } catch (error) {
      console.error('playUrl failed urls=' + JSON.stringify(urls) + ', error=' + JSON.stringify(error));
      await AudioService.stop();
      return '发音播放失败：' + AudioService.errorMessage(error);
    }
  }

  public static buildYoudaoPronunciationUrl(word: string, type: number = 2): string {
    const safeWord: string = word.trim();
    if (safeWord.length === 0) {
      return '';
    }
    return AudioService.YOUDAO_VOICE_URL + encodeURIComponent(safeWord) + '&type=' + type.toString();
  }

  private static async playFirstAvailable(urls: string[]): Promise<void> {
    let lastError: Error | undefined = undefined;
    for (let index: number = 0; index < urls.length; index++) {
      try {
        await AudioService.stop();
        const player: media.AVPlayer = await media.createAVPlayer();
        const playbackId: number = AudioService.beginPlayback(player);
        const initializedPromise: Promise<void> = AudioService.waitForPlayerState(player, ['initialized'], 5000);
        player.url = urls[index];
        await initializedPromise;
        const preparedPromise: Promise<void> = AudioService.waitForPlayerState(player, ['prepared'], 5000);
        await player.prepare();
        await preparedPromise;
        await player.play();
        await AudioService.waitForPlaybackEnd(player, AudioService.playbackTimeoutMs(player));
        await AudioService.releaseIfCurrent(player, playbackId);
        return;
      } catch (error) {
        console.warn('play audio candidate failed url=' + urls[index] + ', error=' + JSON.stringify(error));
        lastError = error as Error;
        await AudioService.stop();
      }
    }
    throw lastError ? lastError : new Error('No playable pronunciation url');
  }

  private static async playDownloadedFirstAvailable(urls: string[], context: common.Context): Promise<void> {
    let lastError: Error | undefined = undefined;
    for (let index: number = 0; index < urls.length; index++) {
      try {
        const path: string = await AudioService.downloadAudio(urls[index], context);
        await AudioService.playLocalFile(path);
        return;
      } catch (error) {
        console.warn('downloaded audio candidate failed url=' + urls[index] + ', error=' + JSON.stringify(error));
        lastError = error as Error;
        await AudioService.stop();
      }
    }
    throw lastError ? lastError : new Error('No downloadable pronunciation url');
  }

  private static async downloadAudio(url: string, context: common.Context): Promise<string> {
    const request = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; HarmonyOS) AppleWebKit/537.36',
          'Accept': 'audio/mpeg,*/*'
        },
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 15000,
        readTimeout: 30000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error('audio responseCode=' + response.responseCode.toString());
      }
      const data: ArrayBuffer = response.result as ArrayBuffer;
      if (data.byteLength <= 0) {
        throw new Error('audio data empty');
      }
      const path: string = context.cacheDir + '/wordflow_audio_' + Date.now().toString() + '.mp3';
      let file: fileIo.File | undefined = undefined;
      try {
        file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC | fileIo.OpenMode.READ_WRITE);
        fileIo.writeSync(file.fd, data);
      } finally {
        if (file) {
          fileIo.closeSync(file);
        }
      }
      return path;
    } finally {
      request.destroy();
    }
  }

  private static async playLocalFile(path: string): Promise<void> {
    await AudioService.stop();
    const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    AudioService.audioFile = file;
    const stat: fileIo.Stat = fileIo.statSync(path);
    const player: media.AVPlayer = await media.createAVPlayer();
    const playbackId: number = AudioService.beginPlayback(player, file);
    const initializedPromise: Promise<void> = AudioService.waitForPlayerState(player, ['initialized'], 5000);
    player.fdSrc = {
      fd: file.fd,
      offset: 0,
      length: stat.size
    };
    await initializedPromise;
    const preparedPromise: Promise<void> = AudioService.waitForPlayerState(player, ['prepared'], 5000);
    await player.prepare();
    await preparedPromise;
    await player.play();
    await AudioService.waitForPlaybackEnd(player, AudioService.playbackTimeoutMs(player));
    await AudioService.releaseIfCurrent(player, playbackId);
  }

  private static async waitForPlayerState(player: media.AVPlayer, expectedStates: string[], timeoutMs: number): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      let finished: boolean = false;
      const timer = setTimeout(() => {
        if (!finished) {
          finished = true;
          reject(new Error('AVPlayer state wait timeout: ' + expectedStates.join('/')));
        }
      }, timeoutMs);

      player.on('stateChange', (state: string) => {
        console.info('AVPlayer stateChange: ' + state);
        if (finished) {
          return;
        }
        if (state === 'error') {
          finished = true;
          clearTimeout(timer);
          reject(new Error('AVPlayer entered error state'));
          return;
        }
        if (expectedStates.indexOf(state) >= 0) {
          finished = true;
          clearTimeout(timer);
          resolve();
        }
      });
    });
  }

  private static buildFallbackUrls(url: string): string[] {
    const urls: string[] = [url];
    if (url.startsWith('https://dict.youdao.com/')) {
      urls.push('http://dict.youdao.com/' + url.substring('https://dict.youdao.com/'.length));
    } else if (url.startsWith('http://dict.youdao.com/')) {
      urls.push('https://dict.youdao.com/' + url.substring('http://dict.youdao.com/'.length));
    }
    const audio: string = AudioService.extractYoudaoAudio(url);
    if (audio.length > 0) {
      urls.push('https://voice.youdao.com/fanyivoice?word=' + encodeURIComponent(audio) + '&le=eng&keyfrom=speaker-target');
      urls.push('http://dict.youdao.com/dictvoice?audio=' + encodeURIComponent(audio) + '&type=1');
    }
    return AudioService.uniqueUrls(urls);
  }

  private static beginPlayback(player: media.AVPlayer, audioFile?: fileIo.File): number {
    AudioService.playbackId++;
    AudioService.player = player;
    AudioService.audioFile = audioFile;
    return AudioService.playbackId;
  }

  private static playbackTimeoutMs(player: media.AVPlayer): number {
    const duration: number = Number(player.duration);
    if (duration > 0) {
      return Math.max(duration + AudioService.PLAYBACK_TIMEOUT_PADDING_MS, AudioService.PLAYBACK_FALLBACK_TIMEOUT_MS);
    }
    return AudioService.PLAYBACK_FALLBACK_TIMEOUT_MS;
  }

  private static async waitForPlaybackEnd(player: media.AVPlayer, timeoutMs: number): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      let finished: boolean = false;
      const timer = setTimeout(() => {
        if (!finished) {
          finished = true;
          resolve();
        }
      }, timeoutMs);

      player.on('stateChange', (state: string) => {
        console.info('AVPlayer playback stateChange: ' + state);
        if (finished) {
          return;
        }
        if (state === 'error') {
          finished = true;
          clearTimeout(timer);
          reject(new Error('AVPlayer entered error state during playback'));
          return;
        }
        if (state === 'completed' || state === 'stopped' || state === 'released') {
          finished = true;
          clearTimeout(timer);
          resolve();
        }
      });
    });
  }

  private static async releaseIfCurrent(player: media.AVPlayer, playbackId: number): Promise<void> {
    if (AudioService.player !== player || AudioService.playbackId !== playbackId) {
      return;
    }
    try {
      await player.release();
    } catch (error) {
      console.error('AudioService release current player failed: ' + JSON.stringify(error));
    }
    if (AudioService.player === player && AudioService.playbackId === playbackId) {
      AudioService.player = undefined;
      if (AudioService.audioFile) {
        fileIo.closeSync(AudioService.audioFile);
        AudioService.audioFile = undefined;
      }
    }
  }

  private static extractYoudaoAudio(url: string): string {
    const audioKey: string = 'audio=';
    const audioIndex: number = url.indexOf(audioKey);
    if (audioIndex < 0) {
      return '';
    }
    const start: number = audioIndex + audioKey.length;
    const end: number = url.indexOf('&', start);
    const rawAudio: string = end >= 0 ? url.substring(start, end) : url.substring(start);
    return decodeURIComponent(rawAudio);
  }

  private static normalizePronunciationUrl(url: string): string {
    if (url.startsWith('https://dict.youdao.com/')) {
      return 'http://dict.youdao.com/' + url.substring('https://dict.youdao.com/'.length);
    }
    return url;
  }

  private static uniqueUrls(urls: string[]): string[] {
    const unique: string[] = [];
    for (let index: number = 0; index < urls.length; index++) {
      if (unique.indexOf(urls[index]) < 0) {
        unique.push(urls[index]);
      }
    }
    return unique;
  }

  private static errorMessage(error: Object): string {
    const errorObject: Error = error as Error;
    if (errorObject.message && errorObject.message.length > 0) {
      return errorObject.message;
    }
    const text: string = JSON.stringify(error);
    if (text && text.length > 2) {
      return text;
    }
    return String(error);
  }

  public static async stop(): Promise<void> {
    AudioService.playbackId++;
    try {
      if (AudioService.player) {
        await AudioService.player.release();
        AudioService.player = undefined;
      }
      if (AudioService.audioFile) {
        fileIo.closeSync(AudioService.audioFile);
        AudioService.audioFile = undefined;
      }
    } catch (error) {
      console.error('AudioService stop failed: ' + JSON.stringify(error));
      AudioService.player = undefined;
      AudioService.audioFile = undefined;
    }
  }
}
