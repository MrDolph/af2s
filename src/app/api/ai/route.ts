import { NextRequest, NextResponse } from 'next/server';
import { ExplorerError, prepare } from '@/lib/explorer/prepare';
export async function POST(req:NextRequest) {
 let body:unknown;
 try {const raw=await req.text();if(raw.length>16000)return NextResponse.json({error:'Request too large.'},{status:413});body=JSON.parse(raw);}catch{return NextResponse.json({error:'Invalid JSON.'},{status:400});}
 if(!body||typeof body!=='object'||Array.isArray(body))return NextResponse.json({error:'Invalid request.'},{status:400});
 try {return NextResponse.json(prepare(body),{headers:{'Cache-Control':'no-store'}});}catch(error){return NextResponse.json({error:error instanceof ExplorerError?error.message:'Unable to prepare this activity.'},{status:error instanceof ExplorerError?error.status:500});}
}
