'use client';

import { useState, useEffect, Suspense } from 'react';
import dynamic from 'next/dynamic';
import Image from 'next/image';
import Header from '../components/Header';
import Hero from '../components/Hero';
import ProfessionalAudioPlayer from '../components/ProfessionalAudioPlayer';
import PlatformLogos from '../components/PlatformLogos';
import { translations } from '../lib/translations';
import { useSearchParams } from 'next/navigation';
import { Music } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

// Lazy-load below-the-fold components (code-split into separate chunks)
const Benefits = dynamic(() => import('../components/Benefits'));
const HowItWorks = dynamic(() => import('../components/HowItWorks'));
const StudioShowcase = dynamic(() => import('../components/StudioShowcase'));
const ComposersSection = dynamic(() => import('../components/ComposersSection'));
const Testimonials = dynamic(() => import('../components/Testimonials'));
const PricingTable = dynamic(() => import('../components/PricingTable'));
const OrderForm = dynamic(() => import('../components/OrderForm'));
const FAQ = dynamic(() => import('../components/FAQ'));
const MerchSection = dynamic(() => import('../components/MerchSection'));
const Footer = dynamic(() => import('../components/Footer'));

function HomeContent() {
    const searchParams = useSearchParams();
    const [lang, setLang] = useState<'es' | 'en'>('es');
    const [showStickyCTA, setShowStickyCTA] = useState(false);
    const [isFormVisible, setIsFormVisible] = useState(false);
    const [selectedPlanFromTable, setSelectedPlanFromTable] = useState<string | null>(null);
    const t = translations[lang];

    useEffect(() => {
        // Solo respetamos el parámetro de URL si existe, de lo contrario forzamos Español
        const urlLang = searchParams.get('lang');
        if (urlLang === 'en' || urlLang === 'es') {
            setLang(urlLang as 'es' | 'en');
        }

        const handleScroll = () => {
            // Mostramos el botón solo después de bajar 500px y si el formulario no está visible
            if (window.scrollY > 500) {
                setShowStickyCTA(true);
            } else {
                setShowStickyCTA(false);
            }
        };

        // Observador para el formulario
        const observer = new IntersectionObserver(
            ([entry]) => {
                setIsFormVisible(entry.isIntersecting);
            },
            { threshold: 0.1 }
        );

        const formElement = document.getElementById('order-form');
        if (formElement) observer.observe(formElement);

        window.addEventListener('scroll', handleScroll);
        return () => {
            window.removeEventListener('scroll', handleScroll);
            if (formElement) observer.unobserve(formElement);
        };
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
            cover: "/images/UNDIA.webp"
        },
        {
            title: "Señora",
            desc: lang === 'es' ? "Ranchera Romántica • 3:12" : "Romantic Ranchera • 3:12",
            src: "/examples/ejemplo2.mp3",
            cover: "/images/señoravip.webp"
        },
        {
            title: "Me Gustas",
            desc: lang === 'es' ? "Salsa Romántica • 2:58" : "Romantic Salsa • 2:58",
            src: "/examples/ejemplo3.mp3",
            cover: "/examples/MEGUSTASSALSA.webp"
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
            cover: "/examples/bailame suave.webp"
        }
    ];

    const handleSelectPlan = async (planId: string, price: number) => {
        setSelectedPlanFromTable(planId);
        
        // Dynamically import confetti only when needed (saves ~29KB from initial bundle)
        const confetti = (await import('canvas-confetti')).default;
        const duration = 2 * 1000;
        const animationEnd = Date.now() + duration;
        const colors = ['#CAA052', '#8B6A35', '#ffffff'];

        const frame = () => {
            confetti({
                particleCount: 3,
                angle: 60,
                spread: 55,
                origin: { x: 0 },
                colors: colors
            });
            confetti({
                particleCount: 3,
                angle: 120,
                spread: 55,
                origin: { x: 1 },
                colors: colors
            });

            if (Date.now() < animationEnd) {
                requestAnimationFrame(frame);
            }
        };
        
        frame();
        document.getElementById('order-form')?.scrollIntoView({ behavior: 'smooth' });
    };

    return (
        <main className="min-h-screen bg-dark-bg font-sans selection:bg-coffee-medium selection:text-white pb-24 md:pb-0">
            <Header lang={lang} setLang={setLang} />
            
            <Hero t={t.hero} lang={lang} />

            <PlatformLogos lang={lang} />

            {/* EXAMPLES SECTION */}
            <section id="examples" className="section-padding bg-dark-bg relative overflow-hidden">
                {/* Background Decor - CSS-only animated orbs (GPU composited) */}
                <div className="bg-orb-1 absolute top-1/4 -left-20 w-80 h-80 bg-coffee-medium/10 rounded-full blur-[120px] pointer-events-none" />
                <div className="bg-orb-2 absolute bottom-1/4 -right-20 w-80 h-80 bg-coffee-medium/10 rounded-full blur-[120px] pointer-events-none" />
                
                <div className="max-w-7xl mx-auto relative z-10">
                    <div className="text-center mb-16">
                        <h2 className="text-4xl md:text-6xl font-black mb-4 tracking-tighter">
                            {t.examples.title.split(' ')[0]} <span className="text-gradient">{t.examples.title.split(' ').slice(1).join(' ')}</span>
                        </h2>
                        <p className="text-gray-400 text-lg md:text-xl max-w-2xl mx-auto">
                            {t.examples.subtitle}
                        </p>
                    </div>

                    <div className="grid grid-cols-2 lg:grid-cols-3 gap-4 md:gap-8">
                        {examples.map((example, i) => (
                            <div key={i}>
                                <ProfessionalAudioPlayer 
                                    src={example.src}
                                    title={example.title}
                                    description={example.desc}
                                    cover={example.cover}
                                />
                            </div>
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
                onSelectPlan={handleSelectPlan} 
            />

            <OrderForm lang={lang} initialPlan={selectedPlanFromTable} />

            <MerchSection lang={lang} />

            {/* Testimonials Banner Image */}
            <section className="section-padding bg-dark-bg relative overflow-hidden">
                <div className="max-w-7xl mx-auto px-4 relative z-10">
                    <div className="relative rounded-3xl overflow-hidden border border-white/10 shadow-2xl shadow-black/80 group">
                        <img 
                            src="/images/TESTIMONIOS.webp"
                            alt="Struky Studios Testimonials"
                            className="w-full h-auto block transition-transform duration-1000 group-hover:scale-105"
                        />
                        <div className="absolute inset-0 bg-gradient-to-t from-black/20 via-transparent to-transparent pointer-events-none"></div>
                    </div>
                </div>
            </section>

            <FAQ t={t.faq} />

            <Footer lang={lang} />

            {/* Sticky Mobile CTA with Animation */}
            <AnimatePresence>
                {showStickyCTA && !isFormVisible && (
                    <motion.div 
                        initial={{ y: 100, opacity: 0 }}
                        animate={{ y: 0, opacity: 1 }}
                        exit={{ y: 100, opacity: 0 }}
                        transition={{ type: "spring", stiffness: 260, damping: 20 }}
                        className="fixed bottom-0 left-0 right-0 p-4 bg-gradient-to-t from-dark-bg via-dark-bg/95 to-transparent z-[50] md:hidden pointer-events-none"
                    >
                        <button 
                            onClick={() => document.getElementById('order-form')?.scrollIntoView({ behavior: 'smooth' })}
                            className="w-full btn-primary py-4 text-base tracking-widest font-black uppercase pointer-events-auto shadow-[0_0_20px_rgba(202,160,82,0.3)] mb-2 flex items-center justify-center gap-2"
                        >
                            <Music className="w-5 h-5" />
                            {t.hero.stickyCTA}
                        </button>
                    </motion.div>
                )}
            </AnimatePresence>
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
