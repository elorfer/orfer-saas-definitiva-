import Link from "next/link";

export const metadata = {
  title: "Términos y Condiciones de Uso | Manifiestas AI",
  description: "Términos y condiciones legales para utilizar el servicio de Manifiestas AI.",
};

export default function TermsPage() {
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
            Términos y Condiciones de Uso
          </h1>
          <p className="text-sm text-slate-400 mb-8 leading-relaxed">
            Última actualización: 4 de junio de 2026
          </p>

          <div className="space-y-6 text-sm leading-relaxed text-slate-300">
            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">1. Aceptación de los Términos</h2>
              <p>
                Al acceder y utilizar **Manifiestas AI** (el "Servicio"), aceptas cumplir y quedar sujeto a estos Términos y Condiciones. Si no estás de acuerdo con alguna de estas condiciones, por favor abstente de utilizar el Servicio.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">2. Descripción del Servicio</h2>
              <p>
                **Manifiestas AI** es una plataforma SaaS que proporciona herramientas digitales orientadas al desarrollo personal, la reprogramación mental y el bienestar, tales como un coach cognitivo impulsado por Inteligencia Artificial, un diario de agradecimiento, y el Triángulo de Manifestación.
              </p>
              <p className="text-indigo-300 font-medium">
                Aviso importante: El Servicio se ofrece con fines educativos y de entretenimiento. La Inteligencia Artificial no reemplaza el asesoramiento, terapia o tratamiento médico o psicológico profesional.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">3. Registro y Cuentas de Usuario</h2>
              <p>
                Para acceder a ciertas funciones premium, debes registrarte y mantener una cuenta activa con credenciales verídicas. Eres responsable de proteger tus datos de acceso y de cualquier actividad que ocurra bajo tu cuenta.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">4. Suscripciones y Pagos</h2>
              <p>
                Ofrecemos una suscripción de acceso ilimitado ("Suscripción Pro"). Los pagos se procesan de forma segura a través de **Stripe**. Al suscribirte, autorizas el cobro recurrente mensual o anual según el plan elegido. Puedes cancelar tu suscripción en cualquier momento a través del portal de facturación en la app.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">5. Limitación de Responsabilidad</h2>
              <p>
                En la máxima medida permitida por la ley, **Manifiestas AI** no será responsable de ningún daño indirecto, incidental, especial o consecuente resultante del uso o la incapacidad de usar el Servicio, o de cualquier consejo u orientación generados por la IA.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">6. Modificaciones de los Términos</h2>
              <p>
                Nos reservamos el derecho de modificar estos términos en cualquier momento. La fecha de última actualización al principio de este documento reflejará los cambios más recientes. El uso continuado del Servicio constituye la aceptación de los nuevos términos.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">7. Contacto</h2>
              <p>
                Si tienes alguna pregunta acerca de estos Términos, puedes contactarnos en: **soporte@manifiestas.ai**
              </p>
            </section>
          </div>
        </div>
      </div>
    </div>
  );
}
