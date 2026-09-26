import { Constants } from './Constants';

export class Logger {
  public static info(tag: string, message: string): void {
    console.info(Logger.format(tag, message));
  }

  public static warn(tag: string, message: string): void {
    console.warn(Logger.format(tag, message));
  }

  public static error(tag: string, message: string, error?: Error): void {
    const detail: string = error ? message + ' ' + error.message : message;
    console.error(Logger.format(tag, detail));
  }

  public static debug(tag: string, message: string): void {
    if (Constants.DEBUG_MODE) {
      console.info(Logger.format(tag, message));
    }
  }

  private static format(tag: string, message: string): string {
    return '[' + tag + '] ' + message;
  }
}
