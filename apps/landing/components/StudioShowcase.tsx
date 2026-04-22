'use client';

import Image from 'next/image';

export default function StudioShowcase({ lang }: { lang: 'es' | 'en' }) {
    return (
        <section className="section-padding bg-dark-bg relative overflow-hidden border-t border-b border-white/5">
            <div className="absolute top-1/2 left-0 w-1/2 h-1/2 bg-coffee-dark/10 blur-[150px] rounded-full translate-y(-50%)"></div>
            
            <div className="max-w-7xl mx-auto grid lg:grid-cols-2 gap-12 items-center relative z-10">
                <div>
                    <h2 className="text-3xl md:text-5xl font-bold mb-6 font-heading">
                        {lang === 'es' ? 'Bienvenido a' : 'Welcome to'} <br/>
                        <span className="text-gradient tracking-tight">Struky Studios</span>
                    </h2>
                    
                    <p className="text-gray-400 text-lg mb-8 leading-relaxed">
                        {lang === 'es' 
                            ? 'No somos solo un algoritmo. Detrás de cada canción generada por nuestra IA avanzada, hay un estudio físico de primer nivel equipado con hardware analógico, donde productores reales perfeccionan cada frecuencia.' 
                            : 'We are not just an algorithm. Behind every AI-generated song, there is a physical top-tier studio equipped with analog hardware, where real producers perfect every frequency.'}
                    </p>
                    
                    <ul className="space-y-5 mb-8">
                        {[
                            lang === 'es' ? 'Equipamiento analógico de clase mundial' : 'World-class analog equipment',
                            lang === 'es' ? 'Monitoreo acústico de alta fidelidad' : 'High-fidelity acoustic monitoring',
                            lang === 'es' ? 'Sinergia perfecta entre IA y oído humano' : 'Perfect synergy between AI and human ear'
                        ].map((item, i) => (
                            <li key={i} className="flex items-center gap-4 text-sm md:text-base font-medium text-gray-300 group cursor-default">
                                <div className="w-8 h-8 rounded-full bg-coffee-medium/10 flex items-center justify-center shrink-0 border border-coffee-medium/20 group-hover:bg-coffee-medium/20 transition-colors shadow-[0_0_10px_rgba(202,160,82,0.1)]">
                                    <svg className="w-4 h-4 text-coffee-light" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M5 13l4 4L19 7"/></svg>
                                </div>
                                <span className="group-hover:text-white transition-colors">{item}</span>
                            </li>
                        ))}
                    </ul>
                </div>

                <div className="relative aspect-[4/3] rounded-2xl overflow-hidden shadow-2xl shadow-black/80 border border-white/10 group">
                    <Image
                        src="/images/studio_main.webp"
                        alt="Struky Studios Professional Console"
                        fill
                        className="object-cover group-hover:scale-105 transition-transform duration-700"
                    />
                    <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent"></div>
                </div>
            </div>
        </section>
    );
}
