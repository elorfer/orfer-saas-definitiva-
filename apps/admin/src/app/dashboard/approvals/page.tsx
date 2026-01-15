'use client';

import { WrenchScrewdriverIcon } from '@heroicons/react/24/outline';

export default function ApprovalsPage() {
    return (
        <div className="min-h-[calc(100vh-8rem)] flex items-center justify-center p-4">
            <div className="text-center max-w-md">
                {/* Icono animado */}
                <div className="mb-8 flex justify-center">
                    <div className="relative">
                        <div className="absolute inset-0 bg-brown-200 rounded-full blur-3xl opacity-50 animate-pulse"></div>
                        <div className="relative bg-gradient-to-br from-brown-100 to-brown-200 rounded-full p-8">
                            <WrenchScrewdriverIcon className="h-24 w-24 text-brown-700 animate-bounce" />
                        </div>
                    </div>
                </div>

                {/* Título */}
                <h1 className="text-4xl font-bold text-gray-900 mb-4">
                    Aprobación
                </h1>

                {/* Descripción */}
                <p className="text-lg text-gray-600 mb-2">
                    Página en construcción
                </p>

                <div className="flex items-center justify-center gap-2 text-brown-700">
                    <div className="h-2 w-2 bg-brown-700 rounded-full animate-bounce" style={{ animationDelay: '0ms' }}></div>
                    <div className="h-2 w-2 bg-brown-700 rounded-full animate-bounce" style={{ animationDelay: '150ms' }}></div>
                    <div className="h-2 w-2 bg-brown-700 rounded-full animate-bounce" style={{ animationDelay: '300ms' }}></div>
                </div>

                {/* Mensaje adicional */}
                <div className="mt-8 p-4 bg-brown-50 rounded-xl border border-brown-200">
                    <p className="text-sm text-brown-800">
                        Estamos trabajando en esta funcionalidad. Pronto estará disponible.
                    </p>
                </div>
            </div>
        </div>
    );
}
