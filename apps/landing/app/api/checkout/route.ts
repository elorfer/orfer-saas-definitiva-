import { NextResponse } from 'next/server';
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY as string, {
    apiVersion: '2025-02-24.acacia',
});

export async function POST(req: Request) {
    try {
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
            ...lyricsMetadata
        };

        const session = await stripe.checkout.sessions.create({
            payment_method_types: ['card'],
            customer_email: body.email,
            line_items: [
                {
                    price_data: {
                        currency: 'usd',
                        product_data: {
                            name: 'Producción Musical Struky AI',
                            description: 'Tu canción masterizada profesionalmente en 24-48 hrs.',
                        },
                        unit_amount: 5000, // $50.00 USD
                    },
                    quantity: 1,
                },
            ],
            mode: 'payment',
            success_url: `${origin}/success`,
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
