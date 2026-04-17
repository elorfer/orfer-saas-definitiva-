import { NextResponse } from 'next/server';
import crypto from 'crypto';

// Replicamos la lógica del webhook para una prueba aislada
function hashData(data: string) {
    if (!data) return '';
    return crypto.createHash('sha256').update(data.trim().toLowerCase()).digest('hex');
}

export async function GET() {
    const pixelId = process.env.NEXT_PUBLIC_META_PIXEL_ID || '1445433937281922';
    const accessToken = process.env.META_ACCESS_TOKEN;
    const testCode = process.env.META_TEST_CODE || 'TEST29760';

    if (!accessToken) {
        return NextResponse.json({ error: 'META_ACCESS_TOKEN no configurada en Vercel' }, { status: 500 });
    }

    const mockEmail = 'test_cliente@struky.com';
    const mockPhone = '+573000000000';
    const eventId = 'test_id_' + Date.now();

    const payload = {
        data: [
            {
                event_name: 'Purchase',
                event_time: Math.floor(Date.now() / 1000),
                event_id: eventId,
                event_source_url: 'https://www.struky.com/success',
                action_source: 'website',
                user_data: {
                    em: [hashData(mockEmail)],
                    ph: [hashData(mockPhone)],
                    client_ip_address: '127.0.0.1',
                    client_user_agent: 'StrukyTestBot/1.0'
                },
                custom_data: {
                    value: 97.00,
                    currency: 'USD',
                    content_name: 'Plan Pro Master (SIMULACIÓN)',
                    content_category: 'Music Production'
                }
            }
        ],
        test_event_code: testCode
    };

    try {
        const response = await fetch(`https://graph.facebook.com/v19.0/${pixelId}/events?access_token=${accessToken}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const result = await response.json();
        
        return NextResponse.json({
            message: 'Simulación enviada a Meta',
            result,
            eventId,
            note: 'Si el resultado dice fbtrace_id, Meta recibió el evento. Revisa tu panel de Probar Eventos.'
        });
    } catch (err: any) {
        return NextResponse.json({ error: err.message }, { status: 500 });
    }
}
