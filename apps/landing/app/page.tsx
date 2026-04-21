'use client';

import { useState } from 'react';
import Header from '../components/Header';
import Hero from '../components/Hero';
import ProfessionalAudioPlayer from '../components/ProfessionalAudioPlayer';
import ComposersSection from '../components/ComposersSection';
import StudioShowcase from '../components/StudioShowcase';
import OrderForm from '../components/OrderForm';
import Footer from '../components/Footer';
import Benefits from '../components/Benefits';
import HowItWorks from '../components/HowItWorks';
import Testimonials from '../components/Testimonials';
import FAQ from '../components/FAQ';
import PricingTable from '../components/PricingTable';
import { translations } from '../lib/translations';
import { useSearchParams } from 'next/navigation';
import { Suspense } from 'react';
import { Music } from 'lucide-react';

function HomeContent() {
    const searchParams = useSearchParams();
    const [lang, setLang] = useState<'es' | 'en'>('es');
    const t = translations[lang];

    useEffect(() => {
        // Solo respetamos el parámetro de URL si existe, de lo contrario forzamos Español
        const urlLang = searchParams.get('lang');
        if (urlLang === 'en' || urlLang === 'es') {
            setLang(urlLang as 'es' | 'en');
        }
    }, [searchParams]);


    const examples = [
        {
            title: "Por eso tomo",
            desc: lang === 'es' ? "Música Popular • 3:20" : "Popular Music • 3:20",
            src: "/examples/por-eso-tomo.mp3",
            cover: "/examples/cover_por_eso_tomo.png"
        },
        {
            title: "Un día",
            desc: lang === 'es' ? "Vallenato Sentimental • 3:45" : "Sentimental Vallenato • 3:45",
            src: "/examples/un-dia.mp3",
            cover: "/examples/cover_un_dia.png"
        },
        {
            title: "Señora",
            desc: lang === 'es' ? "Ranchera Romántica • 3:12" : "Romantic Ranchera • 3:12",
            src: "/examples/ejemplo2.mp3",
            cover: "/examples/cover_senora.png"
        },
        {
            title: "Me Gustas",
            desc: lang === 'es' ? "Salsa Romántica • 2:58" : "Romantic Salsa • 2:58",
            src: "/examples/ejemplo3.mp3",
            cover: "/examples/cover_me_gustas.png"
        },
        {
            title: "Mi Amor Bonito",
            desc: lang === 'es' ? "Pop Romántico • 4:15" : "Romantic Pop • 4:15",
            src: "/examples/mi-amor-bonito.mp3",
            cover: "/examples/cover_mi_amor_bonito.png"
        },
        {
            title: "Bailame Suave",
            desc: lang === 'es' ? "Urbano • 3:12" : "Urban • 3:12",
            src: "/examples/bailame-suave.mp3",
            cover: "/examples/cover_bailame_suave.png"
        }
    ];

    return (
        <main className="min-h-screen bg-dark-bg font-sans selection:bg-coffee-medium selection:text-white pb-24 md:pb-0">
            <Header lang={lang} setLang={setLang} />
            
            <Hero t={t.hero} lang={lang} />

            {/* EXAMPLES SECTION */}
            <section id="examples" className="section-padding bg-dark-bg relative overflow-hidden">
                {/* Background Decor */}
                <div className="absolute top-1/4 -left-20 w-80 h-80 bg-coffee-medium/10 rounded-full blur-[120px] pointer-events-none"></div>
                <div className="absolute bottom-1/4 -right-20 w-80 h-80 bg-coffee-medium/10 rounded-full blur-[120px] pointer-events-none"></div>
                
                <div className="max-w-6xl mx-auto relative z-10">
                    <div className="text-center mb-16">
                        <h2 className="text-4xl md:text-6xl font-black mb-4 tracking-tighter">
                            {t.examples.title.split(' ')[0]} <span className="text-gradient">{t.examples.title.split(' ').slice(1).join(' ')}</span>
                        </h2>
                        <p className="text-gray-400 text-lg md:text-xl max-w-2xl mx-auto">
                            {t.examples.subtitle}
                        </p>
                    </div>

                    <div className="grid grid-cols-2 md:grid-cols-2 lg:grid-cols-3 gap-3 md:gap-6">
                        {examples.map((example, i) => (
                            <ProfessionalAudioPlayer 
                                key={i}
                                src={example.src}
                                title={example.title}
                                description={example.desc}
                                cover={example.cover}
                            />
                        ))}
                    </div>
                </div>
            </section>

            <Benefits t={t.benefits} />

            <HowItWorks t={t.howItWorks} />

            <StudioShowcase lang={lang} />

            <ComposersSection lang={lang} />

            <Testimonials t={t.testimonials} />

            <PricingTable 
                t={t.pricing} 
                onSelectPlan={() => document.getElementById('order-form')?.scrollIntoView({ behavior: 'smooth' })} 
            />

            <OrderForm lang={lang} />

            <FAQ t={t.faq} />

            <Footer lang={lang} />

            {/* Sticky Mobile CTA */}
            <div className="fixed bottom-0 left-0 right-0 p-4 bg-gradient-to-t from-dark-bg/95 via-dark-bg/90 to-transparent z-[50] md:hidden pointer-events-none backdrop-blur-sm">
                <button 
                    onClick={() => document.getElementById('order-form')?.scrollIntoView({ behavior: 'smooth' })}
                    className="w-full btn-primary py-4 text-base tracking-widest font-black uppercase pointer-events-auto shadow-[0_0_20px_rgba(202,160,82,0.3)] mb-2 flex items-center justify-center gap-2"
                >
                    <Music className="w-5 h-5" />
                    {t.hero.stickyCTA}
                </button>
            </div>
        </main>
    );
}

export default function HomePage() {
    return (
        <Suspense fallback={<div className="min-h-screen bg-dark-bg" />}>
            <HomeContent />
        </Suspense>
    );
}
