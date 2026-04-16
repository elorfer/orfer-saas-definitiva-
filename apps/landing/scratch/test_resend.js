const { Resend } = require('resend');

const resend = new Resend('re_9m1ULGMi_J7fB9SiS7amrEi57LoqBRHXs');

async function testEmail() {
    try {
        console.log('🚀 Iniciando prueba de Resend...');
        
        const data = await resend.emails.send({
            from: 'Struky Test <onboarding@resend.dev>',
            to: 'strukyapp@gmail.com',
            subject: '✅ ¡Resend Funcionando!',
            html: `
                <div style="font-family: sans-serif; background-color: #050505; color: #ffffff; padding: 40px; border-radius: 20px;">
                    <h1 style="color: #caa052;">¡Conexión Exitosa!</h1>
                    <p>Este es un correo de prueba de <strong>Struky Music AI</strong>.</p>
                    <p>Si estás leyendo esto, significa que tu API Key es válida y el sistema de automatización está listo para el despegue.</p>
                </div>
            `
        });

        console.log('✅ Email enviado con éxito:', data);
    } catch (error) {
        console.error('❌ Error al enviar email:', error);
    }
}

testEmail();
