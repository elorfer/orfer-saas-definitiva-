import Link from 'next/link';

export const metadata = {
    title: 'Política de Reembolso | Struky',
    description: 'Información detallada sobre nuestra política de satisfacción garantizada de 14 días en Struky.',
    alternates: {
        canonical: 'https://www.struky.com/refund',
    },
};

export default function RefundPage() {
    return (
        <div className="min-h-screen section-padding">
            <div className="max-w-4xl mx-auto">
                <Link href="/" className="inline-flex items-center text-coffee-medium hover:text-coffee-light mb-8 transition-colors">
                    ← Volver al inicio
                </Link>

                <h1 className="text-4xl md:text-5xl font-heading font-bold mb-8">
                    Política de <span className="text-gradient">Reembolso</span>
                </h1>

                <div className="card-dark space-y-6 text-gray-300">
                    <section className="bg-coffee-medium/10 border border-coffee-medium/30 rounded-lg p-6">
                        <h2 className="text-2xl font-bold text-white mb-4">✅ Política de Reembolso de 14 Días</h2>
                        <p className="text-lg">
                            En Struky, ofrecemos un período de reembolso de <strong className="text-coffee-medium">14 días naturales</strong> desde la fecha de compra.
                            Tu satisfacción es nuestra prioridad.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">1. ¿Cuándo puedo solicitar un reembolso?</h2>
                        <p className="mb-3">
                            Puedes solicitar un reembolso completo dentro de los <strong>14 días naturales</strong> posteriores a tu compra si:
                        </p>
                        <ul className="list-disc list-inside space-y-2 ml-4">
                            <li>No estás satisfecho con la calidad de la producción musical entregada</li>
                            <li>La canción no cumple con las especificaciones que acordamos</li>
                            <li>Experimentamos retrasos significativos en la entrega (más de 72 horas del plazo acordado)</li>
                            <li>Cancelas tu pedido antes de que comencemos la producción</li>
                            <li>Cualquier otra razón dentro del período de 14 días</li>
                        </ul>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">2. ¿Cómo solicito un reembolso?</h2>
                        <p className="mb-3">El proceso es simple y rápido:</p>
                        <div className="bg-dark-bg rounded-lg p-6 space-y-3">
                            <div className="flex items-start gap-4">
                                <div className="w-8 h-8 rounded-full bg-coffee-medium/20 flex items-center justify-center flex-shrink-0 text-coffee-medium font-bold">1</div>
                                <div>
                                    <strong className="text-white">Envía un correo electrónico</strong>
                                    <p className="text-sm mt-1">Escribe a: <a href="mailto:welcome@struky.com" className="text-coffee-medium hover:text-coffee-light underline">welcome@struky.com</a></p>
                                </div>
                            </div>
                            <div className="flex items-start gap-4">
                                <div className="w-8 h-8 rounded-full bg-coffee-medium/20 flex items-center justify-center flex-shrink-0 text-coffee-medium font-bold">2</div>
                                <div>
                                    <strong className="text-white">Incluye la información necesaria</strong>
                                    <p className="text-sm mt-1">Tu nombre, número de pedido (si lo tienes) y el motivo del reembolso</p>
                                </div>
                            </div>
                            <div className="flex items-start gap-4">
                                <div className="w-8 h-8 rounded-full bg-coffee-medium/20 flex items-center justify-center flex-shrink-0 text-coffee-medium font-bold">3</div>
                                <div>
                                    <strong className="text-white">Procesamos tu solicitud</strong>
                                    <p className="text-sm mt-1">Revisaremos y responderemos en un plazo de 3-5 días hábiles</p>
                                </div>
                            </div>
                            <div className="flex items-start gap-4">
                                <div className="w-8 h-8 rounded-full bg-coffee-medium/20 flex items-center justify-center flex-shrink-0 text-coffee-medium font-bold">4</div>
                                <div>
                                    <strong className="text-white">Recibes tu reembolso</strong>
                                    <p className="text-sm mt-1">El reembolso se realizará al método de pago original utilizado en la compra</p>
                                </div>
                            </div>
                        </div>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">3. Excepciones al período de reembolso</h2>
                        <p className="mb-3">
                            No podremos procesar reembolsos en los siguientes casos:
                        </p>
                        <ul className="list-disc list-inside space-y-2 ml-4">
                            <li>
                                <strong>Después de 14 días:</strong> Solicitudes recibidas después de transcurridos los 14 días naturales desde la fecha de compra
                            </li>
                            <li>
                                <strong>Distribución comercial:</strong> Si ya has distribuido comercialmente la canción en plataformas de streaming (Spotify, Apple Music, etc.)
                            </li>
                            <li>
                                <strong>Uso público:</strong> Si has publicado o usado públicamente la canción en redes sociales, YouTube u otras plataformas
                            </li>
                        </ul>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">4. Garantía de Satisfacción</h2>
                        <p className="mb-4">Además de nuestra política de reembolso, te garantizamos:</p>
                        <div className="grid md:grid-cols-2 gap-4">
                            <div className="bg-dark-bg rounded-lg p-4 border border-gray-700">
                                <div className="text-coffee-medium text-2xl mb-2">✓</div>
                                <h3 className="font-bold text-white mb-2">Calidad Profesional</h3>
                                <p className="text-sm">
                                    Producción con IA avanzada supervisada por productores musicales profesionales
                                </p>
                            </div>
                            <div className="bg-dark-bg rounded-lg p-4 border border-gray-700">
                                <div className="text-coffee-medium text-2xl mb-2">✓</div>
                                <h3 className="font-bold text-white mb-2">Entrega Rápida</h3>
                                <p className="text-sm">
                                    Tu canción lista en 24-48 horas o te notificamos de cualquier retraso
                                </p>
                            </div>
                            <div className="bg-dark-bg rounded-lg p-4 border border-gray-700">
                                <div className="text-coffee-medium text-2xl mb-2">✓</div>
                                <h3 className="font-bold text-white mb-2">Revisión Incluida</h3>
                                <p className="text-sm">
                                    Una (1) revisión incluida para ajustes razonables de mezcla, tempo o arreglos
                                </p>
                            </div>
                            <div className="bg-dark-bg rounded-lg p-4 border border-gray-700">
                                <div className="text-coffee-medium text-2xl mb-2">✓</div>
                                <h3 className="font-bold text-white mb-2">Soporte Directo</h3>
                                <p className="text-sm">
                                    Comunicación directa y personalizada vía email o WhatsApp
                                </p>
                            </div>
                        </div>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">5. Antes de Realizar tu Pedido</h2>
                        <p className="mb-3">
                            Para asegurar tu satisfacción, te recomendamos:
                        </p>
                        <ul className="list-disc list-inside space-y-2 ml-4">
                            <li>Escuchar nuestros ejemplos de trabajo para conocer el estilo de producción</li>
                            <li>Asegurarte de que tu letra esté completa y pulida</li>
                            <li>Verificar que tienes los derechos de la letra que estás enviando</li>
                            <li>Elegir el género musical que mejor se adapte a tu canción</li>
                            <li>Contactarnos si tienes preguntas antes de realizar el pago</li>
                        </ul>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">6. Disputas de Pago</h2>
                        <p className="mb-3">
                            Nos comprometemos a resolver cualquier problema de manera directa y justa. Si tienes algún inconveniente:
                        </p>
                        <ul className="list-disc list-inside space-y-2 ml-4">
                            <li>
                                <strong>Contáctanos primero:</strong> Por favor, comunícate con nosotros antes de iniciar una disputa de pago con tu banco
                            </li>
                            <li>
                                <strong>Resolución directa:</strong> En la mayoría de casos, podemos resolver el problema de manera rápida y satisfactoria
                            </li>
                            <li>
                                <strong>Disputas bancarias:</strong> Si inicias un contracargo sin contactarnos primero, nos reservamos el derecho de suspender servicios futuros
                            </li>
                        </ul>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">7. Contacto</h2>
                        <p className="mb-4">
                            ¿Tienes preguntas sobre nuestra política de reembolso o necesitas solicitar uno?
                        </p>
                        <div className="bg-dark-bg rounded-lg p-6 space-y-3">
                            <div className="flex items-center gap-3">
                                <span className="text-2xl">📧</span>
                                <div>
                                    <div className="text-sm text-gray-400">Email</div>
                                    <a href="mailto:welcome@struky.com" className="text-coffee-medium hover:text-coffee-light underline font-semibold">
                                        welcome@struky.com
                                    </a>
                                </div>
                            </div>
                            <div className="flex items-center gap-3">
                                <span className="text-2xl">💬</span>
                                <div>
                                    <div className="text-sm text-gray-400">WhatsApp</div>
                                    <a
                                        href="https://wa.me/573017509921"
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        className="text-coffee-medium hover:text-coffee-light underline font-semibold"
                                    >
                                        +57 301 7509921
                                    </a>
                                </div>
                            </div>
                        </div>
                        <p className="text-sm text-gray-400 mt-4">
                            Horario de atención: Lunes a Viernes, 9:00 AM - 6:00 PM (hora de Colombia)
                        </p>
                    </section>

                    <section className="pt-4 border-t border-gray-700">
                        <p className="text-sm text-gray-400">
                            Última actualización: {new Date().toLocaleDateString('es-ES', { year: 'numeric', month: 'long', day: 'numeric' })}
                        </p>
                        <p className="text-xs text-gray-500 mt-2">
                            Esta política cumple con los estándares internacionales de comercio electrónico y protección al consumidor.
                        </p>
                    </section>
                </div>
            </div>
        </div>
    );
}
