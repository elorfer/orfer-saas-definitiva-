import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import Stripe from 'stripe';
import { sendMetaEvent } from '@/lib/meta-capi';

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
        const phoneClean = String(body.phone || '').replace(/\D/g, '');

        // --- META CAPI: InitiateCheckout ---
        const userAgent = req.headers.get('user-agent') || '';
        const ip = req.headers.get('x-forwarded-for')?.split(',')[0] || req.headers.get('x-real-ip') || '';
        
        // Vercel Geolocation Headers
        const city = req.headers.get('x-vercel-ip-city') || '';
        const country = req.headers.get('x-vercel-ip-country') || '';
        const state = req.headers.get('x-vercel-ip-country-region') || '';

        // Extraer cookies de Meta (preferir las enviadas desde el cliente para mayor precisión)
        const cookieStore = await cookies();
        const fbp = body.fbp || cookieStore.get('_fbp')?.value;
        const fbc = body.fbc || cookieStore.get('_fbc')?.value || '';
        // NOTE: Do NOT fabricate fbc server-side with Date.now().
        // Meta flags any fbc whose timestamp doesn't match the original landing time
        // as "modified fbclid". The fbc must come from the client cookie/localStorage
        // where it was created with the correct timestamp when the user first landed.

        // Esperamos el evento para asegurar que Vercel no mate el proceso antes de enviarlo
        let capiResult: any = null;
        let capiError: string | null = null;
        try {
            capiResult = await sendMetaEvent({
                eventName: 'InitiateCheckout',
                eventID: body.metaEventId,
                userData: {
                    email: body.email,
                    phone: phoneClean,
                    firstName: body.name,
                    fbp,
                    fbc,
                    clientIpAddress: ip,
                    clientUserAgent: userAgent,
                    externalId: body.email?.toLowerCase().trim(), // EMAIL como ID externo para InitiateCheckout
                    city,
                    state,
                    country
                },
                customData: {
                    value: Number(body.price) || 50,
                    currency: 'USD',
                    content_name: `Plan ${body.plan || 'Starter'}`,
                    content_category: 'Music Production'
                },
                sourceUrl: req.headers.get('referer') || 'https://www.struky.com/'
            });
            console.log('✅ CAPI InitiateCheckout result:', JSON.stringify(capiResult));
        } catch (err: any) {
            capiError = err.message;
            console.error('❌ CAPI InitiateCheckout error:', err);
        }
        // ------------------------------------

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
            phone: phoneClean.substring(0, 500),
            plan: String(body.plan || 'Starter').substring(0, 500),
            fbp: String(fbp || '').substring(0, 500),
            fbc: String(fbc || '').substring(0, 500),
            clientIp: String(ip || '').substring(0, 500),
            userAgent: String(userAgent || '').substring(0, 500),
            city: String(city || '').substring(0, 500),
            state: String(state || '').substring(0, 500),
            country: String(country || '').substring(0, 500),
            ...lyricsMetadata
        };

        const songQuantity = Math.min(Math.max(Math.round(Number(body.songQuantity) || 1), 1), 10);
        const unitPrice = [37, 50, 97, 147, 250].includes(Number(body.unitPrice)) ? Number(body.unitPrice) : 37;
        
        // Server-side discount validation: Flat 10% if 3 or more songs
        const discountPercent = songQuantity >= 3 ? 10 : 0;
        const unitPriceWithDiscount = unitPrice * (1 - discountPercent / 100);
        const calculatedTotal = Math.ceil(unitPriceWithDiscount * songQuantity);
        const finalPrice = calculatedTotal;

        const songLabel = songQuantity > 1 ? `${songQuantity}x ` : '';
        const discountLabel = discountPercent > 0 ? ` (-${discountPercent}%)` : '';

        const session = await stripe.checkout.sessions.create({
            payment_method_types: ['card'],
            customer_email: body.email,
            line_items: [
                {
                    price_data: {
                        currency: 'usd',
                        product_data: {
                            name: `${songLabel}Plan ${body.plan || 'Starter'} - Struky AI${discountLabel}`,
                            description: songQuantity > 1
                                ? `${songQuantity} producciones musicales personalizadas con ${discountPercent}% de descuento.`
                                : 'Tu producción musical personalizada con calidad internacional.',
                        },
                        unit_amount: Math.round(finalPrice * 100),
                    },
                    quantity: 1,
                },
            ],
            mode: 'payment',
            success_url: `${origin}/success?session_id={CHECKOUT_SESSION_ID}`,
            cancel_url: `${origin}?canceled=true`,
            metadata: {
                ...safeMetadata,
                songQuantity: String(songQuantity),
                unitPrice: String(unitPrice),
                discountPercent: String(discountPercent),
                totalPrice: String(finalPrice),
            },
            payment_intent_data: {
                metadata: {
                    ...safeMetadata,
                    songQuantity: String(songQuantity),
                    unitPrice: String(unitPrice),
                    discountPercent: String(discountPercent),
                    totalPrice: String(finalPrice),
                },
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
