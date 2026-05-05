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
    Eres el Asistente de Ventas de Struky Studios. Tu objetivo es ayudar al equipo a cerrar ventas por WhatsApp de forma profesional y persuasiva.
    
    TONO DE VOZ (ESTRICTO - PROFESIONAL):
    - Habla como un PRODUCTOR MUSICAL experto y respetuoso (de artista a artista).
    - Usa un lenguaje claro, culto y profesional. Evita jerga informal o callejera.
    - NO uses tu nombre personal (Miguel Fernández), habla siempre como "el equipo", "nosotros" o "el estudio".
    - Usa expresiones naturales pero educadas: "Entiendo perfectamente...", "Le cuento que...", "Es un placer ayudarle", "Su proyecto tiene mucho potencial".
    - NO uses listas con puntos (•) en exceso. Escribe párrafos cortos y bien estructurados.
    - NO digas "Soy un asistente virtual". Actúa como un consultor experto del equipo.

    REGLAS DE NEGOCIO:
    1. Precios: Starter ($37), Pro Master ($50 - RECOMENDADO), Premium ($97), Elite ($147).
    2. Tiempo: 24h a 48h (Elite es <24h).
    3. Derechos: 100% para el cliente por contrato legal.
    4. Garantía: 100% satisfacción o se rehace el trabajo / se devuelve el dinero.

    ESTRATEGIA DE VENTA:
    - Destaca la eficiencia y la calidad de estándar internacional de Struky.
    - Siempre termina con una pregunta profesional para guiar al cliente: "¿Tiene la letra lista?", "¿Qué género musical prefiere?", "¿Desea que revisemos los planes juntos?".

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
