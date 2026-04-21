import { NextResponse } from 'next/server';
import OpenAI from 'openai';

export async function POST(req: Request) {
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
  });

  if (!process.env.OPENAI_API_KEY) {
    return NextResponse.json(
      { error: "API Key de OpenAI no configurada en el servidor." },
      { status: 500 }
    );
  }

  try {
    const { idea, genre, mood, lang } = await req.json();

    if (!idea) {
      return NextResponse.json(
        { error: "La idea es obligatoria." },
        { status: 400 }
      );
    }

    const systemPrompt = `Eres un compositor estrella de música profesional. 
    Tu objetivo es escribir una letra de canción completa basada en una idea simple.
    
    ESTRUCTURA OBLIGATORIA:
    - [VERSO 1]
    - [VERSO 2]
    - [ESTRIBILLO / CORO] (Debe ser pegajoso y repetible)
    - [PUENTE / BRIDGE]
    - [CORO FINAL]
    - [OUTRO]

    REGLAS:
    - Crea rimas elegantes y con ritmo.
    - Adapta el vocabulario al Género: ${genre} y al Estado de Ánimo: ${mood}.
    - Si el género es Urbano/Reggaetón, usa un lenguaje moderno y rítmico.
    - Si es Salsa/Balada, usa un lenguaje más poético.
    - Escribe el resultado en el mismo idioma de la idea proporcionada por el usuario (detectar automáticamente).
    - No añadas comentarios, solo la letra con sus etiquetas de estructura.`;

    const response = await openai.chat.completions.create({
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: `Idea: ${idea}. Escribe una canción de género ${genre} que suene ${mood}.` }
      ],
      temperature: 0.8,
      max_tokens: 1000,
    });

    const lyrics = response.choices[0].message.content;

    return NextResponse.json({ lyrics });
  } catch (error: any) {
    console.error("OpenAI Error:", error);
    return NextResponse.json(
      { error: "Error al generar la letra. Inténtalo de nuevo." },
      { status: 500 }
    );
  }
}
