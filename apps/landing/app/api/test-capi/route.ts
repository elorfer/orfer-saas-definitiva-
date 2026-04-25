import { NextResponse } from 'next/server';
import { sendMetaEvent } from '@/lib/meta-capi';

export const dynamic = 'force-dynamic';

export async function GET() {
    const testEventId = `test_real_${Date.now()}`;

    try {
        // Usar EXACTAMENTE la misma función que usa checkout/route.ts
        const result = await sendMetaEvent({
            eventName: 'InitiateCheckout',
            eventID: testEventId,
            userData: {
                email: 'debug@struky.com',
                phone: '+1 5551234567',
                fbp: undefined,
                fbc: undefined,
                clientIpAddress: '8.8.8.8',
                clientUserAgent: 'StrukyDebugReal/1.0'
            },
            customData: {
                value: 1,
                currency: 'USD',
                content_name: 'Plan Debug',
                content_category: 'Music Production'
            },
            sourceUrl: 'https://www.struky.com/'
        });

        return NextResponse.json({
            success: true,
            metaResponse: result,
            testEventId,
            message: 'sendMetaEvent function executed successfully'
        });
    } catch (err: any) {
        return NextResponse.json({
            success: false,
            error: err.message,
            stack: err.stack,
            message: 'sendMetaEvent function FAILED'
        }, { status: 500 });
    }
}
