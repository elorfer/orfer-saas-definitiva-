import { createClient } from '@/utils/supabase/server';
import { NextResponse } from 'next/server';
import { google } from '@ai-sdk/google';
import { generateText } from 'ai';

export const dynamic = 'force-dynamic';

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    
    // 1. Validar autenticación
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: 'No autorizado' }, { status: 401 });
    }

    // 2. Leer parámetros del cuerpo (el área del reto)
    const { area } = await request.json();
    if (!area) {
      return NextResponse.json({ error: 'El área es requerida' }, { status: 400 });
    }

    const areaName = {
      dinero: 'Dinero y Abundancia Financiera',
      amor: 'Amor Propio y Relaciones Ideales',
      salud: 'Salud, Vitalidad y Bienestar Físico',
      exito: 'Éxito Profesional y Metas Personales',
      confianza: 'Confianza y Autoestima Cuántica',
      abundancia: 'Abundancia Infinita y Mentalidad de Prosperidad'
    }[area as string] || area;

    // 3. Crear el Prompt para Gemini para generar los 30 días de forma estructurada en JSON
    const prompt = `Genera un plan o reto de manifestación y reprogramación mental cuántica de 30 días para el área de: "${areaName}".
El tono del plan debe ser de alta vibración, místico pero práctico, y sumamente motivador.
Cada día del reto debe tener una afirmación corta y de gran fuerza, y una micro-acción física alineada y sumamente práctica que el usuario pueda hacer ese día.

Ejemplo de micro-acción para Dinero: "Limpia tu billetera de recibos viejos para hacer espacio energético para la abundancia."
Ejemplo de micro-acción para Amor: "Mírate fijamente en el espejo durante 1 minuto y di en voz alta tres cosas específicas que te encantan de ti."

Debes responder ÚNICAMENTE con un objeto JSON que contenga un array llamado "days", donde cada elemento represente un día del 1 al 30, con el formato exacto:
{
  "days": [
    { "day": 1, "affirmation": "...", "action": "..." },
    { "day": 2, "affirmation": "...", "action": "..." },
    ...
    { "day": 30, "affirmation": "...", "action": "..." }
  ]
}

No añadas explicaciones, introducciones, ni textos aclaratorios antes o después del JSON. Devuelve únicamente el objeto JSON válido.`;

    // 4. Llamar a Gemini 2.5 Flash
    const { text } = await generateText({
      model: google('gemini-2.5-flash'),
      prompt: prompt,
    });

    let challengeContent;
    try {
      // Limpiar texto si Gemini añade bloques de código de markdown (```json ... ```)
      const cleanJsonStr = text.replace(/```json/g, '').replace(/```/g, '').trim();
      challengeContent = JSON.parse(cleanJsonStr);
    } catch (parseErr) {
      console.error("Error al parsear el JSON generado por Gemini:", text);
      return NextResponse.json({ error: "La IA generó una respuesta inválida. Por favor, intenta de nuevo." }, { status: 502 });
    }

    if (!challengeContent.days || !Array.isArray(challengeContent.days) || challengeContent.days.length === 0) {
      return NextResponse.json({ error: "La estructura del reto generada por la IA es incorrecta." }, { status: 502 });
    }

    // 5. Guardar o actualizar el reto en Supabase
    // Para simplificar, si ya tiene un reto activo en esa área, lo eliminamos primero o actualizamos.
    // Vamos a eliminar cualquier reto que tenga este usuario para este área antes de insertar el nuevo para evitar duplicados.
    await supabase
      .from('challenges')
      .delete()
      .eq('user_id', user.id)
      .eq('area', area);

    const { data, error: insertError } = await supabase
      .from('challenges')
      .insert([
        {
          user_id: user.id,
          area: area,
          content: challengeContent.days,
          completed_days: {}
        }
      ])
      .select()
      .single();

    if (insertError) {
      throw insertError;
    }

    return NextResponse.json(data);

  } catch (err: any) {
    console.error("Error en API de generación de reto:", err);
    return NextResponse.json({ error: err.message || 'Error interno del servidor' }, { status: 500 });
  }
}
