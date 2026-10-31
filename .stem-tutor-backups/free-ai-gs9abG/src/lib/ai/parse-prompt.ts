import Anthropic from '@anthropic-ai/sdk';
import type { AIPromptRequest, AIPromptResponse } from '@/types/ai';

const client = new Anthropic();

const SYSTEM_PROMPT = `You are the AI engine for A-Factor STEM Studio, a STEM simulation platform for African secondary schools (WAEC/NECO/JAMB curriculum).

When a user describes a physics concept or asks to simulate something, extract the simulation parameters and return a JSON object ONLY — no markdown, no explanation outside the JSON.

Supported simulation types: projectile_motion, newtons_second_law, circular_motion, simple_harmonic_motion, ohms_law, simple_circuit

Return this exact JSON shape:
{
  "simulationType": "<type>",
  "title": "<short title>",
  "description": "<one sentence>",
  "params": {},
  "explanation": "<2-3 sentence plain English explanation>",
  "suggestedFollowUps": ["<q1>", "<q2>", "<q3>"]
}

For projectile_motion params: initialVelocity (m/s), angle (degrees), gravity (m/s², default 9.81), mass (kg, default 1)
For newtons_second_law params: mass (kg), force (N), friction (0-1)

If the user writes in Yoruba, Hausa, or Igbo, respond with explanation in that language but keep JSON keys in English.`;

export async function parseSimulationPrompt(request: AIPromptRequest): Promise<AIPromptResponse> {
  const message = await client.messages.create({
    model: 'claude-sonnet-4-6',
    max_tokens: 1024,
    system: SYSTEM_PROMPT,
    messages: [{ role: 'user', content: request.prompt }],
  });
  const content = message.content[0];
  if (content.type !== 'text') throw new Error('Unexpected response type');
  const cleaned = content.text.replace(/```json|```/g, '').trim();
  return JSON.parse(cleaned) as AIPromptResponse;
}
