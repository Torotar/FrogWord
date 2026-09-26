import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';

export interface CacheSizeInfo {
  /** 缓存文件总字节数 */
  bytes: number;
  /** 人类可读的显示字符串，如 "2.3 MB" */
  display: string;
}

export class CacheService {
  private static readonly ONLINE_PREFIX: string = 'wordflow_online_';
  private static readonly AUDIO_PREFIX: string = 'wordflow_audio_';

  /**
   * 获取当前缓存总大小（扫描 wordflow_online_* 临时目录）
   */
  public static getCacheSize(context: common.Context): CacheSizeInfo {
    const cacheDir: string = context.cacheDir;
    let totalBytes: number = 0;

    try {
      const entries: string[] = fileIo.listFileSync(cacheDir, { recursion: false });
      for (let i: number = 0; i < entries.length; i++) {
        const name: string = entries[i];
        if (CacheService.isCacheEntry(name)) {
          totalBytes += CacheService.calcSize(cacheDir + '/' + name);
        }
      }
    } catch (error) {
      console.error('CacheService.getCacheSize failed: ' + JSON.stringify(error));
    }

    return {
      bytes: totalBytes,
      display: CacheService.formatSize(totalBytes)
    };
  }

  /**
   * 清除缓存并返回被清理的大小
   */
  public static clearCache(context: common.Context): CacheSizeInfo {
    const cacheDir: string = context.cacheDir;
    let totalFreed: number = 0;

    try {
      const entries: string[] = fileIo.listFileSync(cacheDir, { recursion: false });
      for (let i: number = 0; i < entries.length; i++) {
        const name: string = entries[i];
        if (CacheService.isCacheEntry(name)) {
          const fullPath: string = cacheDir + '/' + name;
          totalFreed += CacheService.calcSize(fullPath);
          CacheService.deleteRecursive(fullPath);
        }
      }
      console.info('CacheService.clearCache done, freed ' + CacheService.formatSize(totalFreed));
    } catch (error) {
      console.error('CacheService.clearCache failed: ' + JSON.stringify(error));
    }

    return {
      bytes: totalFreed,
      display: CacheService.formatSize(totalFreed)
    };
  }

  /**
   * 递归计算文件或目录的总大小
   */
  private static calcSize(path: string): number {
    let total: number = 0;
    try {
      const stat: fileIo.Stat = fileIo.statSync(path);
      if (stat.isDirectory()) {
        const children: string[] = fileIo.listFileSync(path, { recursion: false });
        for (let i: number = 0; i < children.length; i++) {
          total += CacheService.calcSize(path + '/' + children[i]);
        }
      } else {
        total += stat.size;
      }
    } catch (error) {
      console.warn('CacheService.calcSize skip ' + path + ': ' + JSON.stringify(error));
    }
    return total;
  }

  private static isCacheEntry(name: string): boolean {
    return name.startsWith(CacheService.ONLINE_PREFIX) || name.startsWith(CacheService.AUDIO_PREFIX);
  }

  /**
   * 递归删除文件或目录（非空目录也支持）
   */
  private static deleteRecursive(path: string): void {
    try {
      const stat: fileIo.Stat = fileIo.statSync(path);
      if (stat.isDirectory()) {
        const children: string[] = fileIo.listFileSync(path, { recursion: false });
        for (let i: number = 0; i < children.length; i++) {
          CacheService.deleteRecursive(path + '/' + children[i]);
        }
        fileIo.rmdirSync(path);
      } else {
        fileIo.unlinkSync(path);
      }
    } catch (error) {
      console.warn('CacheService.deleteRecursive skip ' + path + ': ' + JSON.stringify(error));
    }
  }

  /**
   * 将字节格式化为人类可读的字符串
   */
  private static formatSize(bytes: number): string {
    if (bytes <= 0) {
      return '0 B';
    }
    const units: string[] = ['B', 'KB', 'MB', 'GB'];
    const base: number = 1024;
    let unitIndex: number = 0;
    let size: number = bytes;
    while (size >= base && unitIndex < units.length - 1) {
      size /= base;
      unitIndex++;
    }
    if (unitIndex === 0) {
      return size.toFixed(0) + ' ' + units[unitIndex];
    }
    return size.toFixed(1) + ' ' + units[unitIndex];
  }
}
