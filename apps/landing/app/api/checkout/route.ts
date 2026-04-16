import { NextResponse } from 'next/server';
import Stripe from 'stripe';

// Forzamos a Next.js a no intentar pre-renderizar esta ruta en Vercel
export const dynamic = 'force-dynamic';

export async function POST(req: Request) {
    try {
        if (!process.env.STRIPE_SECRET_KEY) {
            throw new Error('La variable STRIPE_SECRET_KEY no está configurada en Vercel.');
        }

        const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
            apiVersion: '2026-03-25.dahlia',
        });
        
        const body = await req.json();
        
        // Parse the origin from the request to set valid success/cancel URLs
        const origin = req.headers.get('origin') || 'http://localhost:3000';

        const lyricsRaw = String(body.lyrics || '');
        const lyricsMetadata: Record<string, string> = {};
        
        // Stripe limita cada campo de metadatos a 500 caracteres.
        // Cortamos la letra en fragmentos de 450 y la guardamos en lyrics_part_1, lyrics_part_2...
        const chunkSize = 450;
        for (let i = 0; i < lyricsRaw.length && i < chunkSize * 20; i += chunkSize) {
            const chunkIndex = Math.floor(i / chunkSize) + 1;
            lyricsMetadata[`lyrics___parte_${chunkIndex}`] = lyricsRaw.substring(i, i + chunkSize);
        }

        const safeMetadata = {
            name: String(body.name || '').substring(0, 500),
            email: String(body.email || '').substring(0, 500),
            genre: String(body.genre || '').substring(0, 500),
            customGenre: String(body.customGenre || '').substring(0, 500),
            vocalist: String(body.vocalist || '').substring(0, 500),
            mood: String(body.mood || '').substring(0, 500),
            referenceTrack: String(body.referenceTrack || '').substring(0, 500),
            notes: String(body.notes || '').substring(0, 500),
            phone: String(body.phone || '').substring(0, 500),
            plan: String(body.plan || 'Starter').substring(0, 500),
            ...lyricsMetadata
        };

        const finalPrice = [50, 97, 147].includes(Number(body.price)) ? Number(body.price) : 50;

        const session = await stripe.checkout.sessions.create({
            payment_method_types: ['card'],
            customer_email: body.email,
            line_items: [
                {
                    price_data: {
                        currency: 'usd',
                        product_data: {
                            name: `Plan ${body.plan || 'Starter'} - Struky AI`,
                            description: 'Tu producción musical personalizada con calidad internacional.',
                        },
                        unit_amount: finalPrice * 100,
                    },
                    quantity: 1,
                },
            ],
            mode: 'payment',
            success_url: `${origin}/success?session_id={CHECKOUT_SESSION_ID}`,
            cancel_url: `${origin}?canceled=true`,
            metadata: safeMetadata,
            payment_intent_data: {
                metadata: safeMetadata,
            }
        });

        return NextResponse.json({ url: session.url });
    } catch (err: any) {
        console.error('Error creating Stripe session:', err);
        return NextResponse.json(
            { error: 'Error al procesar el pago. Revisa las claves de Stripe.' },
            { status: 500 }
        );
    }
}
