import { NextResponse } from 'next/server';
import crypto from 'crypto';

export const dynamic = 'force-dynamic';

function hashData(data: string) {
    if (!data) return '';
    return crypto.createHash('sha256').update(data.trim().toLowerCase()).digest('hex');
}

export async function GET() {
    const pixelId = process.env.NEXT_PUBLIC_META_PIXEL_ID || '1445433937281922';
    const accessToken = process.env.META_ACCESS_TOKEN;

    // Diagnóstico de variables
    const diagnostics: any = {
        pixelId,
        hasAccessToken: !!accessToken,
        accessTokenLength: accessToken?.length || 0,
        accessTokenPreview: accessToken ? `${accessToken.substring(0, 8)}...${accessToken.substring(accessToken.length - 4)}` : 'NOT SET',
        nodeEnv: process.env.NODE_ENV,
    };

    if (!accessToken) {
        return NextResponse.json({
            error: 'META_ACCESS_TOKEN not configured',
            diagnostics
        }, { status: 500 });
    }

    // Evento de prueba
    const testEventId = `test_capi_${Date.now()}`;
    const payload = {
        data: [
            {
                event_name: 'InitiateCheckout',
                event_time: Math.floor(Date.now() / 1000),
                event_id: testEventId,
                event_source_url: 'https://www.struky.com/',
                action_source: 'website',
                user_data: {
                    em: [hashData('test@struky.com')],
                    ph: [hashData('1234567890')],
                    client_ip_address: '8.8.8.8',
                    client_user_agent: 'StrukyDebug/1.0'
                },
                custom_data: {
                    value: 1,
                    currency: 'USD',
                    content_name: 'Test CAPI Debug'
                }
            }
        ],
        // Modo TEST para que no contamine tus métricas reales
        test_event_code: 'TEST18020'
    };

    const url = `https://graph.facebook.com/v19.0/${pixelId}/events?access_token=${accessToken}`;

    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        const result = await response.json();

        return NextResponse.json({
            success: response.ok,
            httpStatus: response.status,
            metaResponse: result,
            sentPayload: {
                ...payload,
                data: payload.data.map(d => ({
                    ...d,
                    user_data: '(hashed - omitted for security)'
                }))
            },
            requestUrl: `https://graph.facebook.com/v19.0/${pixelId}/events`,
            diagnostics,
            testEventId
        });
    } catch (err: any) {
        return NextResponse.json({
            error: 'Fetch failed',
            message: err.message,
            diagnostics
        }, { status: 500 });
    }
}
