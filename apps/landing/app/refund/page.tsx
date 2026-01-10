import Link from 'next/link';

export default function RefundPage() {
    return (
        <div className="min-h-screen section-padding">
            <div className="max-w-4xl mx-auto">
                <Link href="/" className="inline-flex items-center text-neon-purple hover:text-neon-blue mb-8 transition-colors">
                    ← Volver al inicio
                </Link>

                <h1 className="text-4xl md:text-5xl font-display font-bold mb-8">
                    Política de <span className="text-gradient">Reembolso</span>
                </h1>

                <div className="card-dark space-y-6 text-gray-300">
                    <section className="bg-neon-purple/10 border border-neon-purple/30 rounded-lg p-6">
                        <h2 className="text-2xl font-bold text-white mb-4">⚠️ Política de No Reembolso</h2>
                        <p className="text-lg">
                            <strong>Importante:</strong> Debido a la naturaleza digital y personalizada de nuestros productos,
                            <span className="text-neon-purple font-bold"> NO OFRECEMOS REEMBOLSOS</span> una vez que el trabajo
                            ha sido iniciado.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">1. ¿Por qué no hay reembolsos?</h2>
                        <p className="mb-3">
                            Nuestro servicio implica la creación de productos digitales personalizados que se producen
                            específicamente para cada cliente. Una vez que comenzamos a trabajar en tu canción:
                        </p>
                        <ul className="list-disc list-inside space-y-2 ml-4">
                            <li>Invertimos tiempo y recursos de IA en la producción</li>
                            <li>Un profesional humano supervisa y refina el trabajo</li>
                            <li>El producto final es único y personalizado para ti</li>
                            <li>No podemos revender o reutilizar el trabajo realizado</li>
                        </ul>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">2. Proceso de Revisión</h2>
                        <p className="mb-3">
                            Aunque no ofrecemos reembolsos, nos comprometemos a tu satisfacción:
                        </p>
                        <ul className="list-disc list-inside space-y-2 ml-4">
                            <li>
                                <strong>Revisión incluida:</strong> Ofrecemos una (1) revisión menor por pedido para
                                ajustes razonables como cambios de tempo, mezcla o arreglos menores.
                            </li>
                            <li>
                                <strong>Comunicación clara:</strong> Trabajaremos contigo para asegurar que el resultado
                                final se acerque lo máximo posible a tus expectativas.
                            </li>
                            <li>
                                <strong>Garantía de calidad:</strong> Garantizamos que la producción será de calidad profesional.
                            </li>
                        </ul>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">3. Excepciones Limitadas</h2>
                        <p className="mb-3">
                            Solo consideraremos reembolsos en casos excepcionales:
                        </p>
                        <ul className="list-disc list-inside space-y-2 ml-4">
                            <li>
                                <strong>Error técnico:</strong> Si experimentamos un error técnico que nos impida
                                completar tu pedido.
                            </li>
                            <li>
                                <strong>Cancelación antes del inicio:</strong> Si cancelas tu pedido ANTES de que
                                comencemos la producción, podrás recibir un reembolso completo.
                            </li>
                            <li>
                                <strong>Problemas de pago duplicado:</strong> Si se procesó un pago duplicado por error.
                            </li>
                        </ul>
                        <p className="mt-4">
                            Para solicitar una revisión de tu caso, contáctanos en:{' '}
                            <a href="mailto:refunds@strukymusicai.com" className="text-neon-purple hover:text-neon-blue underline">
                                refunds@strukymusicai.com
                            </a>
                        </p>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">4. Lo que SÍ Garantizamos</h2>
                        <div className="grid md:grid-cols-2 gap-4 mt-4">
                            <div className="bg-dark-bg rounded-lg p-4 border border-gray-700">
                                <div className="text-neon-purple text-2xl mb-2">✓</div>
                                <h3 className="font-bold text-white mb-2">Calidad Profesional</h3>
                                <p className="text-sm">
                                    Producción de nivel profesional supervisada por expertos humanos.
                                </p>
                            </div>
                            <div className="bg-dark-bg rounded-lg p-4 border border-gray-700">
                                <div className="text-neon-purple text-2xl mb-2">✓</div>
                                <h3 className="font-bold text-white mb-2">Entrega a Tiempo</h3>
                                <p className="text-sm">
                                    Tu canción en 24-48 horas o te notificaremos de cualquier retraso.
                                </p>
                            </div>
                            <div className="bg-dark-bg rounded-lg p-4 border border-gray-700">
                                <div className="text-neon-purple text-2xl mb-2">✓</div>
                                <h3 className="font-bold text-white mb-2">Una Revisión Incluida</h3>
                                <p className="text-sm">
                                    Ajustes razonables para asegurar tu satisfacción.
                                </p>
                            </div>
                            <div className="bg-dark-bg rounded-lg p-4 border border-gray-700">
                                <div className="text-neon-purple text-2xl mb-2">✓</div>
                                <h3 className="font-bold text-white mb-2">Soporte Dedicado</h3>
                                <p className="text-sm">
                                    Comunicación directa vía email o WhatsApp.
                                </p>
                            </div>
                        </div>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">5. Antes de Realizar tu Pedido</h2>
                        <p className="mb-3">
                            Para evitar decepciones, te recomendamos:
                        </p>
                        <ul className="list-disc list-inside space-y-2 ml-4">
                            <li>Revisar nuestros ejemplos de trabajo en el portafolio</li>
                            <li>Asegurarte de que tu letra esté completa y sea de tu autoría</li>
                            <li>Elegir el género musical que mejor se adapte a tu letra</li>
                            <li>Contactarnos si tienes preguntas antes de pagar</li>
                        </ul>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">6. Disputas de Pago</h2>
                        <p>
                            Si inicias una disputa o contracargo (chargeback) con tu banco o procesador de pagos sin
                            contactarnos primero, nos reservamos el derecho de suspender futuros servicios.
                            Te pedimos que nos contactes directamente para resolver cualquier problema.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">7. Contacto</h2>
                        <p>
                            ¿Tienes preguntas sobre nuestra política de reembolso? Contáctanos:
                        </p>
                        <div className="mt-4 space-y-2">
                            <p>
                                📧 Email:{' '}
                                <a href="mailto:refunds@strukymusicai.com" className="text-neon-purple hover:text-neon-blue underline">
                                    refunds@strukymusicai.com
                                </a>
                            </p>
                            <p>
                                💬 WhatsApp:{' '}
                                <a
                                    href="https://wa.me/1234567890"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                    className="text-neon-purple hover:text-neon-blue underline"
                                >
                                    +1 (234) 567-890
                                </a>
                            </p>
                        </div>
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
