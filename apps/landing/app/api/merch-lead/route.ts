import { NextResponse } from 'next/server';
import { Resend } from 'resend';


const resend = new Resend(process.env.RESEND_API_KEY || 're_dummy_key');

export async function POST(req: Request) {
    try {
        const body = await req.json();
        const { email } = body;

        if (!email) {
            return NextResponse.json({ error: 'Email is required' }, { status: 400 });
        }


        // --- RESEND: Notify Admin ---
        await resend.emails.send({
            from: 'Struky Merch <welcome@struky.com>',
            to: 'welcome@struky.com',
            subject: `🔥 INTERÉS EN SUDADERA: ${email}`,
            html: `
                <div style="font-family: sans-serif; background-color: #050505; color: #ffffff; padding: 40px; border-radius: 24px; border: 1px solid #1a1a1a;">
                    <h1 style="color: #caa052; font-size: 24px; margin-bottom: 8px;">🧥 Nuevo Lead de Merchandising</h1>
                    <p style="color: #666; font-size: 14px; margin-bottom: 32px;">Alguien ha mostrado interés en la Sudadera Oficial de Struky Studios.</p>
                    
                    <div style="background: #111; padding: 24px; border-radius: 16px; border: 1px solid #222;">
                        <p style="margin: 0; font-size: 16px;"><strong>Email del interesado:</strong> <span style="color: #caa052;">${email}</span></p>
                    </div>

                    <p style="color: #444; font-size: 12px; margin-top: 32px;">Este es un aviso automático de tu landing page.</p>
                </div>
            `
        });

        // --- RESEND: Thank you to User ---
        await resend.emails.send({
            from: 'Struky Studios <welcome@struky.com>',
            to: email,
            subject: '🧥 Tu reserva de la Sudadera Oficial Struky Studios',
            html: `
                <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; background-color: #050505; color: #ffffff; padding: 40px; border-radius: 24px;">
                    <div style="text-align: center; margin-bottom: 40px;">
                         <h1 style="color: #caa052; font-size: 32px; font-weight: 900; letter-spacing: -1px; margin: 0;">STRUKY</h1>
                         <p style="color: #666; font-size: 12px; text-transform: uppercase; letter-spacing: 2px;">Official Merchandise</p>
                    </div>

                    <h2 style="font-size: 24px; text-align: center; margin-bottom: 24px;">¡Gracias por tu interés! 👋</h2>
                    
                    <p style="color: #ccc; line-height: 1.8; text-align: center; font-size: 16px;">
                        Hemos recibido tu interés por la <strong>Sudadera Oficial Struky Studios (Edición Limitada)</strong>.
                    </p>

                    <div style="background: #111; border: 1px solid #caa05250; padding: 30px; border-radius: 20px; margin: 40px 0; text-align: center;">
                        <p style="font-size: 14px; color: #888; margin-bottom: 10px;">Estás en la lista de espera prioritaria.</p>
                        <div style="color: #fff; font-weight: bold; font-size: 18px;">
                            🚀 Te avisaremos en cuanto abramos las unidades oficiales.
                        </div>
                    </div>

                    <p style="color: #666; font-size: 12px; text-align: center;">
                        Si tienes alguna duda, responde a este correo. ¡Prepárate para vestir la esencia!
                    </p>

                    <hr style="border: 0; border-top: 1px solid #222; margin: 40px 0;" />

                    <p style="color: #444; font-size: 10px; text-align: center; text-transform: uppercase; letter-spacing: 1px;">
                        © 2026 Struky Music AI. Todos los derechos reservados.
                    </p>
                </div>
            `
        });

        return NextResponse.json({ success: true });
    } catch (err: any) {
        console.error('Error in merch-lead API:', err);
        return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 });
    }
}
