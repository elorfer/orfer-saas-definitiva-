'use client';

import { useState, useEffect, Suspense, useRef } from 'react';
import dynamic from 'next/dynamic';
import Image from 'next/image';
import Header from '../components/Header';
import Hero from '../components/Hero';
import ProfessionalAudioPlayer from '../components/ProfessionalAudioPlayer';
import PlatformLogos from '../components/PlatformLogos';
import { translations } from '../lib/translations';
import { useSearchParams } from 'next/navigation';
import { Music, ChevronLeft, ChevronRight } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { playSuccess, playWhoosh, playTick } from '../lib/soundEngine';

// Lazy-load below-the-fold components (code-split into separate chunks)
const HowItWorks = dynamic(() => import('../components/HowItWorks'));
const StudioShowcase = dynamic(() => import('../components/StudioShowcase'));
const ComposersSection = dynamic(() => import('../components/ComposersSection'));
const Testimonials = dynamic(() => import('../components/Testimonials'));
const PricingTable = dynamic(() => import('../components/PricingTable'));
const OrderForm = dynamic(() => import('../components/OrderForm'));
const FAQ = dynamic(() => import('../components/FAQ'));
const MerchSection = dynamic(() => import('../components/MerchSection'));
const Footer = dynamic(() => import('../components/Footer'));
const OfficialShowcase = dynamic(() => import('../components/OfficialShowcase'));
const AudioComparison = dynamic(() => import('../components/AudioComparison'));
const ComparisonSection = dynamic(() => import('../components/ComparisonSection'));
const RecentActivity = dynamic(() => import('../components/RecentActivity'));
const GlobalImpact = dynamic(() => import('../components/GlobalImpact'));
const MemorableEvents = dynamic(() => import('../components/MemorableEvents'));


function HomeContent() {
    const [activeExampleIndex, setActiveExampleIndex] = useState(0);
    const examplesScrollRef = useRef<HTMLDivElement>(null);
    const examplesSectionRef = useRef<HTMLElement>(null);
    const scrollTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

    const scrollToExample = (index: number) => {
        playTick();
        if (examplesScrollRef.current) {
            const container = examplesScrollRef.current;
            const cards = Array.from(container.children) as HTMLElement[];
            if (cards[index]) {
                // Scroll to the actual card position instead of estimating
                const card = cards[index];
                const scrollLeft = card.offsetLeft - (container.offsetWidth - card.offsetWidth) / 2;
                container.scrollTo({
                    left: Math.max(0, scrollLeft),
                    behavior: 'smooth'
                });
            }
            setActiveExampleIndex(index);
        }
    };

    const handleExamplesScroll = () => {
        // Debounce: only update after scrolling stops for 80ms
        if (scrollTimeoutRef.current) {
            clearTimeout(scrollTimeoutRef.current);
        }
        scrollTimeoutRef.current = setTimeout(() => {
            if (examplesScrollRef.current) {
                const container = examplesScrollRef.current;
                const scrollPosition = container.scrollLeft;
                const containerWidth = container.offsetWidth;
                
                const cards = Array.from(container.children) as HTMLElement[];
                if (cards.length === 0) return;

                const containerCenter = scrollPosition + containerWidth / 2;
                
                let closestIndex = 0;
                let minDistance = Infinity;

                cards.forEach((card, i) => {
                    const cardCenter = card.offsetLeft + card.offsetWidth / 2;
                    const distance = Math.abs(containerCenter - cardCenter);
                    if (distance < minDistance) {
                        minDistance = distance;
                        closestIndex = i;
                    }
                });

                if (closestIndex !== activeExampleIndex) {
                    setActiveExampleIndex(closestIndex);
                }
            }
        }, 80);
    };

    const searchParams = useSearchParams();
    const [lang, setLang] = useState<'es' | 'en'>('es');
    const [showStickyCTA, setShowStickyCTA] = useState(false);
    const [isFormVisible, setIsFormVisible] = useState(false);
    const [isPricingVisible, setIsPricingVisible] = useState(false);
    const [isComparisonVisible, setIsComparisonVisible] = useState(false);
    const [selectedPlanFromTable, setSelectedPlanFromTable] = useState<string | null>(null);
    const t = translations[lang];

    useEffect(() => {
        // Solo respetamos el parámetro de URL si existe, de lo contrario forzamos Español
        const urlLang = searchParams.get('lang');
        if (urlLang === 'en' || urlLang === 'es') {
            setLang(urlLang as 'es' | 'en');
        }

        const urlPlan = searchParams.get('plan');
        if (urlPlan) {
            setSelectedPlanFromTable(urlPlan);
        }

        let isTicking = false;
        const handleScroll = () => {
            if (!isTicking) {
                window.requestAnimationFrame(() => {
                    if (window.scrollY > 500) {
                        setShowStickyCTA(true);
                    } else {
                        setShowStickyCTA(false);
                    }
                    isTicking = false;
                });
                isTicking = true;
            }
        };

        // Observador para el formulario
        const observer = new IntersectionObserver(
            ([entry]) => {
                setIsFormVisible(entry.isIntersecting);
            },
            { threshold: 0.1 }
        );

        // Observador para la sección de precios
        const pricingObserver = new IntersectionObserver(
            ([entry]) => {
                setIsPricingVisible(entry.isIntersecting);
            },
            { threshold: 0.1 }
        );

        const formElement = document.getElementById('order-form');
        const pricingElement = document.getElementById('pricing');
        const comparisonElement = document.getElementById('audio-comparison');

        if (formElement) observer.observe(formElement);
        if (pricingElement) pricingObserver.observe(pricingElement);
        
        // Observador para la sección de comparación
        const comparisonObserver = new IntersectionObserver(
            ([entry]) => {
                setIsComparisonVisible(entry.isIntersecting);
            },
            { threshold: 0.2 }
        );
        if (comparisonElement) comparisonObserver.observe(comparisonElement);

        window.addEventListener('scroll', handleScroll);
        return () => {
            window.removeEventListener('scroll', handleScroll);
            if (formElement) observer.unobserve(formElement);
            if (pricingElement) pricingObserver.unobserve(pricingElement);
            if (comparisonElement) comparisonObserver.unobserve(comparisonElement);
        };
    }, [searchParams]);


    const examples = [
        {
            title: "Por eso tomo",
            desc: lang === 'es' ? "Música Popular • 3:20" : "Popular Music • 3:20",
            src: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/por-eso-tomo.mp3",
            cover: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/cover_por_eso_tomo.png"
        },
        {
            title: "Un día",
            desc: lang === 'es' ? "Vallenato Sentimental • 3:45" : "Sentimental Vallenato • 3:45",
            src: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/un-dia.mp3",
            cover: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/UNDIA.webp"
        },
        {
            title: "Señora",
            desc: lang === 'es' ? "Ranchera Romántica • 3:12" : "Romantic Ranchera • 3:12",
            src: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/ejemplo2.mp3",
            cover: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/señoravip.webp"
        },
        {
            title: "Me Gustas",
            desc: lang === 'es' ? "Salsa Romántica • 2:58" : "Romantic Salsa • 2:58",
            src: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/ejemplo3.mp3",
            cover: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/MEGUSTASSALSA.webp"
        },
        {
            title: "Mi Amor Bonito",
            desc: lang === 'es' ? "Pop Romántico • 4:15" : "Romantic Pop • 4:15",
            src: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/mi-amor-bonito.mp3",
            cover: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/cover_mi_amor_bonito.png"
        },
        {
            title: "Bailame Suave",
            desc: lang === 'es' ? "Urbano • 3:12" : "Urban • 3:12",
            src: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/bailame-suave.mp3",
            cover: "https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/bailame%20suave.webp"
        }
    ];

    // playSuccess is now imported from soundEngine (preloaded, zero-latency)

    const handleSelectPlan = async (planId: string, price: number) => {
        playSuccess();
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
        <main className="min-h-screen bg-dark-bg font-sans selection:bg-coffee-medium selection:text-white pb-24 md:pb-0 overflow-x-hidden max-w-full">
            <Header lang={lang} setLang={setLang} />
            
            <Hero t={t.hero} lang={lang} />


            {/* === CONVERSION PATH: Hero → Ejemplos → Precios → Formulario === */}

            {/* EXAMPLES SECTION — Audio real = la mejor prueba */}
            <section ref={examplesSectionRef} id="examples" className="pt-0 bg-dark-bg relative z-20 scroll-mt-0 pb-32 md:pb-24">
                {/* Background Decor - Simplified for performance */}
                <div className="absolute top-1/4 -left-20 w-80 h-80 bg-coffee-medium/5 rounded-full pointer-events-none" />
                <div className="absolute bottom-1/4 -right-20 w-80 h-80 bg-coffee-medium/5 rounded-full pointer-events-none" />
                
                <div className="max-w-7xl mx-auto relative z-10">
                    {/* The Mascot (The Grandpa) */}
                    <motion.div 
                        className="hidden md:block absolute -top-24 right-0 lg:right-12 z-40 w-56 h-56 lg:w-72 lg:h-72 drop-shadow-[0_20px_30px_rgba(0,0,0,0.5)] pointer-events-none"
                        animate={{ 
                            y: [0, -15, 0],
                            rotate: [-1, 2, -1],
                            scale: [1, 1.02, 1]
                        }}
                        transition={{ 
                            duration: 4, 
                            repeat: Infinity, 
                            ease: "easeInOut" 
                        }}
                    >
                        <Image 
                            src="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/mascot.webp" 
                            alt="Mascota Struky Productor" 
                            fill
                            className="object-contain drop-shadow-[0_0_20px_rgba(202,160,82,0.3)]"
                            sizes="(max-width: 1024px) 224px, 288px"
                            unoptimized
                        />
                    </motion.div>
                    
                    {/* Mascot Mobile (Smaller, different placement to not block text) */}
                    <motion.div 
                        className="md:hidden mx-auto mb-6 w-64 h-64 relative drop-shadow-2xl pointer-events-none"
                        animate={{ 
                            y: [0, -10, 0],
                        }}
                        transition={{ 
                            duration: 3, 
                            repeat: Infinity, 
                            ease: "easeInOut" 
                        }}
                    >
                        <Image 
                            src="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/mascot.webp" 
                            alt="Mascota Struky Productor" 
                            fill
                            className="object-contain"
                            sizes="256px"
                            unoptimized
                        />
                    </motion.div>
                    <div className="text-center pt-8 md:pt-16 mb-16 px-4">
                        <h2 className="text-4xl md:text-6xl font-black mb-4 tracking-tighter">
                            {t.examples.title.split(' ')[0]} <span className="text-gradient">{t.examples.title.split(' ').slice(1).join(' ')}</span>
                        </h2>
                        <p className="text-gray-400 text-lg md:text-xl max-w-2xl mx-auto">
                            {t.examples.subtitle}
                        </p>
                    </div>

                    <div className="relative">
                        <div 
                            ref={examplesScrollRef}
                            onScroll={handleExamplesScroll}
                            className="flex md:grid md:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-8 overflow-x-auto md:overflow-visible pb-4 md:pb-0 px-2 md:px-0 snap-x snap-mandatory custom-scrollbar-hide"
                        >
                            {examples.map((example, i) => (
                                <div 
                                    key={i}
                                    className="flex-shrink-0 w-[260px] md:w-full md:max-w-[300px] mx-auto snap-center"
                                >
                                    <ProfessionalAudioPlayer 
                                        src={example.src}
                                        title={example.title}
                                        description={example.desc}
                                        cover={example.cover}
                                    />
                                </div>
                            ))}
                        </div>

                        <div className="text-center md:hidden mt-0 mb-3">
                            <p className="text-[10px] text-gray-500 uppercase tracking-widest font-black animate-pulse">
                                {lang === 'es' ? '👈 Desliza o usa las flechas 👉' : '👈 Slide or use arrows 👉'}
                            </p>
                        </div>
                        {/* Navigation for Mobile */}
                        <div className="flex md:hidden items-center justify-center gap-6 relative z-[60]">
                            <button 
                                onClick={() => scrollToExample(activeExampleIndex > 0 ? activeExampleIndex - 1 : examples.length - 1)}
                                className="w-10 h-10 rounded-full border border-white/10 flex items-center justify-center bg-white/5 active:bg-coffee-medium transition-all"
                            >
                                <ChevronLeft className="w-5 h-5" />
                            </button>
                            
                            <div className="flex gap-2">
                                {examples.map((_, i) => (
                                    <div 
                                        key={i} 
                                        className={`w-1.5 h-1.5 rounded-full transition-all duration-300 ${activeExampleIndex === i ? 'w-4 bg-coffee-medium' : 'bg-white/20'}`} 
                                    />
                                ))}
                            </div>

                            <button 
                                onClick={() => scrollToExample(activeExampleIndex < examples.length - 1 ? activeExampleIndex + 1 : 0)}
                                className="w-10 h-10 rounded-full border border-white/10 flex items-center justify-center bg-white/5 active:bg-coffee-medium transition-all"
                            >
                                <ChevronRight className="w-5 h-5" />
                            </button>
                        </div>
                    </div>
                </div>
            </section>

            <PlatformLogos lang={lang} />

            <OfficialShowcase lang={lang} />

            <PricingTable 
                t={t.pricing} 
                onSelectPlan={handleSelectPlan} 
            />

            <OrderForm lang={lang} initialPlan={selectedPlanFromTable} />



            {/* === CONTENIDO SECUNDARIO: Resolución de objeciones === */}

            <HowItWorks t={t.howItWorks} />

            <ComparisonSection lang={lang} />

            <AudioComparison lang={lang} />

            <Testimonials t={t.testimonials} />

            <FAQ t={t.faq} />

            {/* Mini-CTA: Recupera usuarios que leyeron todo el contenido */}
            <section className="py-20 md:py-28 bg-gradient-to-b from-transparent via-coffee-medium/5 to-transparent relative overflow-hidden">
                <div className="absolute inset-0 pointer-events-none">
                    <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-coffee-medium/5 rounded-full blur-3xl" />
                </div>
                <div className="max-w-2xl mx-auto text-center px-6 relative z-10">
                    <p className="text-xs font-black uppercase tracking-[0.3em] text-coffee-medium mb-4">
                        {lang === 'es' ? '¿Ya escuchaste los ejemplos?' : 'Already heard the examples?'}
                    </p>
                    <h3 className="text-3xl md:text-5xl font-black text-white tracking-tighter mb-6">
                        {lang === 'es' ? 'Tu canción está a ' : 'Your song is '}
                        <span className="text-gradient">{lang === 'es' ? 'un clic' : 'one click away'}</span>
                    </h3>
                    <p className="text-gray-400 text-sm md:text-base mb-10 max-w-md mx-auto leading-relaxed">
                        {lang === 'es'
                            ? 'Escríbenos tu idea, elige tu estilo y recibe tu canción profesional en 48 horas.'
                            : 'Write your idea, choose your style and receive your professional song in 48 hours.'}
                    </p>
                    <button
                        onClick={() => {
                            playWhoosh();
                            document.getElementById('order-form')?.scrollIntoView({ behavior: 'smooth' });
                        }}
                        className="bg-coffee-medium hover:bg-coffee-light text-black font-black uppercase tracking-[0.15em] py-4 px-10 rounded-full transition-all hover:scale-105 active:scale-95 shadow-[0_10px_40px_rgba(202,160,82,0.3)] text-sm md:text-base inline-flex items-center gap-3"
                    >
                        <Music className="w-5 h-5" />
                        {lang === 'es' ? 'CREAR MI CANCIÓN AHORA' : 'CREATE MY SONG NOW'}
                    </button>
                </div>
            </section>

            {/* === BRANDING & AUTORIDAD === */}

            <GlobalImpact t={t.global} />

            <StudioShowcase lang={lang} />

            {/* <MemorableEvents lang={lang} /> — Oculto temporalmente, se activa después */}

            {/* === POST-CONVERSION: Contenido para los que siguen explorando === */}

            <ComposersSection lang={lang} />

            <MerchSection lang={lang} />

            <Footer lang={lang} />

            {/* <RecentActivity lang={lang} /> - Desactivado por petición del usuario (estorbaban) */}

            {/* Sticky Mobile CTA */}
            <AnimatePresence>
                {showStickyCTA && !isFormVisible && !isPricingVisible && (
                    <motion.div 
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        transition={{ duration: 0.3 }}
                        className="fixed bottom-4 left-4 right-4 z-[50] md:hidden pointer-events-none pb-[env(safe-area-inset-bottom)]"
                    >
                        <motion.button 
                            onClick={() => {
                                playWhoosh();
                                document.getElementById('order-form')?.scrollIntoView({ behavior: 'smooth' });
                            }}
                            whileHover={{ scale: 1.05 }}
                            whileTap={{ scale: 0.95 }}
                            animate={{ 
                                x: [0, -2, 2, -2, 2, 0],
                                transition: {
                                    duration: 0.5,
                                    repeat: Infinity,
                                    repeatDelay: 5,
                                    ease: "easeInOut"
                                }
                            }}
                            className="w-full btn-primary py-4 text-base tracking-widest font-black uppercase pointer-events-auto shadow-[0_0_20px_rgba(202,160,82,0.3)] flex items-center justify-center gap-2"
                        >
                            <Music className="w-5 h-5" />
                            {isComparisonVisible 
                                ? (lang === 'es' ? 'Quiero mi producción así' : 'I want my production like this')
                                : t.hero.stickyCTA
                            }
                        </motion.button>
                    </motion.div>
                )}
            </AnimatePresence>

            {/* Sticky Desktop CTA — Floating pill bottom-right */}
            <AnimatePresence>
                {showStickyCTA && !isFormVisible && !isPricingVisible && (
                    <motion.div
                        initial={{ opacity: 0, scale: 0.8, y: 20 }}
                        animate={{ opacity: 1, scale: 1, y: 0 }}
                        exit={{ opacity: 0, scale: 0.8, y: 20 }}
                        transition={{ duration: 0.4, type: 'spring', stiffness: 260, damping: 20 }}
                        className="fixed bottom-8 right-8 z-[50] hidden md:block"
                    >
                        <motion.button
                            onClick={() => {
                                playWhoosh();
                                document.getElementById('order-form')?.scrollIntoView({ behavior: 'smooth' });
                            }}
                            whileHover={{ scale: 1.05 }}
                            whileTap={{ scale: 0.95 }}
                            animate={{ 
                                x: [0, -2, 2, -2, 2, 0],
                                transition: {
                                    duration: 0.5,
                                    repeat: Infinity,
                                    repeatDelay: 5,
                                    ease: "easeInOut"
                                }
                            }}
                            className="group bg-coffee-medium hover:bg-coffee-light text-black font-black uppercase tracking-widest py-3.5 px-8 rounded-full transition-all shadow-[0_10px_40px_rgba(202,160,82,0.4)] text-xs flex items-center gap-3"
                        >
                            <Music className="w-4 h-4" />
                            {lang === 'es' ? 'CREAR MI CANCIÓN' : 'CREATE MY SONG'}
                            <span className="w-2 h-2 rounded-full bg-black/20 animate-pulse" />
                        </motion.button>
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
