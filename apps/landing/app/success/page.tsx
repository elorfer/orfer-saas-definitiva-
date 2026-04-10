import Link from 'next/link';

export default function SuccessPage() {
    return (
        <div className="min-h-screen flex items-center justify-center p-6 bg-dark-bg">
            <div className="card-dark max-w-lg w-full text-center py-12">
                <div className="w-20 h-20 bg-green-500/20 text-green-400 rounded-full flex items-center justify-center mx-auto mb-6 text-4xl">
                    ✓
                </div>
                <h1 className="text-3xl font-display font-bold mb-4">¡Pago Exitoso!</h1>
                <p className="text-gray-300 mb-8">
                    Hemos recibido correctamente tu orden por $50 USD y todos los requerimientos de tu canción.
                </p>
                <div className="bg-coffee-dark/20 border border-coffee-medium/30 rounded-lg p-6 mb-8 text-left">
                    <h3 className="font-bold text-coffee-light mb-4">¿Qué sigue ahora?</h3>
                    <ul className="text-sm text-gray-400 space-y-4">
                        <li className="flex items-start gap-3">
                            <span className="text-coffee-medium mt-0.5">1.</span>
                            Recibirás enseguida un recibo de compra oficial de Stripe en tu correo.
                        </li>
                        <li className="flex items-start gap-3">
                            <span className="text-coffee-medium mt-0.5">2.</span>
                            Nuestros productores analizarán tus letras y referencias enviadas para comenzar a iterar con la IA.
                        </li>
                        <li className="flex items-start gap-3">
                            <span className="text-coffee-medium mt-0.5">3.</span>
                            Recibirás en WhatsApp/Email tu máster final en las próximas 24 a 48 horas. ¡Atento!
                        </li>
                    </ul>
                </div>
                <Link href="/" className="btn-primary inline-flex px-8 py-3 rounded-full">
                    Volver a Inicio
                </Link>
            </div>
        </div>
    );
}
