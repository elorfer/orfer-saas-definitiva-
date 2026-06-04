import { NextResponse } from 'next/server';
import { createClient } from '@/utils/supabase/server';
import Stripe from 'stripe';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user }, error: userError } = await supabase.auth.getUser();

    if (userError || !user) {
      return NextResponse.json({ error: 'No autorizado' }, { status: 401 });
    }

    const stripeSecret = process.env.STRIPE_SECRET_KEY;
    if (!stripeSecret || stripeSecret === 'sk_test_mockkey') {
      return NextResponse.json({ 
        error: 'STRIPE_SECRET_KEY no está configurada o tiene el valor por defecto. Por favor actualiza tu archivo .env.local.' 
      }, { status: 500 });
    }

    const stripe = new Stripe(stripeSecret, {
      apiVersion: '2023-10-16' as any,
    });

    const origin = req.headers.get('origin') || 'http://localhost:3000';

    const priceId = process.env.STRIPE_PRICE_ID;
    if (!priceId || priceId === 'price_mockid') {
      return NextResponse.json({ 
        error: 'STRIPE_PRICE_ID no está configurada en .env.local. Crea un producto de suscripción recurrente en el dashboard de Stripe (modo prueba) y copia su Price ID.' 
      }, { status: 400 });
    }

    // Crear la sesión de checkout en Stripe para suscripción mensual
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      customer_email: user.email,
      line_items: [
        {
          price: priceId,
          quantity: 1,
        },
      ],
      mode: 'subscription',
      success_url: `${origin}/app?checkout=success`,
      cancel_url: `${origin}/paywall?checkout=cancel`,
      metadata: {
        user_id: user.id,
      },
      subscription_data: {
        metadata: {
          user_id: user.id,
        }
      }
    });

    return NextResponse.json({ url: session.url });
  } catch (err: any) {
    console.error('Error al crear sesión de checkout:', err);
    return NextResponse.json({ error: err.message || 'Error interno del servidor' }, { status: 500 });
  }
}
