import { Injectable, Logger } from '@nestjs/common';
import { Resend } from 'resend';

@Injectable()
export class ResendService {
  private readonly logger = new Logger(ResendService.name);
  private resend: Resend;

  constructor() {
    const apiKey = process.env.RESEND_API_KEY;

    if (!apiKey) {
      this.logger.warn('⚠️ RESEND_API_KEY no configurada. Emails deshabilitados.');
      return;
    }

    this.resend = new Resend(apiKey);
    this.logger.log('✅ Resend inicializado correctamente');
  }

  async sendPasswordResetEmail(email: string, resetToken: string): Promise<boolean> {
    if (!this.resend) {
      this.logger.warn('⚠️ Resend no configurado. Email no enviado.');
      return false;
    }

    try {
      // 🔗 Deep Link: Siempre usar deep link para que abra la app
      // TODO: En producción, usar https://struky.com cuando esté configurado
      const resetLink = `struky://reset-password/${resetToken}`;

      // 🔧 Detectar si estamos en desarrollo
      const isDevelopment = process.env.NODE_ENV !== 'production';

      // En desarrollo, Resend solo permite enviar a tu propio email
      const devEmail = 'strukyapp@gmail.com';
      const recipientEmail = isDevelopment ? devEmail : email;

      if (isDevelopment) {
        this.logger.log(`📧 [DEV] Enviando email de ${email} a ${devEmail} (limitación de Resend)`);
      }

      // Construir HTML del email
      const devNote = isDevelopment
        ? `<div class="dev-note">
             <strong>🔧 MODO DESARROLLO</strong><br>
             Este email fue solicitado para: <strong>${email}</strong><br>
             Por limitaciones de Resend en testing, fue enviado a <strong>${devEmail}</strong>
           </div>`
        : '';

      const emailContent = isDevelopment ? ` (${email})` : '';

      const { data, error } = await this.resend.emails.send({
        from: isDevelopment ? 'Struky <onboarding@resend.dev>' : 'Struky <noreply@struky.com>',
        to: [recipientEmail],
        subject: `Recupera tu contraseña - Struky${isDevelopment ? ` [DEV: ${email}]` : ''}`,
        html: `
          <!DOCTYPE html>
          <html>
            <head>
              <style>
                body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
                .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
                .button { display: inline-block; padding: 15px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; font-weight: bold; margin: 20px 0; }
                .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
                .dev-note { background: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin-bottom: 20px; }
              </style>
            </head>
            <body>
              <div class="container">
                <div class="header">
                  <h1>🎵 Struky</h1>
                  <p>Recuperación de contraseña</p>
                </div>
                <div class="content">
                  ${devNote}
                  <p>Hola,</p>
                  <p>Recibimos una solicitud para restablecer la contraseña de tu cuenta${emailContent}.</p>
                  <p>Haz click en el siguiente botón para crear una nueva contraseña:</p>
                  <p style="text-align: center;">
                    <a href="${resetLink}" class="button">Restablecer Contraseña</a>
                  </p>
                  <p><strong>Este enlace expirará en 1 hora.</strong></p>
                  <p>Si no solicitaste este cambio, puedes ignorar este email de forma segura.</p>
                  <div class="footer">
                    <p>© 2026 Struky. Todos los derechos reservados.</p>
                    <p>Si el botón no funciona, copia este enlace: ${resetLink}</p>
                  </div>
                </div>
              </div>
            </body>
          </html>
        `,
      });

      if (error) {
        this.logger.error('❌ Error enviando email con Resend:', error);
        return false;
      }

      this.logger.log(`✅ Email de recuperación enviado a: ${recipientEmail} (ID: ${data.id})`);
      return true;
    } catch (error) {
      this.logger.error('❌ Error enviando email:', error);
      return false;
    }
  }
}
