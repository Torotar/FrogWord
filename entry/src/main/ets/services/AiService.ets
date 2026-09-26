import { http } from '@kit.NetworkKit';
import { AiConfig } from '../model/AiConfig';
import { AiConfigService } from './AiConfigService';

interface ChatMessage {
  role: string;
  content: string;
}

interface ChatRequestBody {
  model: string;
  messages: ChatMessage[];
  temperature: number;
}

interface ChatChoice {
  message?: ChatMessage;
}

interface ChatError {
  message?: string;
}

interface ChatResponseBody {
  choices?: ChatChoice[];
  error?: ChatError;
}

interface ModelItem {
  id?: string;
}

interface ModelListResponse {
  data?: ModelItem[];
  error?: ChatError;
}

export class AiService {
  public static async generateWordExplanation(word: string): Promise<string> {
    const config: AiConfig = await AiConfigService.getConfig();
    if (!config.aiApiKey || config.aiApiKey.trim().length === 0) {
      return 'API Key 为空，请先在 AI 接口配置中填写 API Key。';
    }

    const request = http.createHttp();
    try {
      const chatUrl: string = AiService.buildChatCompletionsUrl(config.aiBaseUrl);
      const body: ChatRequestBody = {
        model: config.aiModel,
        messages: [
          {
            role: 'system',
            content: '你是一个英语学习助手，请用简洁中文解释单词，并给出一个简单英文例句。'
          },
          {
            role: 'user',
            content: '请解释单词 ' + word
          }
        ],
        temperature: 0.7
      };

      const response: http.HttpResponse = await request.request(chatUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + config.aiApiKey
        },
        extraData: JSON.stringify(body),
        connectTimeout: 30000,
        readTimeout: 30000
      });

      const responseText: string = String(response.result);
      if (AiService.isHtmlResponse(responseText)) {
        return 'AI 接口返回了网页内容，请检查 Base URL。DeepSeek 请填写 https://api.deepseek.com，当前请求地址：' + chatUrl;
      }
      try {
        const parsed: ChatResponseBody = JSON.parse(responseText) as ChatResponseBody;
        if (parsed.error && parsed.error.message) {
          return parsed.error.message;
        }
        if (parsed.choices && parsed.choices.length > 0 && parsed.choices[0].message) {
          return parsed.choices[0].message.content;
        }
      } catch (parseError) {
        console.error('AI response parse failed: ' + JSON.stringify(parseError));
      }
      return responseText;
    } catch (error) {
      console.error('AI request failed: ' + JSON.stringify(error));
      return 'AI 请求失败：' + JSON.stringify(error);
    } finally {
      request.destroy();
    }
  }

  public static async fetchAvailableModels(currentConfig?: AiConfig): Promise<string> {
    const config: AiConfig = currentConfig ? currentConfig : await AiConfigService.getConfig();
    if (!config.aiApiKey || config.aiApiKey.trim().length === 0) {
      return 'API Key 为空，请先在 AI 接口配置中填写 API Key。';
    }

    const modelsUrl: string = AiService.buildModelsUrl(config.aiBaseUrl);
    const request = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(modelsUrl, {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + config.aiApiKey
        },
        connectTimeout: 30000,
        readTimeout: 30000
      });

      const responseText: string = String(response.result);
      if (AiService.isHtmlResponse(responseText)) {
        return '模型列表接口返回了网页内容，说明 Base URL 不是 API 地址。DeepSeek 请填写 https://api.deepseek.com，当前请求地址：' + modelsUrl;
      }
      try {
        const parsed: ModelListResponse = JSON.parse(responseText) as ModelListResponse;
        if (parsed.error && parsed.error.message) {
          return parsed.error.message;
        }
        if (parsed.data && parsed.data.length > 0) {
          const ids: string[] = [];
          for (let index: number = 0; index < parsed.data.length && index < 30; index++) {
            const id: string | undefined = parsed.data[index].id;
            if (id && id.length > 0) {
              ids.push(id);
            }
          }
          return ids.length > 0 ? ids.join('\n') : responseText;
        }
      } catch (parseError) {
        console.error('Models response parse failed: ' + JSON.stringify(parseError));
      }
      return responseText;
    } catch (error) {
      console.error('fetchAvailableModels failed: ' + JSON.stringify(error));
      return '模型列表拉取失败：' + JSON.stringify(error);
    } finally {
      request.destroy();
    }
  }

  private static buildChatCompletionsUrl(baseUrl: string): string {
    const normalizedUrl: string = AiService.normalizeBaseUrl(baseUrl);
    if (normalizedUrl.endsWith('/chat/completions')) {
      return normalizedUrl;
    }
    if (normalizedUrl.endsWith('/models')) {
      return normalizedUrl.substring(0, normalizedUrl.length - '/models'.length) + '/chat/completions';
    }
    return normalizedUrl + '/chat/completions';
  }

  private static buildModelsUrl(baseUrl: string): string {
    const normalizedUrl: string = AiService.normalizeBaseUrl(baseUrl);
    if (normalizedUrl.endsWith('/chat/completions')) {
      return normalizedUrl.substring(0, normalizedUrl.length - '/chat/completions'.length) + '/models';
    }
    if (normalizedUrl.endsWith('/models')) {
      return normalizedUrl;
    }
    return normalizedUrl + '/models';
  }

  private static normalizeBaseUrl(baseUrl: string): string {
    let url: string = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    if (url.indexOf('platform.deepseek.com') >= 0 || url === 'https://deepseek.com' || url === 'https://www.deepseek.com') {
      return 'https://api.deepseek.com';
    }
    if (url === 'https://api.openai.com') {
      return 'https://api.openai.com/v1';
    }
    if (url.endsWith('/v1/chat/completions')) {
      return url;
    }
    return url;
  }

  private static isHtmlResponse(responseText: string): boolean {
    const trimmedText: string = responseText.trim().toLowerCase();
    return trimmedText.startsWith('<!doctype html') || trimmedText.startsWith('<html');
  }
}
