import { NextResponse } from 'next/server';
import { sendMetaEvent } from '@/lib/meta-capi';

export async function GET(req: Request) {
    const { searchParams } = new URL(req.url);
    const testCode = searchParams.get('code');

    if (!testCode) {
        return NextResponse.json({ error: 'Falta el parámetro "code". Ejemplo: /api/test-meta?code=TEST12345' }, { status: 400 });
    }

    try {
        const result = await sendMetaEvent({
            eventName: 'Purchase',
            eventID: `test_${Date.now()}`,
            testEventCode: testCode,
            userData: {
                email: 'test-capi@struky.com',
                phone: '573001234567',
                firstName: 'Test',
                clientIpAddress: '127.0.0.1',
                clientUserAgent: 'StrukyTestAgent/1.0'
            },
            customData: {
                value: 1,
                currency: 'USD',
                content_name: 'Test CAPI Integration',
                content_category: 'Testing'
            },
            sourceUrl: 'https://www.struky.com/test-capi'
        });

        return NextResponse.json({ 
            success: true, 
            message: 'Evento enviado a Meta CAPI', 
            testCode,
            metaResponse: result 
        });
    } catch (error: any) {
        return NextResponse.json({ 
            success: false, 
            error: error.message 
        }, { status: 500 });
    }
}
