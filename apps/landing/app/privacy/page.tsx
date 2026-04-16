import Link from 'next/link';

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
                            <li>Información de pago (procesada de forma segura por Stripe/Lemon Squeezy)</li>
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
                            procesados de forma segura a través de Stripe/Lemon Squeezy, que cumple con los estándares PCI DSS.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">4. Compartir Información</h2>
                        <p>
                            No vendemos, intercambiamos ni transferimos tu información personal a terceros, excepto:
                        </p>
                        <ul className="list-disc list-inside mt-2 space-y-2 ml-4">
                            <li>Procesadores de pago (Stripe/Lemon Squeezy) para completar transacciones</li>
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
                        <h2 className="text-2xl font-bold text-white mb-4">6. Cookies</h2>
                        <p>
                            Utilizamos cookies esenciales para el funcionamiento del sitio web y análisis básico de tráfico.
                            No utilizamos cookies de seguimiento de terceros para publicidad.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">7. Contacto</h2>
                        <p>
                            Para cualquier pregunta sobre esta política de privacidad, contáctanos en:{' '}
                            <a href="mailto:strukyapp@gmail.com" className="text-neon-purple hover:text-neon-blue underline">
                                strukyapp@gmail.com
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
