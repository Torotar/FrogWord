import { SearchTransitionRect } from './HomeSearchTransition';

export interface HomeModuleTransitionRoute {
  id: string;
  source: SearchTransitionRect;
}

export class HomeModuleTransition {
  private static returnSources: Map<string, SearchTransitionRect> = new Map<string, SearchTransitionRect>();

  static isValid(rect: SearchTransitionRect | undefined): boolean {
    return rect !== undefined && rect.width > 0 && rect.height > 0;
  }

  static isValidRoute(route: HomeModuleTransitionRoute | undefined): boolean {
    return route !== undefined && route.id.length > 0 && HomeModuleTransition.isValid(route.source);
  }

  static setReturnSource(id: string, source: SearchTransitionRect): void {
    if (id.length === 0 || !HomeModuleTransition.isValid(source)) {
      return;
    }
    HomeModuleTransition.returnSources.set(id, source);
  }

  static consumeReturnSource(id: string): SearchTransitionRect | undefined {
    const source: SearchTransitionRect | undefined = HomeModuleTransition.returnSources.get(id);
    HomeModuleTransition.returnSources.delete(id);
    return source;
  }
}
