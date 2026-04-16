import { NextResponse } from 'next/server';
import Stripe from 'stripe';
import { Resend } from 'resend';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_dummy', {
    apiVersion: '2026-03-25.dahlia',
});

const resend = new Resend(process.env.RESEND_API_KEY || 're_dummy_key');

export async function POST(req: Request) {
    const body = await req.text();
    const signature = req.headers.get('stripe-signature');

    let event: Stripe.Event;

    try {
        if (!signature || !process.env.STRIPE_WEBHOOK_SECRET) {
            console.error('Missing signature or webhook secret');
            return NextResponse.json({ error: 'Webhook Secret not configured' }, { status: 400 });
        }
        event = stripe.webhooks.constructEvent(body, signature, process.env.STRIPE_WEBHOOK_SECRET);
    } catch (err: any) {
        console.error(`Webhook signature verification failed: ${err.message}`);
        return NextResponse.json({ error: 'Invalid signature' }, { status: 400 });
    }

    if (event.type === 'checkout.session.completed') {
        const session = event.data.object as Stripe.Checkout.Session;
        const metadata = session.metadata || {};

        // Reconstruir la letra desde las partes
        const lyricsParts = Object.keys(metadata)
            .filter(key => key.startsWith('lyrics___parte_'))
            .sort((a, b) => {
                const numA = parseInt(a.split('_').pop() || '0');
                const numB = parseInt(b.split('_').pop() || '0');
                return numA - numB;
            })
            .map(key => metadata[key]);
        
        const fullLyrics = lyricsParts.join('');
        const plan = metadata.plan || 'Premium';

        try {
            // 1. Enviar email al administrador (Struky Team)
            await resend.emails.send({
                from: 'Struky Orders <orders@resend.dev>',
                to: 'strukyapp@gmail.com',
                subject: `🔥 ¡NUEVO PEDIDO: ${plan}! - ${metadata.name}`,
                html: `
                    <div style="font-family: sans-serif; background-color: #050505; color: #ffffff; padding: 40px; border-radius: 24px; border: 1px solid #1a1a1a;">
                        <h1 style="color: #caa052; font-size: 24px; margin-bottom: 8px;">🚀 Nueva Venta en Struky</h1>
                        <p style="color: #666; font-size: 14px; margin-bottom: 32px;">Se ha completado un pago exitoso de ${session.amount_total! / 100} USD</p>
                        
                        <div style="background: #111; padding: 24px; border-radius: 16px; margin-bottom: 24px; border: 1px solid #222;">
                            <h3 style="color: #caa052; font-size: 12px; text-transform: uppercase; margin-bottom: 16px;">Detalles del Cliente</h3>
                            <p style="margin: 4px 0;"><strong>Nombre:</strong> ${metadata.name}</p>
                            <p style="margin: 4px 0;"><strong>Email:</strong> ${metadata.email}</p>
                            <p style="margin: 4px 0;"><strong>WhatsApp:</strong> ${metadata.phone}</p>
                            <p style="margin: 4px 0;"><strong>Plan:</strong> <span style="color: #caa052;">${plan}</span></p>
                        </div>

                        <div style="background: #111; padding: 24px; border-radius: 16px; margin-bottom: 24px; border: 1px solid #222;">
                            <h3 style="color: #caa052; font-size: 12px; text-transform: uppercase; margin-bottom: 16px;">Detalles Artísticos</h3>
                            <p style="margin: 4px 0;"><strong>Género:</strong> ${metadata.genre}</p>
                            <p style="margin: 4px 0;"><strong>Voz:</strong> ${metadata.vocalist}</p>
                            <p style="margin: 4px 0;"><strong>Mood:</strong> ${metadata.mood}</p>
                        </div>

                        <div style="background: #111; padding: 24px; border-radius: 16px; border: 1px solid #222;">
                            <h3 style="color: #caa052; font-size: 12px; text-transform: uppercase; margin-bottom: 16px;">Letra del Cliente</h3>
                            <pre style="white-space: pre-wrap; color: #ccc; font-size: 14px; line-height: 1.6;">${fullLyrics || 'Sin letra'}</pre>
                        </div>
                    </div>
                `
            });

            // 2. Enviar email de bienvenida al CLIENTE
            await resend.emails.send({
                from: 'Struky Music <orders@resend.dev>',
                to: metadata.email,
                subject: `🎧 ¡Tu producción en Struky ha comenzado, ${metadata.name}!`,
                html: `
                    <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; background-color: #050505; color: #ffffff; padding: 40px; border-radius: 24px;">
                        <div style="text-align: center; margin-bottom: 40px;">
                             <h1 style="color: #caa052; font-size: 32px; font-weight: 900; letter-spacing: -1px; margin: 0;">STRUKY</h1>
                             <p style="color: #666; font-size: 12px; text-transform: uppercase; letter-spacing: 2px;">Premium AI Music Production</p>
                        </div>

                        <h2 style="font-size: 24px; text-align: center; margin-bottom: 24px;">¡Hola, ${metadata.name}! 👋</h2>
                        
                        <p style="color: #ccc; line-height: 1.8; text-align: center; font-size: 16px;">
                            Gracias por confiar en Struky. Hemos recibido correctamente tu pedido del <strong>Plan ${plan}</strong> y nuestro equipo ya está manos a la obra con tus letras.
                        </p>

                        <div style="background: #111; border: 1px solid #caa05250; padding: 30px; border-radius: 20px; margin: 40px 0; text-align: center;">
                            <h3 style="color: #caa052; margin-top: 0;">¿Qué sigue ahora?</h3>
                            <p style="font-size: 14px; color: #888;">Nuestros productores están iterando con la IA para lograr la mayor calidad posible.</p>
                            <div style="margin-top: 20px; color: #fff; font-weight: bold; font-size: 18px;">
                                ⏱️ Entrega estimada: 24-48 horas
                            </div>
                        </div>

                        <p style="color: #666; font-size: 12px; text-align: center;">
                            Recibirás tu canción final directamente en tu WhatsApp y correo electrónico. ¡Prepárate para sonar profesional!
                        </p>

                        <hr style="border: 0; border-top: 1px solid #222; margin: 40px 0;" />

                        <p style="color: #444; font-size: 10px; text-align: center; text-transform: uppercase; letter-spacing: 1px;">
                            © 2026 Struky Music AI. Todos los derechos reservados.
                        </p>
                    </div>
                `
            });

            console.log('Admin and Customer emails sent successfully for session:', session.id);
        } catch (emailErr) {
            console.error('Error sending email notifications:', emailErr);
        }
    }

    return NextResponse.json({ received: true });
}
