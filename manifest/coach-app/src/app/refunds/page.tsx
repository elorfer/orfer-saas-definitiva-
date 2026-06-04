import Link from "next/link";

export const metadata = {
  title: "Política de Reembolso y Cancelación | Manifiestas AI",
  description: "Política de reembolso, devoluciones y cancelación de suscripciones de Manifiestas AI.",
};

export default function RefundsPage() {
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
            Política de Reembolso y Cancelación
          </h1>
          <p className="text-sm text-slate-400 mb-8 leading-relaxed">
            Última actualización: 4 de junio de 2026
          </p>

          <div className="space-y-6 text-sm leading-relaxed text-slate-300">
            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">1. Política de Cancelación</h2>
              <p>
                Puedes cancelar tu suscripción a **Manifiestas AI Pro** en cualquier momento. La cancelación se puede realizar directamente desde el apartado de "Mi Cuenta" o "Suscripción" en la aplicación, accediendo al portal seguro de facturación de Stripe.
              </p>
              <p>
                Al cancelar tu suscripción, seguirás teniendo acceso completo a los beneficios premium hasta que finalice tu período de facturación actual (mensual o anual). Al terminar dicho período, tu cuenta pasará automáticamente al plan gratuito básico y no se realizarán nuevos cobros.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">2. Política de Reembolso</h2>
              <p>
                Queremos que estés completamente satisfecho con tu experiencia de manifestación. Por ello, ofrecemos una **garantía de reembolso de 14 días** para nuevas suscripciones.
              </p>
              <ul className="list-disc pl-5 space-y-1">
                <li>**Nuevos usuarios:** Si te suscribes a nuestro plan mensual o anual y decides dentro de los primeros 14 días posteriores al cobro que el servicio no cumple con tus expectativas, puedes solicitar un reembolso total del importe pagado.</li>
                <li>**Excepciones:** No se realizarán reembolsos parciales ni totales de suscripciones solicitados después del periodo de garantía de 14 días. Tampoco se reembolsan renovaciones automáticas de meses sucesivos si el usuario no canceló la suscripción antes de la fecha de facturación.</li>
              </ul>
            </section>

            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">3. Cómo Solicitar un Reembolso</h2>
              <p>
                Para solicitar tu reembolso, por favor envía un correo electrónico a: **soporte@manifiestas.ai** con el asunto *"Solicitud de Reembolso Pro"* e incluyendo la siguiente información:
              </p>
              <ul className="list-disc pl-5 space-y-1">
                <li>La dirección de correo electrónico asociada a tu cuenta de Manifiestas AI.</li>
                <li>El número de recibo o comprobante de pago enviado por Stripe.</li>
                <li>Un breve comentario opcional sobre tu experiencia para ayudarnos a mejorar nuestro servicio.</li>
              </ul>
              <p>
                Procesaremos tu solicitud en un plazo máximo de 3 a 5 días hábiles. El reembolso se aplicará al mismo método de pago utilizado para la compra original. Ten en cuenta que el banco emisor de tu tarjeta puede tardar unos días adicionales en reflejar el abono en tu estado de cuenta.
              </p>
            </section>

            <section className="space-y-3">
              <h2 className="text-lg font-bold text-white">4. Fallos Técnicos</h2>
              <p>
                En caso de que experimentes problemas técnicos graves que te impidan utilizar el Servicio y que nuestro equipo de soporte no pueda resolver en un periodo de 72 horas, evaluaremos solicitudes de reembolso fuera del período de 14 días como muestra de buena fe hacia nuestro servicio.
              </p>
            </section>
          </div>
        </div>
      </div>
    </div>
  );
}
