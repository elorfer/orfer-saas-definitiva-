import crypto from 'crypto';

function hashData(data: string) {
    if (!data) return '';
    return crypto.createHash('sha256').update(data.trim().toLowerCase()).digest('hex');
}

export async function sendMetaEvent({
    eventName,
    userData,
    customData,
    eventID,
    sourceUrl,
    testEventCode
}: {
    eventName: 'InitiateCheckout' | 'Purchase' | 'Lead' | 'AddToCart';
    userData: {
        email?: string;
        phone?: string;
        firstName?: string;
        fbp?: string;
        fbc?: string;
        clientIpAddress?: string;
        clientUserAgent?: string;
        externalId?: string;
    };
    customData?: any;
    eventID?: string;
    sourceUrl?: string;
    testEventCode?: string;
}) {
    const pixelId = process.env.NEXT_PUBLIC_META_PIXEL_ID || '1681899642811715';
    const accessToken = process.env.META_ACCESS_TOKEN;

    if (!accessToken) {
        console.warn('META_ACCESS_TOKEN not configured. Skipping CAPI event.');
        return;
    }

    const payload = {
        data: [
            {
                event_name: eventName,
                event_time: Math.floor(Date.now() / 1000),
                event_id: eventID,
                event_source_url: sourceUrl || 'https://www.struky.com/',
                action_source: 'website',
                user_data: {
                    em: userData.email ? [hashData(userData.email)] : [],
                    ph: userData.phone ? [hashData(userData.phone)] : [],
                    fn: userData.firstName ? [hashData(userData.firstName)] : [],
                    fbp: userData.fbp,
                    fbc: userData.fbc,
                    client_ip_address: userData.clientIpAddress || '',
                    client_user_agent: userData.clientUserAgent || 'StrukyServer/1.0',
                    ...(userData.externalId ? { external_id: [hashData(userData.externalId)] } : {})
                },
                custom_data: customData
            }
        ],
        ...(testEventCode ? { test_event_code: testEventCode } : {})
    };

    try {
        const response = await fetch(`https://graph.facebook.com/v19.0/${pixelId}/events?access_token=${accessToken}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const result = await response.json();
        console.log(`Meta CAPI (${eventName}) Response:`, result);
        return result;
    } catch (err) {
        console.error(`Error sending Meta CAPI event (${eventName}):`, err);
    }
}
