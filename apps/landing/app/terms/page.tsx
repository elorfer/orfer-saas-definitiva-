import Link from 'next/link';

export const metadata = {
    title: 'Términos de Servicio | Struky',
    description: 'Términos y condiciones de uso para la producción de canciones y derechos de propiedad intelectual en Struky.',
    alternates: {
        canonical: 'https://www.struky.com/terms',
    },
};

export default function TermsPage() {
    return (
        <div className="min-h-screen section-padding">
            <div className="max-w-4xl mx-auto">
                <Link href="/" className="inline-flex items-center text-coffee-medium hover:text-coffee-light mb-8 transition-colors">
                    ← Volver al inicio
                </Link>

                <h1 className="text-4xl md:text-5xl font-heading font-bold mb-8">
                    Términos de <span className="text-gradient">Servicio</span>
                </h1>

                <div className="card-dark space-y-6 text-gray-300">
                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">1. Aceptación de los Términos</h2>
                        <p>
                            Al acceder y utilizar los servicios de Struky, aceptas estar sujeto a estos Términos de Servicio.
                            Si no estás de acuerdo con alguna parte de estos términos, no debes utilizar nuestros servicios.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">2. Descripción del Servicio</h2>
                        <p className="mb-3">
                            Struky ofrece servicios de producción musical asistida por inteligencia artificial avanzada,
                            supervisada y refinada por productores musicales profesionales humanos. Convertimos letras de canciones proporcionadas por el cliente
                            en producciones musicales de calidad profesional.
                        </p>
                        <p>
                            Dependiendo del plan elegido (Pro o Elite), el servicio puede incluir un <strong>Video Obsequio</strong> (visualizer o video lírico sencillo) como complemento a la producción musical. Este video es un valor añadido y no constituye el núcleo principal del servicio de producción.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">3. Proceso de Pedido</h2>
                        <ul className="list-disc list-inside space-y-2 ml-4">
                            <li>El cliente proporciona la letra de la canción y el género musical deseado</li>
                            <li>El pago debe completarse antes de iniciar la producción</li>
                            <li>El tiempo de entrega estimado es de 24-48 horas desde la confirmación del pago</li>
                            <li>La entrega se realiza por email o WhatsApp según la preferencia del cliente</li>
                        </ul>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">4. Derechos de Propiedad Intelectual</h2>
                        <p className="mb-3">
                            <strong>4.1 Letra Original:</strong> El cliente garantiza que es el autor original de la letra
                            proporcionada o tiene los derechos necesarios para su uso.
                        </p>
                        <p className="mb-3">
                            <strong>4.2 Producción Musical:</strong> Una vez completado el pago, el cliente recibe todos
                            los derechos de la producción musical final para uso personal o comercial.
                        </p>
                        <p>
                            <strong>4.3 Portafolio:</strong> Struky se reserva el derecho de utilizar fragmentos
                            de las producciones como ejemplos de portafolio, salvo que el cliente solicite lo contrario.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">5. Pagos y Precios</h2>
                        <ul className="list-disc list-inside space-y-2 ml-4">
                            <li>Todos los precios están expresados en dólares estadounidenses (USD)</li>
                            <li>El pago debe realizarse por adelantado a través de Stripe</li>
                            <li>Los precios pueden cambiar sin previo aviso</li>
                            <li>Las promociones especiales están sujetas a términos específicos</li>
                        </ul>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">6. Garantías y Limitaciones</h2>
                        <p className="mb-3">
                            <strong>6.1 Garantía de Calidad:</strong> Nos comprometemos a entregar producciones musicales
                            de calidad profesional utilizando IA avanzada supervisada por expertos humanos.
                        </p>
                        <p className="mb-3">
                            <strong>6.2 Limitaciones:</strong> No garantizamos resultados comerciales específicos.
                            La calidad de la producción depende en parte de la calidad de la letra proporcionada.
                        </p>
                        <p>
                            <strong>6.3 Revisiones:</strong> Ofrecemos hasta una (1) revisión menor por pedido para
                            ajustes razonables, sujeto a disponibilidad.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">7. Conducta del Usuario</h2>
                        <p>El cliente se compromete a:</p>
                        <ul className="list-disc list-inside space-y-2 ml-4">
                            <li>No proporcionar contenido ofensivo, ilegal o que infrinja derechos de terceros</li>
                            <li>No intentar replicar, copiar o revender nuestro servicio</li>
                            <li>Comunicarse de manera respetuosa con nuestro equipo</li>
                        </ul>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">8. Limitación de Responsabilidad</h2>
                        <p>
                            Struky no será responsable por daños indirectos, incidentales, especiales o consecuentes
                            que resulten del uso o la imposibilidad de usar nuestros servicios, incluso si hemos sido advertidos
                            de la posibilidad de dichos daños.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">9. Modificaciones de los Términos</h2>
                        <p>
                            Nos reservamos el derecho de modificar estos términos en cualquier momento. Los cambios entrarán
                            en vigencia inmediatamente después de su publicación en el sitio web.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">10. Ley Aplicable</h2>
                        <p>
                            Estos términos se rigen por las leyes de la República de Colombia.
                            Cualquier disputa será resuelta en los tribunales competentes de Colombia.
                        </p>
                    </section>

                    <section>
                        <h2 className="text-2xl font-bold text-white mb-4">11. Contacto</h2>
                        <p>
                            Para preguntas sobre estos términos, contáctanos en:{' '}
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
