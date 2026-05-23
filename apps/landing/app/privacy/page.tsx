import Link from 'next/link';

export const metadata = {
    title: 'Política de Privacidad | Struky',
    description: 'Conoce cómo recopilamos, utilizamos y protegemos tus datos de contacto, letras de canciones e información en Struky.',
    alternates: {
        canonical: 'https://www.struky.com/privacy',
    },
};

export default function PrivacyPage() {
    return (
        <div className="min-h-screen section-padding">
            <div className="max-w-4xl mx-auto">
                <Link href="/" className="inline-flex items-center text-coffee-medium hover:text-coffee-light mb-8 transition-colors">
                    ← Volver al inicio
                </Link>

                <h1 className="text-4xl md:text-5xl font-heading font-bold mb-8">
                    Política de <span className="text-gradient">Privacidad</span>
                </h1>

                <div className="card-dark space-y-6 text-gray-300">
                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">1. Información que Recopilamos</h2>
                        <p>
                            En Struky, recopilamos la siguiente información cuando utilizas nuestros servicios:
                        </p>
                        <ul className="list-disc list-inside mt-2 space-y-2 ml-4">
                            <li>Nombre completo</li>
                            <li>Dirección de correo electrónico</li>
                            <li>Letra de la canción que deseas producir</li>
                            <li>Preferencias de género musical</li>
                            <li>Información de pago (procesada de forma segura por Stripe)</li>
                        </ul>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">2. Uso de la Información</h2>
                        <p>Utilizamos tu información para:</p>
                        <ul className="list-disc list-inside mt-2 space-y-2 ml-4">
                            <li>Producir tu canción de acuerdo a tus especificaciones</li>
                            <li>Enviarte el archivo final de tu canción</li>
                            <li>Procesar pagos de forma segura</li>
                            <li>Comunicarnos contigo sobre tu pedido</li>
                            <li>Mejorar nuestros servicios</li>
                        </ul>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">3. Protección de Datos</h2>
                        <p>
                            Implementamos medidas de seguridad técnicas y organizativas para proteger tus datos personales
                            contra el acceso no autorizado, la alteración, divulgación o destrucción. Todos los pagos son
                            procesados de forma segura a través de Stripe, que cumple con los estándares PCI DSS.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">4. Compartir Información</h2>
                        <p>
                            No vendemos, intercambiamos ni transferimos tu información personal a terceros, excepto:
                        </p>
                        <ul className="list-disc list-inside mt-2 space-y-2 ml-4">
                            <li>Procesadores de pago (Stripe) para completar transacciones</li>
                            <li>Plataformas de análisis y publicidad (Meta/Facebook Pixel) para medir el rendimiento de campañas</li>
                            <li>Cuando sea requerido por ley</li>
                        </ul>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">5. Tus Derechos</h2>
                        <p>Tienes derecho a:</p>
                        <ul className="list-disc list-inside mt-2 space-y-2 ml-4">
                            <li>Acceder a tus datos personales</li>
                            <li>Solicitar la corrección de datos inexactos</li>
                            <li>Solicitar la eliminación de tus datos</li>
                            <li>Oponerte al procesamiento de tus datos</li>
                        </ul>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">6. Cookies y Tecnologías de Seguimiento</h2>
                        <p className="mb-2">
                            Utilizamos cookies esenciales para el funcionamiento del sitio web.
                            Adicionalmente, utilizamos las siguientes tecnologías de terceros:
                        </p>
                        <ul className="list-disc list-inside mt-2 space-y-2 ml-4">
                            <li><strong>Meta Pixel (Facebook):</strong> Para medir la efectividad de nuestras campañas publicitarias y mejorar la experiencia del usuario</li>
                            <li><strong>Cookies de análisis:</strong> Para comprender cómo los visitantes interactúan con nuestro sitio</li>
                        </ul>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">7. Contacto</h2>
                        <p>
                            Para cualquier pregunta sobre esta política de privacidad, contáctanos en:{' '}
                            <a href="mailto:welcome@struky.com" className="text-neon-purple hover:text-neon-blue underline">
                                welcome@struky.com
                            </a>
                        </p>
                    </section>

                    <section className="pt-4 border-t border-gray-700">
                        <p className="text-sm text-gray-400">
                            Última actualización: {new Date().toLocaleDateString('es-ES', { year: 'numeric', month: 'long', day: 'numeric' })}
                        </p>
                    </section>
                </div>
            </div>
        </div>
    );
}
