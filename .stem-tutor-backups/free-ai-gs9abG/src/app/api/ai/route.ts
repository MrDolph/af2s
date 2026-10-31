import { NextRequest, NextResponse } from 'next/server';
import { parseSimulationPrompt } from '@/lib/ai/parse-prompt';
import type { AIPromptRequest } from '@/types/ai';

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json()) as AIPromptRequest;
    if (!body.prompt || typeof body.prompt !== 'string')
      return NextResponse.json({ error: 'Prompt is required' }, { status: 400 });
    if (body.prompt.length > 500)
      return NextResponse.json({ error: 'Prompt too long' }, { status: 400 });
    const result = await parseSimulationPrompt(body);
    return NextResponse.json(result);
  } catch (error) {
    console.error('[AI Route Error]', error);
    return NextResponse.json({ error: 'Failed to process prompt.' }, { status: 500 });
  }
}
