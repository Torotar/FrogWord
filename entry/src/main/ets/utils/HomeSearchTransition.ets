export interface SearchTransitionRect {
  x: number;
  y: number;
  width: number;
  height: number;
}

export class HomeSearchTransition {
  private static returnSource: SearchTransitionRect | undefined = undefined;

  static isValid(rect: SearchTransitionRect | undefined): boolean {
    return rect !== undefined && rect.width > 0 && rect.height > 0;
  }

  static setReturnSource(rect: SearchTransitionRect): void {
    HomeSearchTransition.returnSource = rect;
  }

  static hasReturnSource(): boolean {
    return HomeSearchTransition.isValid(HomeSearchTransition.returnSource);
  }

  static consumeReturnSource(): SearchTransitionRect | undefined {
    const source: SearchTransitionRect | undefined = HomeSearchTransition.returnSource;
    HomeSearchTransition.returnSource = undefined;
    return source;
  }
}
