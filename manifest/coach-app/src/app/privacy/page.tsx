import Link from "next/link";

export const metadata = {
  title: "Política de Privacidad | Manifiestas AI",
  description: "Política de privacidad y tratamiento de datos personales de Manifiestas AI.",
};

export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-[#080414] text-slate-200 font-sans relative overflow-x-hidden selection:bg-accent-purple/30 selection:text-accent-gold">
      {/* Luces de fondo */}
      <div className="absolute top-0 left-1/4 w-[500px] h-[500px] bg-[#534AB7]/10 rounded-full blur-[120px] pointer-events-none"></div>
      <div className="absolute bottom-0 right-1/4 w-[500px] h-[500px] bg-[#8b5cf6]/10 rounded-full blur-[120px] pointer-events-none"></div>

      <div className="max-w-4xl mx-auto px-6 py-16 relative z-10">
        <Link
          href="/"
          className="inline-flex items-center gap-2 text-indigo-400 hover:text-indigo-300 font-bold text-xs uppercase tracking-widest mb-8 transition-all hover:-translate-x-1"
        >
          ← Volver al Inicio
        </Link>

        <div className="glass-card rounded-3xl p-8 md:p-12 border border-white/5 shadow-2xl backdrop-blur-2xl">
          <h1 className="text-3xl sm:text-4xl font-black text-white tracking-tight mb-8">
            Política de Privacidad
          </h1>
          <p className="text-sm text-slate-400 mb-8 leading-relaxed">
            Última actualización: 4 de junio de 2026
          </p>

          <div className="space-y-6 text-sm leading-relaxed text-slate-300">
            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">1. Información que Recopilamos</h2>
              <p>
                Recopilamos información para proporcionar un mejor servicio a nuestros usuarios. Esto incluye:
              </p>
              <ul className="list-disc pl-5 space-y-1">
                <li>**Información de registro:** Dirección de correo electrónico cuando te registras de forma gratuita o de pago.</li>
                <li>**Datos del servicio:** Conversaciones del chat cognitivo con el Coach de IA, notas ingresadas en tu diario de gratitud, y los deseos, emociones y acciones del Triángulo de Manifestación.</li>
                <li>**Información de pago:** Las transacciones de facturación son gestionadas directamente y de forma segura por **Stripe**. No guardamos ni tenemos acceso a los datos de tu tarjeta de crédito.</li>
              </ul>
            </section>

            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">2. Uso de la Información</h2>
              <p>
                Utilizamos los datos recopilados para:
              </p>
              <ul className="list-disc pl-5 space-y-1">
                <li>Proporcionar, operar y mantener las funcionalidades cognitivas de la app.</li>
                <li>Procesar de forma segura tus transacciones mediante Stripe.</li>
                <li>Personalizar y mejorar tu experiencia con la IA cognitiva de manifestación.</li>
                <li>Enviarte notificaciones relacionadas con tu cuenta, alertas de metas o soporte.</li>
              </ul>
            </section>

            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">3. Cookies y Tecnologías de Seguimiento</h2>
              <p>
                Utilizamos cookies funcionales y técnicas necesarias para la autenticación de usuarios (Supabase) y el procesamiento seguro de pagos (Stripe). También podemos emplear cookies de analíticas para comprender cómo los usuarios interactúan con nuestra landing page. Puedes configurar tu navegador para rechazar todas las cookies, aunque esto podría afectar al correcto funcionamiento del Servicio.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">4. Privacidad de las Conversaciones con la IA</h2>
              <p>
                En **Manifiestas AI** respetamos la naturaleza íntima y privada de tus decretos, metas y reflexiones. Tus conversaciones con el Coach cognitivo y tus diarios son privados y no se comparten con terceros, utilizándose exclusivamente para el procesamiento instantáneo del modelo de lenguaje de Inteligencia Artificial de forma segura y cifrada.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">5. Seguridad de los Datos</h2>
              <p>
                Implementamos medidas de seguridad estándar de la industria, incluyendo cifrado SSL/HTTPS en todas las transmisiones de datos y bases de datos seguras mediante Supabase y Google Cloud, para proteger tu información de accesos no autorizados, alteración o divulgación.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">6. Tus Derechos</h2>
              <p>
                Tienes derecho a acceder, corregir o solicitar la eliminación definitiva de tu cuenta y todos tus datos personales asociados de nuestra base de datos. Puedes escribirnos en cualquier momento a **soporte@manifiestas.ai** para procesar tu solicitud.
              </p>
            </section>
          </div>
        </div>
      </div>
    </div>
  );
}
