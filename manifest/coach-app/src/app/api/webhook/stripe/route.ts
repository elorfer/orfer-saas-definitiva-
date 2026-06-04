import { NextResponse } from 'next/server';
import Stripe from 'stripe';
import { createClient } from '@supabase/supabase-js';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || '', {
  apiVersion: '2023-10-16' as any,
});

export async function POST(req: Request) {
  const body = await req.text();
  const signature = req.headers.get('stripe-signature');

  if (!signature || !process.env.STRIPE_WEBHOOK_SECRET || process.env.STRIPE_WEBHOOK_SECRET === 'whsec_mocksecret') {
    return NextResponse.json({ error: 'Webhook secret o firma faltante / por defecto' }, { status: 400 });
  }

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(body, signature, process.env.STRIPE_WEBHOOK_SECRET);
  } catch (err: any) {
    console.error(`Error de verificación de firma de Stripe: ${err.message}`);
    return NextResponse.json({ error: `Firma inválida: ${err.message}` }, { status: 400 });
  }

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseServiceKey) {
    console.error('Falta la variable SUPABASE_SERVICE_ROLE_KEY en el servidor.');
    return NextResponse.json({ error: 'Configuración de base de datos administrativa incompleta en el servidor.' }, { status: 500 });
  }

  // Crear cliente administrador de Supabase para saltar políticas RLS de forma segura en backend
  const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    }
  });

  try {
    // 1. Pago inicial completado de forma exitosa
    if (event.type === 'checkout.session.completed') {
      const session = event.data.object as Stripe.Checkout.Session;
      const userId = session.metadata?.user_id;

      if (!userId) {
        console.error('No se encontró user_id en los metadatos de la sesión de Stripe');
        return NextResponse.json({ error: 'User ID no especificado en metadatos' }, { status: 400 });
      }

      // Actualizar el perfil del usuario a PRO
      const { error } = await supabaseAdmin
        .from('profiles')
        .update({ subscription_tier: 'pro' })
        .eq('id', userId);

      if (error) throw error;
      console.log(`[Stripe Webhook] Suscripción PRO activada para el usuario ${userId}`);
    } 
    
    // 2. Suscripción cancelada / expirada
    else if (event.type === 'customer.subscription.deleted') {
      const subscription = event.data.object as Stripe.Subscription;
      const userId = subscription.metadata?.user_id;

      if (!userId) {
        console.error('No se encontró user_id en los metadatos de la suscripción de Stripe');
        return NextResponse.json({ error: 'User ID no especificado en metadatos de suscripción' }, { status: 400 });
      }

      // Degradación del usuario a FREE
      const { error } = await supabaseAdmin
        .from('profiles')
        .update({ subscription_tier: 'free' })
        .eq('id', userId);

      if (error) throw error;
      console.log(`[Stripe Webhook] Suscripción cancelada. Usuario ${userId} degradado a plan gratuito.`);
    }

    return NextResponse.json({ received: true });
  } catch (err: any) {
    console.error('Error al procesar webhook de Stripe:', err);
    return NextResponse.json({ error: err.message || 'Error interno del servidor' }, { status: 500 });
  }
}
