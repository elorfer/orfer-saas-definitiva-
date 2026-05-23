import { Suspense } from 'react';
import ServiciosContent from './ServiciosClient';

export const metadata = {
    title: 'Servicios Profesionales de Distribución y Producción | Struky',
    description: 'Lleva tu música a YouTube y plataformas de streaming con nuestra producción profesional asistida por IA.',
    alternates: {
        canonical: 'https://www.struky.com/servicios',
    },
};

export default function ServiciosPage() {
    return (
        <Suspense fallback={<div className="min-h-screen bg-dark-bg" />}>
            <ServiciosContent />
        </Suspense>
    );
}
