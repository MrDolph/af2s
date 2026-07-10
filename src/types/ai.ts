import type { SimulationType, SimulationParams } from './simulation';

export interface AIPromptRequest {
  prompt: string;
  language?: 'en' | 'yo' | 'ha' | 'ig' | 'fr' | 'ar';
}

export interface AIPromptResponse {
  simulationType: SimulationType;
  title: string;
  description: string;
  params: SimulationParams;
  explanation: string;
  suggestedFollowUps: string[];
}

export interface ConversationMessage {
  role: 'user' | 'assistant';
  content: string;
}
