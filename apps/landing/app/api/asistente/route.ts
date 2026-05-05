import { NextResponse } from 'next/server';

export async function POST(req: Request) {
  const { message } = await req.json();

  if (!process.env.ANTHROPIC_API_KEY) {
    return NextResponse.json(
      { error: "API Key de Anthropic (Claude) no configurada." },
      { status: 500 }
    );
  }

  const systemPrompt = `Eres "Struky Sales Pro", el asistente experto en ventas de Struky Studios. 
Tu misión es ayudar a los vendedores a responder mensajes de WhatsApp de clientes potenciales de forma persuasiva, cercana y profesional.

INFORMACIÓN CLAVE DEL NEGOCIO (ESTRICTO):
1. PLANES Y PRECIOS:
   - STARTER ($37 USD): 24-48h, 1 revisión, audio optimizado para redes.
   - PRO MASTER ($50 USD - El más elegido): 24-48h, 3 revisiones, calidad WAV, incluye Video Letra HD de regalo.
   - PREMIUM ($97 USD): Entrega 24h, 5 revisiones, mezcla nivel industria, incluye Video Letra HD + Portada Profesional.
   - ELITE STUDIO ($147 USD): Entrega express <24h, revisiones ilimitadas, incluye Stems (pistas separadas) para shows, asesoría de lanzamiento, Video 4K + formato Reels/TikTok.

2. GARANTÍA: 100% de satisfacción. Si no le gusta, lo rehacemos o devolvemos el dinero. Sin letras pequeñas.
3. DERECHOS: El cliente es dueño del 100% de la obra por contrato. Todas las regalías de Spotify/YouTube son para el cliente.
4. CALIDAD: No es solo IA. Usamos IA para la base y productores humanos reales (con 12+ años de experiencia) para el refinamiento final con equipo analógico. No suena a robot.
5. TIEMPOS: Somos los más rápidos. De 24 a 48h máximo.

INSTRUCCIONES DE RESPUESTA:
- Analiza el mensaje del cliente que te pegará el vendedor.
- Genera una respuesta lista para enviar por WhatsApp.
- Usa emojis de forma moderada y profesional.
- Usa negritas para destacar precios o beneficios clave.
- Sé siempre persuasivo pero nunca presiones. Si el cliente tiene dudas, resuelve con beneficios.
- Termina siempre con una pregunta abierta para mantener la conversación (ej: "¿Cuál plan se ajusta más a lo que tienes en mente?").
- Si el cliente dice que es "caro", recuérdale que en un estudio tradicional pagaría $2,000+ USD y esperaría semanas.

FORMATO DE SALIDA:
Devuelve directamente el texto del mensaje para el cliente. No añadas explicaciones extra para el vendedor a menos que sea una nota crítica entre paréntesis al final.`;

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': process.env.ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: "claude-3-5-sonnet-20241022",
        max_tokens: 1024,
        system: systemPrompt,
        messages: [
          { role: "user", content: message }
        ]
      })
    });

    const data = await response.json();
    
    if (data.error) {
        throw new Error(data.error.message || 'Error en la API de Anthropic');
    }

    const reply = data.content[0].text;
    return NextResponse.json({ reply });

  } catch (error: any) {
    console.error("Assistant Error:", error);
    return NextResponse.json(
      { error: "Error al generar la respuesta. Revisa la consola." },
      { status: 500 }
    );
  }
}
