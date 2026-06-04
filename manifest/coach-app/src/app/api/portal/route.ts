import { NextResponse } from 'next/server';
import { createClient } from '@/utils/supabase/server';
import Stripe from 'stripe';

export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
  try {
    const supabase = await createClient();
    const { data: { user }, error: userError } = await supabase.auth.getUser();

    if (userError || !user || !user.email) {
      return NextResponse.json({ error: 'No autorizado' }, { status: 401 });
    }

    const stripeSecret = process.env.STRIPE_SECRET_KEY;
    if (!stripeSecret || stripeSecret === 'sk_test_mockkey') {
      return NextResponse.json({ 
        error: 'STRIPE_SECRET_KEY no está configurada o tiene el valor por defecto.' 
      }, { status: 500 });
    }

    const stripe = new Stripe(stripeSecret, {
      apiVersion: '2023-10-16' as any,
    });

    const origin = req.headers.get('origin') || 'http://localhost:3000';

    // Buscar el cliente en Stripe utilizando su correo de Supabase
    const customers = await stripe.customers.list({
      email: user.email,
      limit: 1,
    });

    if (customers.data.length === 0) {
      return NextResponse.json({ 
        error: 'No se encontró un cliente asociado a este correo en Stripe. Si acabas de suscribirte, espera unos segundos.' 
      }, { status: 404 });
    }

    const customerId = customers.data[0].id;

    // Crear sesión del portal de Stripe para que el usuario gestione su suscripción
    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: `${origin}/app`,
    });

    return NextResponse.json({ url: session.url });
  } catch (err: any) {
    console.error('Error al crear sesión de portal de Stripe:', err);
    return NextResponse.json({ error: err.message || 'Error interno del servidor' }, { status: 500 });
  }
}
