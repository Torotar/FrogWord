import { AiConfig } from '../model/AiConfig';
import { PreferencesService } from './PreferencesService';

export class AiConfigService {
  public static async getConfig(): Promise<AiConfig> {
    return await PreferencesService.getAiConfig();
  }

  public static async saveConfig(config: AiConfig): Promise<void> {
    await PreferencesService.saveAiConfig(config);
  }

  public static async getApiKey(provider: string): Promise<string> {
    return await PreferencesService.getAiApiKey(provider);
  }

  public static async saveApiKey(provider: string, apiKey: string): Promise<void> {
    await PreferencesService.saveAiApiKey(provider, apiKey);
  }

  public static async getModel(provider: string): Promise<string> {
    return await PreferencesService.getAiModel(provider);
  }

  public static async saveModel(provider: string, model: string): Promise<void> {
    await PreferencesService.saveAiModel(provider, model);
  }
}
