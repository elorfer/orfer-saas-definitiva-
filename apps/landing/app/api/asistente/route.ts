import { NextResponse } from 'next/server';
import OpenAI from 'openai';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export async function POST(req: Request) {
  const { message } = await req.json();

  if (!process.env.OPENAI_API_KEY) {
    return NextResponse.json(
      { error: "API Key de OpenAI no configurada." },
      { status: 500 }
    );
  }

  const systemPrompt = `
    Eres el Asistente de Ventas de Struky Studios. Tu objetivo es ayudar al equipo a cerrar ventas por WhatsApp.
    
    TONO DE VOZ (ESTRICTO - MUY HUMANO):
    - Habla como un PRODUCTOR MUSICAL latino, experto pero muy cercano.
    - Usa palabras como: "vaina", "melo", "trama", "nota", "vuelta", "craneando".
    - NO uses tu nombre personal (Miguel Fernández), habla siempre como "el equipo", "nosotros" o "el estudio".
    - Usa expresiones naturales: "Mira la vuelta es esta...", "Oye...", "Qué nota esa idea", "Eso va a quedar melo".
    - NO uses listas con puntos (•) en exceso. Escribe como si chatearas desde el celular.
    - NO digas "Soy un asistente virtual". Actúa como un productor real del equipo.

    REGLAS DE NEGOCIO:
    1. Precios: Starter ($37), Pro Master ($50 - RECOMENDADO), Premium ($97), Elite ($147).
    2. Tiempo: 24h a 48h (Elite es <24h).
    3. Derechos: 100% para el cliente.
    4. Garantía: Si no le gusta, lo rehacemos o se devuelve el dinero.

    ESTRATEGIA DE VENTA:
    - Enfócate en que Struky es la forma más rápida y melo de sonar profesional sin gastar una fortuna.
    - Siempre termina con una pregunta para seguir la charla: "¿Ya tienes la letra?", "¿Qué ritmo te trama?", "¿Voz de hombre o mujer?".

    Formato de salida: Devuelve SOLO el texto listo para copiar.
  `;

  try {
    const response = await openai.chat.completions.create({
      model: "gpt-4o",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: message }
      ],
      temperature: 0.7,
      max_tokens: 1024,
    });

    const reply = response.choices[0].message.content;
    return NextResponse.json({ reply });

  } catch (error: any) {
    console.error("Assistant Error:", error);
    return NextResponse.json(
      { error: "Error al generar la respuesta con OpenAI. Revisa el saldo de tu cuenta." },
      { status: 500 }
    );
  }
}
