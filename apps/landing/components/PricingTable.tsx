'use client';

import { Check, Star, Zap, Crown, Video } from 'lucide-react';
import { motion } from 'framer-motion';

interface PricingTableProps {
    onSelectPlan: (plan: string, price: number) => void;
}

export default function PricingTable({ onSelectPlan }: PricingTableProps) {
    const plans = [
        {
            id: 'starter',
            name: 'Starter',
            price: 50,
            description: 'La semilla de tu hit.',
            features: [
                'Producción estándar (48-72h)',
                '1 revisión musical',
                'Uso personal / Maqueta',
                'Calidad MP3 Alta Calidad'
            ],
            icon: Zap,
            highlight: false,
            cta: 'Empezar con Starter'
        },
        {
            id: 'pro',
            name: 'Pro Master',
            price: 97,
            description: 'Calidad Radio y Spotify.',
            features: [
                'Entrega Rápida (24h)',
                '3 revisiones musicales',
                'Derechos Comerciales 100%',
                'Calidad WAV Profesional',
                'OBSEQUIO: Video Letra HD'
            ],
            icon: Star,
            highlight: true,
            cta: 'Elegir Plan Pro'
        },
        {
            id: 'elite',
            name: 'Elite Studio',
            price: 147,
            description: 'Producción VIP Completa.',
            features: [
                'Prioridad Máxima en Estudio',
                'Revisiones Ilimitadas',
                'Entrega de Multitracks (Stems)',
                'Mezcla y Master Analógica',
                'OBSEQUIO: Video Letra HD'
            ],
            icon: Crown,
            highlight: false,
            cta: 'Elegir Plan Elite'
        }
    ];

    return (
        <section className="section-padding bg-dark-bg/50 relative overflow-hidden">
            <div className="max-w-6xl mx-auto px-6">
                <div className="text-center mb-16">
                    <h2 className="text-4xl md:text-6xl font-black mb-4 tracking-tighter">
                        Planes de <span className="text-gradient hover:glow-text transition-all duration-300">Producción</span>
                    </h2>
                    <p className="text-gray-400 text-lg md:text-xl max-w-2xl mx-auto">
                        Selecciona el nivel de acabado que tu música merece. Calidad internacional para el mercado global.
                    </p>
                </div>

                <div className="grid md:grid-cols-3 gap-8">
                    {plans.map((plan) => (
                        <motion.div
                            key={plan.id}
                            whileHover={{ y: -10 }}
                            className={`relative glass-morphism rounded-3xl p-8 border ${
                                plan.highlight 
                                ? 'border-coffee-medium shadow-[0_0_40px_rgba(202,160,82,0.15)] ring-1 ring-coffee-medium/50' 
                                : 'border-white/5'
                            } flex flex-col`}
                        >
                            {plan.highlight && (
                                <div className="absolute -top-4 left-1/2 -translate-x-1/2 bg-gradient-to-r from-coffee-medium to-coffee-light text-black text-[10px] font-black uppercase tracking-widest px-4 py-1.5 rounded-full shadow-lg z-10">
                                    Más Popular
                                </div>
                            )}

                            <div className="mb-8">
                                <div className={`w-12 h-12 rounded-2xl flex items-center justify-center mb-6 ${
                                    plan.highlight ? 'bg-coffee-medium text-black' : 'bg-white/5 text-coffee-light'
                                }`}>
                                    <plan.icon className="w-6 h-6" />
                                </div>
                                <h3 className="text-2xl font-black mb-2">{plan.name}</h3>
                                <p className="text-gray-500 text-sm">{plan.description}</p>
                            </div>

                            <div className="mb-8">
                                <div className="flex items-baseline gap-1">
                                    <span className="text-5xl font-black text-white">${plan.price}</span>
                                    <span className="text-gray-500 font-bold uppercase text-xs tracking-widest">USD</span>
                                </div>
                            </div>

                            <ul className="space-y-4 mb-10 flex-1">
                                {plan.features.map((feature, i) => (
                                    <li key={i} className={`flex items-start gap-3 text-sm ${feature.includes('OBSEQUIO') ? 'text-coffee-light font-bold' : 'text-gray-400'}`}>
                                        {feature.includes('Video Letra') ? (
                                            <Video className="w-5 h-5 shrink-0 text-coffee-medium animate-pulse" />
                                        ) : (
                                            <Check className={`w-5 h-5 shrink-0 ${plan.highlight ? 'text-coffee-light' : 'text-coffee-medium'}`} />
                                        )}
                                        {feature}
                                    </li>
                                ))}
                            </ul>

                            <button
                                onClick={() => {
                                    onSelectPlan(plan.name, plan.price);
                                    document.getElementById('order-form')?.scrollIntoView({ behavior: 'smooth' });
                                }}
                                className={`w-full py-4 rounded-xl font-black uppercase tracking-widest text-xs transition-all ${
                                    plan.highlight
                                    ? 'bg-coffee-medium text-black hover:bg-coffee-light shadow-[0_0_20px_rgba(202,160,82,0.3)]'
                                    : 'bg-white/5 text-white border border-white/10 hover:bg-white/10'
                                }`}
                            >
                                {plan.cta}
                            </button>
                        </motion.div>
                    ))}
                </div>
            </div>
        </section>
    );
}
