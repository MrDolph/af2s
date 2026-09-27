import { NextResponse } from 'next/server';
import { getAnalyticsSummary } from '@/lib/analytics/redis';

export async function GET() {
  const summary = await getAnalyticsSummary();
  return NextResponse.json(summary);
}
