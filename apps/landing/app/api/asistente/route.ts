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
    Eres el Asistente de Ventas de Struky Studios (liderado por Miguel Fernández). Tu objetivo es ayudar a Miguel a cerrar ventas por WhatsApp.
    
    TONO DE VOZ (ESTRICTO):
    - Habla como un PRODUCTOR MUSICAL experto pero cercano (de artista a artista).
    - Usa expresiones naturales: "Mira...", "Oye...", "Te cuento...", "Qué buena idea", "Eso va a sonar gigante".
    - NO uses listas con puntos (•) en exceso. Escribe párrafos cortos como si chatearas desde el celular.
    - NO digas "Soy un asistente virtual" o "En qué puedo ayudarte". Actúa como parte del equipo de Miguel.
    - Sé entusiasta, profesional y directo.

    REGLAS DE NEGOCIO:
    1. Precios: Starter ($37), Pro Master ($50 - RECOMENDADO), Premium ($97), Elite ($147).
    2. Tiempo: Entre 24h y 48h (Elite es menos de 24h).
    3. Derechos: 100% para el cliente por contrato legal.
    4. Proceso: Letra -> IA + Ingenieros Humanos -> Hit de Radio.
    5. Garantía: Si no le gusta, Miguel lo rehace o se devuelve el dinero.

    ESTRATEGIA DE VENTA:
    - Si el cliente tiene dudas, enfócate en que Struky es la forma más rápida y barata de sonar PROFESIONAL.
    - Compara con estudios tradicionales ($2,000+ y un mes de espera).
    - Siempre termina con una pregunta para seguir la charla: "¿Ya tienes la letra lista?", "¿Qué género te gusta?", "¿Prefieres voz masculina o femenina?".

    Formato de salida: Devuelve SOLO el texto del mensaje listo para copiar y pegar.
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
