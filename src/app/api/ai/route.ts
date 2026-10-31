import { NextRequest, NextResponse } from 'next/server';
import { parseSimulationPrompt } from '@/lib/ai/parse-prompt';
import { DemoPromptError } from '@/lib/ai/demo-simulation';
import type { AIPromptRequest } from '@/types/ai';
export async function POST(req: NextRequest) {
  let body: unknown;
  try {
    const text = await req.text();
    if (text.length > 4000) return NextResponse.json({ error: 'Request too large.' }, { status: 413 });
    body = JSON.parse(text);
  } catch { return NextResponse.json({ error: 'Invalid JSON.' }, { status: 400 }); }
  if (!body || typeof body !== 'object') return NextResponse.json({ error: 'Invalid request.' }, { status: 400 });
  const { prompt, language } = body as { prompt?: unknown; language?: unknown };
  if (typeof prompt !== 'string' || !prompt.trim()) return NextResponse.json({ error: 'Prompt is required.' }, { status: 400 });
  if (prompt.length > 500) return NextResponse.json({ error: 'Prompt too long.' }, { status: 400 });
  if (language !== undefined && !['en','yo','ha','ig','fr','ar'].includes(language as string)) return NextResponse.json({ error: 'Invalid language.' }, { status: 400 });
  try {
    const result = await parseSimulationPrompt({ prompt: prompt.trim(), language } as AIPromptRequest);
    return NextResponse.json(result, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    if (error instanceof DemoPromptError) return NextResponse.json({ error: error.message, mode: 'demo' }, { status: 422 });
    // Do not print credentials, provider response headers or request contents.
    const status = error && typeof error === 'object' && 'status' in error ? error.status : undefined;
    if (status === 401) return NextResponse.json({ error: 'Live AI rejected the API key. Use SIMULATION_AI_MODE=demo for the free demo, then restart your server.' }, { status: 502 });
    return NextResponse.json({ error: 'Live AI is unavailable. Set SIMULATION_AI_MODE=demo and restart for the free demo.' }, { status: 503 });
  }
}
