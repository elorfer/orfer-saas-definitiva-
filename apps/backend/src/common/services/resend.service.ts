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
        subject: `🔐 Recupera tu contraseña - Struky${isDevelopment ? ` [DEV: ${email}]` : ''}`,
        html: `
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { 
                  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                  line-height: 1.6; 
                  color: #2D2420;
                  background: linear-gradient(135deg, #F5F2F0 0%, #E8E2DD 100%);
                  padding: 20px;
                }
                .container { 
                  max-width: 600px; 
                  margin: 0 auto; 
                  background: #FFFFFF;
                  border-radius: 20px;
                  overflow: hidden;
                  box-shadow: 0 20px 60px rgba(93, 64, 55, 0.1);
                }
                .header { 
                  background: linear-gradient(135deg, #8D6E63 0%, #5D4037 100%);
                  padding: 40px 30px;
                  text-align: center;
                  position: relative;
                }
                .logo { 
                  font-size: 48px;
                  font-weight: 900;
                  color: #FFFFFF;
                  margin-bottom: 10px;
                  letter-spacing: -2px;
                  text-shadow: 0 2px 4px rgba(0,0,0,0.1);
                }
                .subtitle {
                  color: rgba(255, 255, 255, 0.95);
                  font-size: 16px;
                  font-weight: 300;
                  letter-spacing: 2px;
                  text-transform: uppercase;
                }
                .content { 
                  background: #FFFFFF;
                  padding: 40px 30px;
                  color: #2D2420;
                }
                .dev-note { 
                  background: #FFF3E0;
                  border-left: 4px solid #FFA726;
                  padding: 15px 20px;
                  border-radius: 8px;
                  margin-bottom: 25px;
                  color: #E65100;
                  font-size: 14px;
                }
                .greeting {
                  font-size: 24px;
                  font-weight: 600;
                  margin-bottom: 20px;
                  color: #2D2420;
                }
                .message {
                  font-size: 16px;
                  color: #756860;
                  margin-bottom: 15px;
                  line-height: 1.8;
                }
                .button-container {
                  text-align: center;
                  margin: 35px 0;
                }
                .button { 
                  display: inline-block;
                  padding: 18px 45px;
                  background: linear-gradient(135deg, #8D6E63 0%, #5D4037 100%);
                  color: white !important;
                  text-decoration: none;
                  border-radius: 50px;
                  font-weight: 700;
                  font-size: 16px;
                  letter-spacing: 0.5px;
                  box-shadow: 0 10px 30px rgba(141, 110, 99, 0.3);
                  transition: all 0.3s ease;
                }
                .warning {
                  background: #FFEBEE;
                  border-left: 4px solid #EF5350;
                  padding: 15px 20px;
                  border-radius: 8px;
                  margin: 20px 0;
                  color: #C62828;
                  font-weight: 600;
                }
                .footer { 
                  text-align: center;
                  padding: 30px;
                  background: #F5F2F0;
                  color: #A89C94;
                  font-size: 13px;
                }
                .footer-link {
                  color: #8D6E63;
                  text-decoration: none;
                  word-break: break-all;
                  font-size: 12px;
                  display: block;
                  margin-top: 15px;
                  padding: 10px;
                  background: #FFFFFF;
                  border: 1px solid #E8E2DD;
                  border-radius: 8px;
                }
                .divider {
                  height: 1px;
                  background: linear-gradient(90deg, transparent, #E8E2DD, transparent);
                  margin: 20px 0;
                }
              </style>
            </head>
            <body>
              <div class="container">
                <div class="header">
                  <div class="logo">🎵 STRUKY</div>
                  <div class="subtitle">Tu música, tu mundo</div>
                </div>
                <div class="content">
                  ${devNote}
                  <div class="greeting">¡Hola! 👋</div>
                  <p class="message">
                    Recibimos una solicitud para restablecer la contraseña de tu cuenta${emailContent}.
                  </p>
                  <p class="message">
                    No te preocupes, recuperar el acceso a tu música es muy fácil. 
                    Solo haz clic en el botón de abajo y crea una nueva contraseña segura.
                  </p>
                  <div class="button-container">
                    <a href="${resetLink}" class="button">🔐 Restablecer Contraseña</a>
                  </div>
                  <div class="warning">
                    ⏰ Este enlace expirará en 1 hora por seguridad.
                  </div>
                  <div class="divider"></div>
                  <p class="message" style="font-size: 14px; color: rgba(255,255,255,0.7);">
                    Si no solicitaste este cambio, puedes ignorar este email de forma segura. 
                    Tu cuenta permanecerá protegida.
                  </p>
                </div>
                <div class="footer">
                  <p>© 2026 Struky. Todos los derechos reservados.</p>
                  <p style="margin-top: 10px;">Tu música, siempre a tu alcance 🎧</p>
                  <p style="margin-top: 20px; font-size: 12px; color: rgba(255,255,255,0.5);">
                    ¿No funciona el botón? Copia este enlace:
                  </p>
                  <a href="${resetLink}" class="footer-link">${resetLink}</a>
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

  async sendWelcomeVerificationEmail(email: string, code: string): Promise<boolean> {
    if (!this.resend) {
      this.logger.warn('⚠️ Resend no configurado. Email de bienvenida no enviado.');
      return false;
    }

    try {
      // 🔧 Detectar si estamos en desarrollo
      const isDevelopment = process.env.NODE_ENV !== 'production';

      // En desarrollo, Resend solo permite enviar a tu propio email
      const devEmail = 'strukyapp@gmail.com';
      const recipientEmail = isDevelopment ? devEmail : email;

      if (isDevelopment) {
        this.logger.log(`📧 [DEV] Enviando email de bienvenida de ${email} a ${devEmail}`);
      }

      // Construir HTML del email
      const devNote = isDevelopment
        ? `<div class="dev-note">
             <strong>🔧 MODO DESARROLLO</strong><br>
             Este email fue solicitado para: <strong>${email}</strong><br>
             Por limitaciones de Resend en testing, fue enviado a <strong>${devEmail}</strong>
           </div>`
        : '';

      const { data, error } = await this.resend.emails.send({
        from: isDevelopment ? 'Struky <onboarding@resend.dev>' : 'Struky <welcome@struky.com>',
        to: [recipientEmail],
        subject: `🎧 ¡Tu código de acceso a Struky: ${code}`,
        html: `
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { 
                  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                  background-color: #FDFBF9;
                  padding: 40px 20px;
                  color: #2D2420;
                }
                .container { 
                  max-width: 500px; 
                  margin: 0 auto; 
                  background: #FFFFFF;
                  border-radius: 32px;
                  overflow: hidden;
                  box-shadow: 0 40px 100px rgba(93, 64, 55, 0.1);
                  border: 1px solid #F5EFEB;
                }
                .header { 
                  background: linear-gradient(135deg, #3E2723 0%, #1B1B1B 100%);
                  padding: 50px 40px;
                  text-align: center;
                }
                .logo { 
                  font-size: 38px;
                  font-weight: 900;
                  color: #D7CCC8;
                  letter-spacing: -1px;
                  margin-bottom: 5px;
                }
                .subtitle {
                  color: rgba(215, 204, 200, 0.7);
                  font-size: 14px;
                  font-weight: 300;
                  letter-spacing: 3px;
                  text-transform: uppercase;
                }
                .content { 
                  padding: 50px 40px;
                  text-align: center;
                }
                .greeting {
                  font-size: 26px;
                  font-weight: 700;
                  margin-bottom: 15px;
                  color: #2D2420;
                }
                .message {
                  font-size: 16px;
                  color: #756860;
                  line-height: 1.6;
                  margin-bottom: 30px;
                }
                .code-container {
                  background: #F5F2F0;
                  padding: 24px;
                  border-radius: 20px;
                  margin: 30px 0;
                  border: 2px dashed #D7CCC8;
                }
                .code {
                  font-family: 'Courier New', Courier, monospace;
                  font-size: 48px;
                  font-weight: 900;
                  color: #3E2723;
                  letter-spacing: 12px;
                  margin: 0;
                  padding-left: 12px; /* Centrar visualmente */
                }
                .expiry-note {
                  font-size: 13px;
                  color: #A89C94;
                  margin-top: 15px;
                }
                .footer { 
                  background: #FAF7F5;
                  padding: 30px;
                  text-align: center;
                  font-size: 12px;
                  color: #A89C94;
                  border-top: 1px solid #F5EFEB;
                }
                .dev-note { 
                  background: #FFF3E0;
                  border-left: 4px solid #FFA726;
                  padding: 15px;
                  border-radius: 12px;
                  margin-bottom: 30px;
                  color: #E65100;
                  font-size: 14px;
                  text-align: left;
                }
              </style>
            </head>
            <body>
              <div class="container">
                <div class="header">
                  <img src="https://res.cloudinary.com/dilq8e3bj/image/upload/v1773827907/logo_struky_vwev8e.png" alt="Struky Logo" height="65" style="display: block; margin: 0 auto 10px auto;" />
                  <div class="subtitle">Premium Music</div>
                </div>
                <div class="content">
                  ${devNote}
                  <div class="greeting">¡Hola! 🎧</div>
                  <p class="message">
                    Estamos felices de que te unas a la comunidad de Struky. Para completar tu registro, ingresa el siguiente código en la aplicación:
                  </p>
                  
                  <div class="code-container">
                    <div class="code">${code}</div>
                  </div>
                  
                  <p class="expiry-note">
                    ⏰ Este código es válido por 24 horas.
                  </p>
                  
                  <p class="message" style="margin-top: 40px; font-size: 14px;">
                    Si no solicitaste este código, puedes ignorar este correo con total tranquilidad.
                  </p>
                </div>
                <div class="footer">
                  <p>© 2026 Struky Music. Todos los derechos reservados.</p>
                  <p style="margin-top: 5px;">Tu música, tu estilo, tu mundo.</p>
                </div>
              </div>
            </body>
          </html>
        `,
      });

      if (error) {
        this.logger.error('❌ Error enviando email de bienvenida:', error);
        return false;
      }

      this.logger.log(`✅ Email de bienvenida con OTP enviado a: ${recipientEmail} (ID: ${data.id})`);
      return true;
    } catch (error) {
      this.logger.error('❌ Error enviando email de bienvenida:', error);
      return false;
    }
  }
}
