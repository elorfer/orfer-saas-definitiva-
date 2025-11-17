import { NextResponse } from 'next/server';

export async function GET(request: Request) {
  // Redirigir al login cuando hay un error de NextAuth
  const url = new URL(request.url);
  const error = url.searchParams.get('error');
  
  // Redirigir al login con el mensaje de error si es necesario
  const loginUrl = new URL('/login', request.url);
  if (error) {
    loginUrl.searchParams.set('error', error);
  }
  
  return NextResponse.redirect(loginUrl);
}

export async function POST(request: Request) {
  // Redirigir al login cuando hay un error de NextAuth
  const loginUrl = new URL('/login', request.url);
  return NextResponse.redirect(loginUrl);
}

