'use client';

import { Check, X, Clock, DollarSign, ShieldCheck, UserCheck } from 'lucide-react';

export default function ComparisonSection({ lang }: { lang: 'es' | 'en' }) {
    const isEs = lang === 'es';

    const comparisonData = [
        {
            feature: isEs ? "Costo Promedio" : "Average Cost",
            traditional: "$2,000+ USD",
            struky: "$50 - $147 USD",
            icon: <DollarSign className="w-5 h-5" />
        },
        {
            feature: isEs ? "Tiempo de Entrega" : "Delivery Time",
            traditional: isEs ? "3 - 6 Semanas" : "3 - 6 Weeks",
            struky: isEs ? "24 - 48 Horas" : "24 - 48 Hours",
            icon: <Clock className="w-5 h-5" />
        },
        {
            feature: isEs ? "Derechos de Autor" : "Copyright Ownership",
            traditional: isEs ? "Compartidos / Regalías" : "Shared / Royalties",
            struky: isEs ? "100% Tuyos (Contrato)" : "100% Yours (Contract)",
            icon: <ShieldCheck className="w-5 h-5" />
        },
        {
            feature: isEs ? "Productor Real" : "Real Producer",
            traditional: <Check className="text-green-500 w-6 h-6 mx-auto" />,
            struky: <Check className="text-coffee-medium w-6 h-6 mx-auto" />,
            icon: <UserCheck className="w-5 h-5" />
        },
        {
            feature: isEs ? "Revisiones Ilimitadas" : "Unlimited Revisions",
            traditional: <X className="text-red-500 w-6 h-6 mx-auto" />,
            struky: <Check className="text-coffee-medium w-6 h-6 mx-auto" />,
            icon: <ShieldCheck className="w-5 h-5" />
        }
    ];

    return (
        <section className="section-padding bg-dark-bg relative overflow-hidden border-t border-white/5">
            <div className="max-w-4xl mx-auto px-4 relative z-10">
                <div className="text-center mb-12 md:mb-16">
                    <h2 className="text-3xl md:text-5xl font-black mb-4 tracking-tighter uppercase italic">
                        {isEs ? '¿Por qué' : 'Why'} <span className="text-gradient pr-2">Struky</span> {isEs ? 'y no un estudio?' : 'vs Traditional Studios?'}
                    </h2>
                    <p className="text-gray-400 text-sm md:text-lg max-w-2xl mx-auto font-medium">
                        {isEs 
                            ? 'Comparamos la industria tradicional con la revolución de Struky. Misma calidad, fracción del costo.' 
                            : 'We compare the traditional industry with the Struky revolution. Same quality, fraction of the cost.'}
                    </p>
                </div>

                <div className="bg-[#0A0A0A] border border-white/10 rounded-[2.5rem] overflow-hidden shadow-2xl">
                    <div className="grid grid-cols-3 bg-white/5 border-b border-white/10 p-4 md:p-6 text-center items-center">
                        <div className="text-left text-[10px] md:text-xs font-black uppercase tracking-widest text-gray-500">
                            {isEs ? 'Característica' : 'Feature'}
                        </div>
                        <div className="text-red-400/80 text-[10px] md:text-xs font-black uppercase tracking-widest">
                            {isEs ? 'Estudio Tradicional' : 'Traditional Studio'}
                        </div>
                        <div className="text-coffee-light text-[10px] md:text-xs font-black uppercase tracking-widest">
                            Struky Elite
                        </div>
                    </div>

                    <div className="divide-y divide-white/5">
                        {comparisonData.map((row, i) => (
                            <div key={i} className="grid grid-cols-3 p-4 md:p-8 text-center items-center hover:bg-white/[0.02] transition-colors">
                                <div className="flex items-center gap-2 md:gap-4 text-left">
                                    <div className="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center text-gray-400 hidden md:flex">
                                        {row.icon}
                                    </div>
                                    <span className="text-[11px] md:text-base font-bold text-white/90 leading-tight">
                                        {row.feature}
                                    </span>
                                </div>
                                <div className="text-[11px] md:text-base font-medium text-gray-500">
                                    {row.traditional}
                                </div>
                                <div className="text-[12px] md:text-lg font-black text-coffee-light">
                                    {row.struky}
                                </div>
                            </div>
                        ))}
                    </div>

                    {/* Bottom CTA Highlight */}
                    <div className="p-8 bg-coffee-medium/5 text-center border-t border-white/5">
                        <p className="text-xs md:text-sm text-gray-400 font-bold">
                            {isEs 
                                ? 'Ahorras más del 90% en costos y semanas de tiempo perdido.' 
                                : 'You save over 90% in costs and weeks of wasted time.'}
                        </p>
                    </div>
                </div>

                {/* Trust Badges */}
                <div className="mt-12 flex flex-wrap justify-center gap-8 md:gap-16 opacity-40 grayscale hover:grayscale-0 transition-all duration-700">
                    <div className="flex items-center gap-2">
                        <Check className="w-4 h-4 text-coffee-medium" />
                        <span className="text-[10px] font-black uppercase tracking-widest text-white">Radio Ready</span>
                    </div>
                    <div className="flex items-center gap-2">
                        <Check className="w-4 h-4 text-coffee-medium" />
                        <span className="text-[10px] font-black uppercase tracking-widest text-white">Full Copyright</span>
                    </div>
                    <div className="flex items-center gap-2">
                        <Check className="w-4 h-4 text-coffee-medium" />
                        <span className="text-[10px] font-black uppercase tracking-widest text-white">SSL Encrypted</span>
                    </div>
                </div>
            </div>
        </section>
    );
}
