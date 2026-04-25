'use client';

import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import confetti from 'canvas-confetti';
import { translations } from '../lib/translations';
import { PLANS, PLAN_IDS } from '../lib/plans';
import { Check, Video, ChevronDown, Sparkles, Wand2, Loader2, Lock, ShieldCheck, CreditCard, Zap } from 'lucide-react';

const COUNTRIES = [
    { name: 'Estados Unidos', code: '+1', flag: '🇺🇸' },
    { name: 'Colombia', code: '+57', flag: '🇨🇴' },
    { name: 'México', code: '+52', flag: '🇲🇽' },
    { name: 'España', code: '+34', flag: '🇪🇸' },
    { name: 'Venezuela', code: '+58', flag: '🇻🇪' },
    { name: 'Argentina', code: '+54', flag: '🇦🇷' },
    { name: 'Chile', code: '+56', flag: '🇨🇱' },
    { name: 'Perú', code: '+51', flag: '🇵🇪' },
    { name: 'Ecuador', code: '+593', flag: '🇪🇨' },
    { name: 'Rep. Dominicana', code: '+1', flag: '🇩🇴' },
    { name: 'Panamá', code: '+507', flag: '🇵🇦' },
];

interface OrderFormProps {
    lang: 'es' | 'en';
    initialPlan?: string | null;
}

export default function OrderForm({ lang, initialPlan }: OrderFormProps) {
    const t = translations[lang];
    const [step, setStep] = React.useState(1);
    const [isLoading, setIsLoading] = React.useState(false);
    const [slots, setSlots] = useState(8); // Iniciar siempre en 8 para ver el descenso
    const [showCountrySelect, setShowCountrySelect] = React.useState(false);
    const [selectedCountry, setSelectedCountry] = React.useState(COUNTRIES[0]);

    // Efecto para simular actividad (FOMO)
    useEffect(() => {
        const interval = setInterval(() => {
            setSlots(prev => {
                const rand = Math.random();
                if (rand > 0.4) { // 60% probabilidad de bajar
                    return prev > 5 ? prev - 1 : 5; // Nunca baja de 5 cupos
                } else if (rand < 0.2) { // 20% probabilidad de subir
                    return prev < 12 ? prev + 1 : 11;
                }
                return prev;
            });
        }, 6000);

        return () => clearInterval(interval);
    }, []);

    const isInitialRender = useRef(true);

    // Efecto para auto-scroll al cambiar de paso
    useEffect(() => {
        if (isInitialRender.current) {
            isInitialRender.current = false;
            return;
        }

        const element = document.getElementById('order-form');
        if (element) {
            // Un pequeño delay (100ms) es clave porque Framer Motion tarda en renderizar el nuevo paso
            setTimeout(() => {
                element.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }, 100);
        }
    }, [step]);

    const [formData, setFormData] = React.useState({
        name: '',
        email: '',
        genre: 'Pop',
        vocalist: 'Sin preferencia',
        mood: 'Feliz',
        lyrics: '',
        notes: '',
        phone: '',
        plan: PLAN_IDS.PRO as string, // Default to Pro
        price: 97
    });

    const [isGenerating, setIsGenerating] = useState(false);
    const [aiIdea, setAiIdea] = useState('');
    const [showAiInput, setShowAiInput] = useState(false);
    const [genCount, setGenCount] = useState(0);
    const [lyricsExpanded, setLyricsExpanded] = useState(false);
    const [planActiveIndex, setPlanActiveIndex] = useState(1); // Default to middle card (Pro)
    const [notification, setNotification] = useState<string | null>(null);
    const planScrollRef = useRef<HTMLDivElement>(null);

    // Sync external plan selection internally
    useEffect(() => {
        if (initialPlan && initialPlan !== formData.plan) {
            const planData = PLANS.find(p => p.id === initialPlan);
            if (planData) {
                setFormData(prev => ({
                    ...prev,
                    plan: initialPlan,
                    price: planData.price
                }));
            }
        }
    }, [initialPlan]);

    // Cargar contador de IA al montar
    useEffect(() => {
        const saved = localStorage.getItem('struky_ai_gen_count');
        if (saved) setGenCount(parseInt(saved));
    }, []);

    const nextStep = () => {
        // Si ya hay un plan seleccionado (desde la tabla externa) y estamos en el paso 2, 
        // saltamos el paso 3 (que es volver a elegir plan) e ir directo al 4 (confirmar).
        if (step === 2 && formData.plan && initialPlan) {
            setStep(4);
        } else {
            setStep(s => Math.min(s + 1, 4));
        }
    };
    const prevStep = () => {
        setStep(s => Math.max(s - 1, 1));
    };

    // Efecto de Confetti Premium (Colores Struky)
    const triggerSuccessConfetti = () => {
        const colors = ['#CAA052', '#8B6A35', '#ffffff'];
        const fire = (particleRatio: number, opts: any) => {
            confetti({
                ...opts,
                particleCount: Math.floor(200 * particleRatio),
                colors: colors
            });
        };

        fire(0.25, { spread: 26, startVelocity: 55, origin: { x: 0.5, y: 0.7 } });
        fire(0.2, { spread: 60, origin: { x: 0.5, y: 0.7 } });
        fire(0.35, { spread: 100, decay: 0.91, scalar: 0.8, origin: { x: 0.5, y: 0.7 } });
        fire(0.1, { spread: 120, startVelocity: 25, decay: 0.92, scalar: 1.2, origin: { x: 0.5, y: 0.7 } });
        fire(0.1, { spread: 120, startVelocity: 45, origin: { x: 0.5, y: 0.7 } });
    };

    // Auto-scroll al entrar en Paso 3 o cambiar plan
    // Usa polling porque AnimatePresence puede tardar en montar el contenedor
    useEffect(() => {
        if (step === 3 && formData.plan) {
            const idx = PLANS.findIndex(p => p.id === formData.plan);
            if (idx >= 0) {
                setPlanActiveIndex(idx);
                let attempts = 0;
                const maxAttempts = 15;
                const tryScroll = () => {
                    attempts++;
                    const container = planScrollRef.current;
                    if (container && container.children.length >= 3) {
                        const card = container.children[idx] as HTMLElement;
                        if (card && card.offsetWidth > 0) {
                            requestAnimationFrame(() => {
                                const scrollAmount = card.offsetLeft - (container.clientWidth / 2) + (card.clientWidth / 2);
                                container.scrollTo({ left: scrollAmount, behavior: 'auto' });
                            });
                            return; // Éxito, dejar de intentar
                        }
                    }
                    if (attempts < maxAttempts) {
                        setTimeout(tryScroll, 100);
                    }
                };
                // Primer intento tras un breve delay para que AnimatePresence inicie el mount
                const timer = setTimeout(tryScroll, 50);
                return () => clearTimeout(timer);
            }
        }
    }, [step, formData.plan]);

    const selectPlan = (plan: string, price: number) => {
        setFormData(prev => ({ ...prev, plan, price }));
        triggerSuccessConfetti();
        setStep(2);
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        if (step < 4) return nextStep();

        setIsLoading(true);
        
        // --- META CAPI & Pixel: InitiateCheckout (Now fired only when definitively proceeding to checkout) ---
        const eventID = `ic_${Date.now()}_${formData.email.split('@')[0]}`;
        
        if (typeof window !== 'undefined' && (window as any).fbq) {
            // Inicializar con datos de usuario para Coincidencia Avanzada (Advanced Matching)
            const pixelId = process.env.NEXT_PUBLIC_META_PIXEL_ID || "1445433937281922";
            (window as any).fbq('init', pixelId, {
                em: formData.email.toLowerCase().trim(),
                ph: `${selectedCountry.code}${formData.phone}`.replace(/\D/g, '')
            });
            
            (window as any).fbq('track', 'InitiateCheckout', {
                value: formData.price,
                currency: 'USD',
                content_name: formData.plan
            }, { 
                eventID: eventID 
            });
        }
        
        try {
            const response = await fetch('/api/checkout', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    ...formData,
                    plan: t.pricing.plans[formData.plan as keyof typeof t.pricing.plans]?.name || formData.plan,
                    phone: `${selectedCountry.code} ${formData.phone}`,
                    metaEventId: eventID
                }),
            });
            const data = await response.json();
            // DEBUG: Ver respuesta de CAPI antes de redirigir
            if (data._capiDebug) {
                console.log('🔍 CAPI DEBUG:', JSON.stringify(data._capiDebug, null, 2));
                alert('CAPI Debug: ' + JSON.stringify(data._capiDebug));
            }
            if (data.url) window.location.href = data.url;
        } catch (error) {
            console.error('Error:', error);
            alert(lang === 'es' ? 'Error de conexión' : 'Connection error');
        } finally {
            setIsLoading(false);
        }
    };

    const handleGenerateLyrics = async () => {
        if (!aiIdea) return;
        setIsGenerating(true);
        try {
            const response = await fetch('/api/generate-lyrics', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    idea: aiIdea,
                    genre: formData.genre,
                    mood: formData.mood,
                    lang
                }),
            });
            const data = await response.json();
            if (data.lyrics) {
                const newCount = genCount + 1;
                setGenCount(newCount);
                localStorage.setItem('struky_ai_gen_count', newCount.toString());

                setFormData({ ...formData, lyrics: data.lyrics });
                setShowAiInput(false);

                // Efecto de celebración
                triggerSuccessConfetti();
                setNotification(lang === 'es' ? '¡Tu letra ha sido compuesta con éxito! ✨' : 'Your lyrics have been composed successfully! ✨');
                setTimeout(() => setNotification(null), 4000);
            }
        } catch (error) {
            console.error("Error generating lyrics:", error);
        } finally {
            setIsGenerating(false);
        }
    };

    const handlePlanScroll = () => {
        if (planScrollRef.current) {
            const scrollPosition = planScrollRef.current.scrollLeft;
            const containerWidth = planScrollRef.current.offsetWidth;
            const cardWidth = Math.min(containerWidth * 0.85 + 16, 400);
            const index = Math.round(scrollPosition / cardWidth);
            if (index !== planActiveIndex) {
                setPlanActiveIndex(index);
            }
        }
    };

    return (
        <section id="order-form" className="section-padding bg-dark-card/30 scroll-mt-24 md:scroll-mt-32">
            <div className="max-w-3xl mx-auto">
                <div className="text-center mb-12">
                    <h2 className="text-3xl md:text-5xl font-bold mb-4">
                        {lang === 'es' ? 'Crea tu' : 'Create your'} <span className="text-gradient">{lang === 'es' ? 'canción ahora' : 'song now'}</span>
                    </h2>
                    <div className="flex justify-center items-center gap-2 mt-8 max-w-lg mx-auto">
                        {[1, 2, 3, 4].map((s, index) => (
                            <div key={s} className="flex items-center flex-1">
                                <div className="flex flex-col items-center flex-1">
                                    <div
                                        className={`h-2 relative w-full rounded-full transition-all duration-300 mb-2 ${s <= step ? 'bg-gradient-to-r from-coffee-medium to-coffee-light shadow-[0_0_10px_rgba(202,160,82,0.5)]' : 'bg-white/10'
                                            }`}
                                    />
                                    <span className={`text-[9px] font-bold uppercase tracking-wider transition-colors duration-200 ${s <= step ? 'text-coffee-light' : 'text-gray-600'}`}>
                                        {lang === 'es'
                                            ? (s === 1 ? 'Estilo' : s === 2 ? 'Letra' : s === 3 ? 'Plan' : 'Confirmar')
                                            : (s === 1 ? 'Style' : s === 2 ? 'Lyrics' : s === 3 ? 'Plan' : 'Confirm')}
                                    </span>
                                </div>
                            </div>
                        ))}
                    </div>
                </div>

                <form onSubmit={handleSubmit} className="glass-morphism rounded-3xl p-5 sm:p-8 md:p-12 relative overflow-hidden">
                    {/* Floating Notification */}
                    <AnimatePresence>
                        {notification && (
                            <motion.div
                                initial={{ opacity: 0, y: -50, x: '-50%' }}
                                animate={{ opacity: 1, y: 20, x: '-50%' }}
                                exit={{ opacity: 0, y: -50, x: '-50%' }}
                                className="fixed top-4 left-1/2 z-[100] bg-[#CAA052] text-white px-6 py-3 rounded-full font-bold shadow-[0_0_40px_rgba(202,160,82,0.5)] flex items-center gap-3 whitespace-nowrap border border-white/20"
                            >
                                <Sparkles className="w-5 h-5 text-white" />
                                {notification}
                            </motion.div>
                        )}
                    </AnimatePresence>

                    <AnimatePresence mode="wait">
                        {step === 1 && (
                            <motion.div
                                key="step1"
                                initial={{ opacity: 0, x: 20 }}
                                animate={{ opacity: 1, x: 0 }}
                                transition={{ duration: 0.25 }}
                                exit={{ opacity: 0, x: -20 }}
                                className="space-y-6"
                            >
                                <div className="grid md:grid-cols-2 gap-6">
                                    <div>
                                        <label className="block text-sm font-bold text-gray-400 mb-2 uppercase tracking-widest">{lang === 'es' ? 'Género' : 'Genre'}</label>
                                        <select
                                            className="w-full bg-[#1a1a1a] border border-white/10 rounded-xl px-4 py-3 focus:border-coffee-light transition-all outline-none appearance-none text-white"
                                            style={{ colorScheme: 'dark' }}
                                            value={formData.genre}
                                            onChange={e => setFormData({ ...formData, genre: e.target.value })}
                                        >
                                            <option value="Pop" className="bg-[#1a1a1a]">Pop</option>
                                            <option value="Reggaetón" className="bg-[#1a1a1a]">Reggaetón</option>
                                            <option value="Trap" className="bg-[#1a1a1a]">Trap / Urbano</option>
                                            <option value="Salsa" className="bg-[#1a1a1a]">Salsa</option>
                                            <option value="Bachata" className="bg-[#1a1a1a]">Bachata</option>
                                            <option value="Vallenato" className="bg-[#1a1a1a]">Vallenato</option>
                                            <option value="Regional Mexicano" className="bg-[#1a1a1a]">Regional Mexicano / Banda</option>
                                            <option value="Ranchera" className="bg-[#1a1a1a]">Ranchera / Mariachi</option>
                                            <option value="Merengue" className="bg-[#1a1a1a]">Merengue</option>
                                            <option value="Otro" className="bg-[#1a1a1a]">{lang === 'es' ? 'Otro (Escribir...)' : 'Other (Write...)'}</option>
                                        </select>
                                    </div>
                                    <div>
                                        <label className="block text-sm font-bold text-gray-400 mb-2 uppercase tracking-widest">{lang === 'es' ? 'Voz' : 'Vocalist'}</label>
                                        <select
                                            className="w-full bg-[#1a1a1a] border border-white/10 rounded-xl px-4 py-3 focus:border-coffee-light transition-all outline-none appearance-none text-white"
                                            style={{ colorScheme: 'dark' }}
                                            value={formData.vocalist}
                                            onChange={e => setFormData({ ...formData, vocalist: e.target.value })}
                                        >
                                            <option value="Masculina" className="bg-[#1a1a1a]">Masculina</option>
                                            <option value="Femenina" className="bg-[#1a1a1a]">Femenina</option>
                                            <option value="Mixta" className="bg-[#1a1a1a]">Mixta (Dúo)</option>
                                            <option value="Sin preferencia" className="bg-[#1a1a1a]">Sin preferencia</option>
                                        </select>
                                    </div>
                                </div>

                                {formData.genre === 'Otro' && (
                                    <motion.div
                                        initial={{ opacity: 0, y: -10 }}
                                        animate={{ opacity: 1, y: 0 }}
                                        transition={{ duration: 0.2 }}
                                        className="bg-white/5 p-4 rounded-xl border border-coffee-medium/30"
                                    >
                                        <label className="block text-[10px] font-black text-coffee-light mb-2 uppercase tracking-widest">
                                            {lang === 'es' ? 'Especifica tu género personalizado' : 'Specify your custom genre'}
                                        </label>
                                        <input
                                            type="text"
                                            placeholder={lang === 'es' ? 'Ej: Bolero, Rock, Jazz...' : 'Ex: Bolero, Rock, Jazz...'}
                                            className="w-full bg-transparent border-b border-white/20 py-2 outline-none focus:border-coffee-light transition-all text-sm"
                                            onChange={e => setFormData({ ...formData, notes: `Género deseado: ${e.target.value}. ${formData.notes}` })}
                                            required
                                        />
                                    </motion.div>
                                )}
                                <div>
                                    <label className="block text-sm font-bold text-gray-400 mb-2 uppercase tracking-widest">{lang === 'es' ? 'Tu Nombre / Artista' : 'Artist Name'}</label>
                                    <input
                                        type="text"
                                        placeholder="Ej: David Ruiz"
                                        className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 focus:border-coffee-light transition-all outline-none"
                                        value={formData.name}
                                        onChange={e => setFormData({ ...formData, name: e.target.value })}
                                        required
                                    />
                                </div>
                            </motion.div>
                        )}

                        {step === 2 && (
                            <motion.div
                                key="step2"
                                initial={{ opacity: 0, x: 20 }}
                                animate={{ opacity: 1, x: 0 }}
                                transition={{ duration: 0.25 }}
                                exit={{ opacity: 0, x: -20 }}
                                className="space-y-6"
                            >
                                <div>
                                    <div className="flex items-center justify-between mb-4">
                                        <label className="block text-sm font-bold text-gray-400 uppercase tracking-widest">{lang === 'es' ? 'Tu Letra' : 'Your Lyrics'}</label>
                                        <button
                                            type="button"
                                            onClick={() => setShowAiInput(!showAiInput)}
                                            data-fb-ignore="true"
                                            fb-pii="ignore"
                                            className="text-xs font-black uppercase tracking-widest px-3 py-1.5 rounded-lg bg-gradient-to-r from-[#9c88ff] to-[#8c7ae6] text-white flex items-center gap-2 hover:scale-105 transition-all shadow-lg shadow-purple-500/20"
                                        >
                                            <Sparkles className="w-3 h-3" />
                                            {t.form.labels.aiButton}
                                        </button>
                                    </div>

                                    {showAiInput && (
                                        <motion.div
                                            initial={{ opacity: 0, height: 0 }}
                                            animate={{ opacity: 1, height: 'auto' }}
                                            transition={{ duration: 0.2 }}
                                            className={`mb-6 p-4 rounded-2xl border ${genCount >= 3 ? 'bg-coffee-medium/10 border-coffee-medium/30' : 'bg-purple-500/5 border-purple-500/20'}`}
                                        >
                                            {genCount >= 3 ? (
                                                <div className="text-center py-2">
                                                    <p className="text-xs font-bold text-coffee-light uppercase tracking-wider mb-2">
                                                        {lang === 'es' ? 'Límite de demos alcanzado' : 'Demo limit reached'}
                                                    </p>
                                                    <p className="text-[10px] text-gray-400 leading-relaxed">
                                                        {lang === 'es'
                                                            ? '¡Has creado rimas increíbles! Pide tu canción ahora para que nuestros productores le den vida a esta letra.'
                                                            : 'You created amazing rhymes! Order your song now so our producers can bring these lyrics to life.'}
                                                    </p>
                                                </div>
                                            ) : (
                                                <>
                                                    <p className="text-[10px] font-black text-purple-400 uppercase tracking-widest mb-3">
                                                        {lang === 'es' ? `Describe tu idea (Intento ${genCount + 1}/3)` : `Describe your idea (Attempt ${genCount + 1}/3)`}
                                                    </p>
                                                    <div className="flex gap-2">
                                                        <input
                                                            type="text"
                                                            placeholder={t.form.labels.aiIdeaPlaceholder}
                                                            className="flex-1 bg-white/5 border border-white/10 rounded-xl px-4 py-2 text-sm outline-none focus:border-purple-500/50 transition-all text-white"
                                                            value={aiIdea}
                                                            onChange={e => setAiIdea(e.target.value)}
                                                            onKeyDown={e => e.key === 'Enter' && (e.preventDefault(), handleGenerateLyrics())}
                                                        />
                                                        <button
                                                            type="button"
                                                            disabled={isGenerating || !aiIdea}
                                                            onClick={handleGenerateLyrics}
                                                            data-fb-ignore="true"
                                                            fb-pii="ignore"
                                                            className="bg-purple-600 hover:bg-purple-500 disabled:opacity-50 text-white px-4 rounded-xl transition-all flex items-center justify-center min-w-[44px] shadow-[0_0_15px_rgba(124,58,237,0.3)] hover:shadow-[0_0_25px_rgba(124,58,237,0.5)]"
                                                        >
                                                            {isGenerating ? <Loader2 className="w-4 h-4 animate-spin" /> : <Wand2 className="w-4 h-4" />}
                                                        </button>
                                                    </div>
                                                </>
                                            )}
                                        </motion.div>
                                    )}

                                    <div className="relative group/textarea">
                                        <textarea
                                            rows={4}
                                            style={{ minHeight: lyricsExpanded ? '400px' : '120px' }}
                                            className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 focus:border-coffee-light transition-[border-color] outline-none resize-none sm:resize-y text-white placeholder:text-gray-600 text-base sm:text-sm max-h-[60vh] pb-10 overflow-y-auto"
                                            value={formData.lyrics}
                                            onChange={e => setFormData({ ...formData, lyrics: e.target.value })}
                                            onInput={e => {
                                                // Auto-expand solo en móvil (< 640px)
                                                if (window.innerWidth < 640) {
                                                    const el = e.currentTarget;
                                                    el.style.height = 'auto';
                                                    el.style.height = Math.min(el.scrollHeight, window.innerHeight * 0.6) + 'px';
                                                }
                                            }}
                                            required
                                            placeholder={lang === 'es' ? 'Pega aquí tus versos o genéralos con IA arriba...' : 'Paste your lyrics here or generate them with AI above...'}
                                        />
                                        {/* Botón funcional de expandir/contraer - solo desktop */}
                                        <button
                                            type="button"
                                            onClick={() => setLyricsExpanded(!lyricsExpanded)}
                                            className="absolute bottom-5 right-5 items-center gap-2 text-gray-500 hover:text-coffee-light transition-colors hidden sm:flex cursor-pointer z-10 group/expand"
                                        >
                                            <span className="text-[9px] font-bold uppercase tracking-wider group-hover/expand:text-coffee-medium">
                                                {lyricsExpanded
                                                    ? (lang === 'es' ? 'Contraer' : 'Collapse')
                                                    : (lang === 'es' ? 'Expandir' : 'Expand')}
                                            </span>
                                            <div className="w-6 h-6 rounded-md bg-white/5 border border-white/10 flex items-center justify-center group-hover/expand:bg-coffee-medium/20 group-hover/expand:border-coffee-medium/30 transition-all">
                                                <svg className={`w-3.5 h-3.5 transition-transform ${lyricsExpanded ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M19 9l-7 7-7-7" />
                                                </svg>
                                            </div>
                                        </button>
                                    </div>
                                    <div className="mt-4 p-4 bg-coffee-medium/10 border border-coffee-medium/20 rounded-xl flex items-center gap-4 shadow-xl">
                                        <div className="w-8 h-8 rounded-full bg-coffee-medium/20 flex items-center justify-center shrink-0">
                                            <Zap className="w-4 h-4 text-coffee-medium" />
                                        </div>
                                        <div>
                                            <p className="text-[10px] font-black text-coffee-medium uppercase tracking-[0.2em] mb-1">
                                                {lang === 'es' ? '¿Tienes una melodía propia?' : 'Do you have your own melody?'}
                                            </p>
                                            <p className="text-[10px] text-gray-300 leading-normal uppercase tracking-widest font-medium">
                                                {lang === 'es'
                                                    ? 'Para conservar tu melodía, envíanos tu audio por WhatsApp tras el pago junto con el comprobante.'
                                                    : 'To keep your melody, send your audio via WhatsApp after payment along with the receipt.'}
                                            </p>
                                        </div>
                                    </div>
                                </div>
                                <div className="grid md:grid-cols-2 gap-6">
                                    <div>
                                        <label className="block text-sm font-bold text-gray-400 mb-2 uppercase tracking-widest">{lang === 'es' ? 'Estado de Ánimo' : 'Mood'}</label>
                                        <select
                                            className="w-full bg-[#1a1a1a] border border-white/10 rounded-xl px-4 py-3 focus:border-coffee-light transition-all outline-none appearance-none text-white"
                                            style={{ colorScheme: 'dark' }}
                                            value={formData.mood}
                                            onChange={e => setFormData({ ...formData, mood: e.target.value })}
                                        >
                                            <option value="Feliz" className="bg-[#1a1a1a]">Feliz / Alegre</option>
                                            <option value="Romántico" className="bg-[#1a1a1a]">Romántico / Enamorado</option>
                                            <option value="Bailable" className="bg-[#1a1a1a]">Explosivo / Bailable</option>
                                            <option value="Triste" className="bg-[#1a1a1a]">Triste / Melancólico</option>
                                            <option value="Épico" className="bg-[#1a1a1a]">Épico / Motivacional</option>
                                            <option value="Urbano" className="bg-[#1a1a1a]">Chulo / Urbano</option>
                                            <option value="Relajado" className="bg-[#1a1a1a]">Relajado / Chill</option>
                                        </select>
                                    </div>
                                    <div>
                                        <label className="block text-sm font-bold text-gray-400 mb-2 uppercase tracking-widest">WhatsApp / Celular</label>
                                        <div className="relative flex gap-2">
                                            {/* Country Select */}
                                            <div className="relative">
                                                <button
                                                    type="button"
                                                    onClick={() => setShowCountrySelect(!showCountrySelect)}
                                                    className="h-full bg-white/5 border border-white/10 rounded-xl px-3 py-3 flex items-center gap-2 hover:bg-white/10 transition-all min-w-[90px]"
                                                >
                                                    <span className="text-xl">{selectedCountry.flag}</span>
                                                    <span className="text-xs font-bold">{selectedCountry.code}</span>
                                                    <ChevronDown className={`w-3 h-3 transition-transform ${showCountrySelect ? 'rotate-180' : ''}`} />
                                                </button>

                                                {showCountrySelect && (
                                                    <div className="absolute bottom-full left-0 mb-2 w-56 max-h-60 overflow-y-auto bg-[#1a1a1a] border border-white/10 rounded-xl shadow-2xl z-50 p-1 custom-scrollbar">
                                                        {COUNTRIES.map((country) => (
                                                            <button
                                                                key={country.name}
                                                                type="button"
                                                                className="w-full flex items-center gap-3 px-3 py-2.5 hover:bg-white/5 rounded-lg transition-all text-left"
                                                                onClick={() => {
                                                                    setSelectedCountry(country);
                                                                    setShowCountrySelect(false);
                                                                }}
                                                            >
                                                                <span className="text-xl">{country.flag}</span>
                                                                <div className="flex flex-col">
                                                                    <span className="text-xs font-bold text-white">{country.name}</span>
                                                                    <span className="text-[10px] text-gray-500">{country.code}</span>
                                                                </div>
                                                            </button>
                                                        ))}
                                                    </div>
                                                )}
                                            </div>

                                            <input
                                                type="tel"
                                                placeholder="..."
                                                className="flex-1 min-w-0 bg-white/5 border border-white/10 rounded-xl px-4 py-3 focus:border-coffee-light transition-all outline-none"
                                                value={formData.phone}
                                                onChange={e => setFormData({ ...formData, phone: e.target.value })}
                                                required
                                            />
                                        </div>
                                    </div>
                                    <div className="md:col-span-2">
                                        <label className="block text-sm font-bold text-gray-400 mb-2 uppercase tracking-widest">Email</label>
                                        <input
                                            type="email"
                                            placeholder="tu@email.com"
                                            className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 focus:border-coffee-light transition-all outline-none"
                                            value={formData.email}
                                            onChange={e => setFormData({ ...formData, email: e.target.value })}
                                            required
                                        />
                                    </div>
                                </div>
                            </motion.div>
                        )}

                        {step === 3 && (
                            <motion.div
                                key="step3"
                                initial={{ opacity: 0, scale: 0.95 }}
                                animate={{ opacity: 1, scale: 1 }}
                                transition={{ duration: 0.25 }}
                                className="space-y-8"
                            >
                                <div className="text-center mb-4">
                                    <h4 className="text-xl font-bold text-coffee-light">{lang === 'es' ? 'Selecciona el nivel de acabado' : 'Select production level'}</h4>
                                    <p className="text-gray-500 text-sm">{lang === 'es' ? '¿Qué tan lejos quieres llevar tu canción?' : 'How far do you want to take your song?'}</p>
                                </div>
                                <div
                                    ref={planScrollRef}
                                    onScroll={handlePlanScroll}
                                    className="relative flex lg:grid lg:grid-cols-3 gap-4 lg:gap-6 overflow-x-auto lg:overflow-visible pt-6 lg:pt-0 pb-8 lg:pb-0 px-1 snap-x snap-mandatory custom-scrollbar-hide"
                                >
                                    {PLANS.map((plan) => (
                                        <button
                                            key={plan.id}
                                            type="button"
                                            onClick={() => {
                                                setFormData(prev => ({ ...prev, plan: plan.id, price: plan.price }));
                                                triggerSuccessConfetti();
                                            }}
                                            className={`relative p-8 rounded-3xl border transition-all text-left flex flex-col items-center text-center group/card flex-shrink-0 w-[85%] lg:w-full snap-center ${formData.plan === plan.id
                                                ? 'border-coffee-medium bg-coffee-medium/10 shadow-[0_0_30px_rgba(202,160,82,0.15)] scale-[1.02] lg:scale-105 z-10'
                                                : 'border-white/10 bg-white/5 hover:border-white/20'
                                                }`}
                                        >
                                            {plan.highlight && (
                                                <div className="absolute -top-4 left-1/2 -translate-x-1/2 bg-coffee-medium text-black text-[10px] font-black uppercase px-4 py-1.5 rounded-full whitespace-nowrap z-10 shadow-lg">
                                                    {t.pricing.popular}
                                                </div>
                                            )}
                                            <div className="relative">
                                                <plan.icon className={`w-12 h-12 mb-5 transition-transform group-hover/card:scale-110 ${formData.plan === plan.id ? 'text-coffee-light' : 'text-coffee-medium'}`} />
                                                {formData.plan === plan.id && (
                                                    <motion.div 
                                                        initial={{ scale: 0 }}
                                                        animate={{ scale: 1 }}
                                                        className="absolute -top-2 -right-2 bg-coffee-medium rounded-full p-1 shadow-lg"
                                                    >
                                                        <Check className="w-3 h-3 text-black" />
                                                    </motion.div>
                                                )}
                                            </div>
                                            <h4 className="font-black text-base mb-1 uppercase tracking-tight">{t.pricing.plans[plan.id].name}</h4>
                                            <div className="text-4xl font-black mb-3 text-white">${plan.price}<span className="text-xs text-gray-500 ml-1">USD</span></div>
                                            <p className="text-[11px] text-coffee-light font-bold mb-6 uppercase tracking-widest">{t.pricing.plans[plan.id].desc}</p>

                                            <ul className="space-y-3 w-full pt-6 border-t border-white/5 text-left">
                                                {t.pricing.plans[plan.id].features.map((f: string) => (
                                                    <li key={f} className="text-[11px] text-gray-400 flex items-start gap-3">
                                                        <Check className="w-3.5 h-3.5 text-coffee-medium shrink-0 mt-0.5" />
                                                        <span className="leading-tight">{f}</span>
                                                    </li>
                                                ))}
                                            </ul>
                                        </button>
                                    ))}
                                </div>
                                <div className="flex justify-center gap-2 mt-4 lg:hidden">
                                    <div className={`h-1.5 rounded-full transition-all duration-300 ${planActiveIndex === 0 ? 'w-6 bg-coffee-light' : 'w-1.5 bg-white/10'}`}></div>
                                    <div className={`h-1.5 rounded-full transition-all duration-300 ${planActiveIndex === 1 ? 'w-6 bg-coffee-light' : 'w-1.5 bg-white/10'}`}></div>
                                    <div className={`h-1.5 rounded-full transition-all duration-300 ${planActiveIndex === 2 ? 'w-6 bg-coffee-light' : 'w-1.5 bg-white/10'}`}></div>
                                </div>
                            </motion.div>
                        )}

                        {step === 4 && (
                            <motion.div
                                key="step4"
                                initial={{ opacity: 0, x: 20 }}
                                animate={{ opacity: 1, x: 0 }}
                                transition={{ duration: 0.25 }}
                                exit={{ opacity: 0, x: -20 }}
                                className="space-y-8"
                            >
                                {/* ORDER SUMMARY TICKET */}
                                <div className="bg-black/40 border border-white/10 rounded-3xl p-8 relative overflow-hidden shadow-2xl">
                                    <div className="absolute top-0 left-0 w-2 h-full bg-coffee-medium"></div>
                                    <div className="flex justify-between items-start mb-8">
                                        <div>
                                            <h3 className="text-xl font-black text-white uppercase tracking-tight mb-1">
                                                {lang === 'es' ? 'Resumen del Pedido' : 'Order Summary'}
                                            </h3>
                                            <div className="flex items-center gap-3">
                                                <p className="text-[10px] text-coffee-light font-bold uppercase tracking-[0.3em]">
                                                    {t.pricing.plans[formData.plan as keyof typeof t.pricing.plans]?.name || formData.plan} Edition
                                                </p>
                                                <button 
                                                    type="button"
                                                    onClick={() => setStep(3)}
                                                    className="text-[9px] text-gray-500 hover:text-coffee-light border border-white/10 hover:border-coffee-medium/30 px-2 py-0.5 rounded transition-all uppercase font-black"
                                                >
                                                    {lang === 'es' ? 'Cambiar' : 'Change'}
                                                </button>
                                            </div>
                                        </div>
                                        <div className="text-right">
                                            <span className="text-3xl font-black text-white">${formData.price}</span>
                                            <span className="text-[10px] text-gray-500 block">USD</span>
                                        </div>
                                    </div>

                                    <div className="grid md:grid-cols-2 gap-8 mb-8">
                                        {/* Columna 1: Datos Personales */}
                                        <div className="space-y-4">
                                            <h4 className="text-[11px] font-black text-gray-400 uppercase tracking-widest border-b border-white/10 pb-2">Información de Contacto</h4>
                                            <div className="grid gap-3">
                                                <div>
                                                    <p className="text-[10px] text-gray-400 uppercase tracking-wider mb-1">Artista / Cliente</p>
                                                    <p className="text-xs text-white font-bold">{formData.name || '-'}</p>
                                                </div>
                                                <div>
                                                    <p className="text-[10px] text-gray-400 uppercase tracking-wider mb-1">WhatsApp de Entrega</p>
                                                    <p className="text-xs text-white font-bold">{selectedCountry.code} {formData.phone || '-'}</p>
                                                </div>
                                                <div>
                                                    <p className="text-[10px] text-gray-400 uppercase tracking-wider mb-1">Correo Electrónico</p>
                                                    <p className="text-xs text-white font-bold">{formData.email || '-'}</p>
                                                </div>
                                            </div>
                                        </div>

                                        {/* Columna 2: Especificaciones */}
                                        <div className="space-y-4">
                                            <h4 className="text-[11px] font-black text-gray-400 uppercase tracking-widest border-b border-white/10 pb-2">Especificaciones Creativas</h4>
                                            <div className="grid grid-cols-2 gap-3">
                                                <div>
                                                    <p className="text-[10px] text-gray-400 uppercase tracking-wider mb-1">Género</p>
                                                    <p className="text-xs text-white font-bold">{formData.genre}</p>
                                                </div>
                                                <div>
                                                    <p className="text-[10px] text-gray-400 uppercase tracking-wider mb-1">Preferencia de Voz</p>
                                                    <p className="text-xs text-white font-bold">{formData.vocalist}</p>
                                                </div>
                                                <div>
                                                    <p className="text-[10px] text-gray-400 uppercase tracking-wider mb-1">Estado de Ánimo</p>
                                                    <p className="text-xs text-white font-bold">{formData.mood}</p>
                                                </div>
                                                <div>
                                                    <p className="text-[10px] text-gray-400 uppercase tracking-wider mb-1">Entrega Estimada</p>
                                                    <p className="text-xs text-coffee-light font-bold">
                                                        {formData.plan === 'Elite Studio' ? '24 HORAS' : formData.plan === 'Pro Master' ? '24-48 HORAS' : '48-72 HORAS'}
                                                    </p>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    {/* Letra */}
                                    <div className="bg-white/5 rounded-2xl p-5 border border-white/5 mb-8 relative">
                                        <div className="absolute -top-px left-8 right-8 h-px bg-gradient-to-r from-transparent via-white/10 to-transparent"></div>
                                        <div className="text-[10px] text-gray-400 uppercase tracking-widest mb-3 flex items-center gap-2">
                                            <div className="w-1 h-1 rounded-full bg-coffee-medium"></div>
                                            Versos Confirmados
                                        </div>
                                        <p className="text-xs text-gray-300 italic line-clamp-3 leading-relaxed">
                                            "{formData.lyrics || 'Sin letra proporcionada'}"
                                        </p>
                                    </div>

                                    {/* Lo que incluye el plan */}
                                    <div className="flex flex-wrap gap-4 justify-center">
                                        {[
                                            'Producción por Humanos + IA',
                                            'Derechos de Autoría 100%',
                                            formData.plan !== 'Starter' ? 'Video Obsequio Incluido' : 'Audio en Alta Calidad',
                                            formData.plan === 'Elite Studio' ? 'Multitracks / STEMS' : 'Masterización Profesional'
                                        ].map(check => (
                                            <div key={check} className="flex items-center gap-2 text-[10px] text-gray-300 font-bold uppercase">
                                                <Check className="w-3 h-3 text-coffee-medium" />
                                                {check}
                                            </div>
                                        ))}
                                    </div>
                                </div>

                                {/* COMPARISON TABLE */}
                                <div className="comparison-grid">
                                    <div className="comparison-col border-b md:border-b-0 md:border-r border-white/10 bg-white/[0.01]">
                                        <h4 className="text-red-500/80 font-black text-xs uppercase tracking-widest mb-6 flex items-center gap-2">
                                            {lang === 'es' ? 'Estudio Tradicional' : 'Traditional Studio'} <span className="text-lg">×</span>
                                        </h4>
                                        <div className="text-3xl font-bold text-gray-600 line-through mb-4">~$500 USD</div>
                                        <p className="text-xs text-gray-500 leading-relaxed">
                                            {lang === 'es'
                                                ? 'Músicos, tiempo de estudio, ingeniero y vocalistas.'
                                                : 'Musicians, studio time, engineer and vocalists.'}
                                        </p>
                                    </div>

                                    {/* SEGUNDA COLUMNA: EL VALOR DE STRUKY */}
                                    <div className="comparison-col bg-coffee-medium/[0.03]">
                                        <h4 className="text-coffee-medium font-black text-xs uppercase tracking-widest mb-6 flex items-center gap-2">
                                            {lang === 'es' ? 'Solo hoy con Struky' : 'Only today with Struky'} <span className="text-lg">✓</span>
                                        </h4>
                                        <div className="text-4xl font-black text-white mb-4 animate-pulse">${formData.price} USD</div>
                                        <p className="text-xs text-gray-300 leading-relaxed font-bold">
                                            {lang === 'es'
                                                ? 'Entrega garantizada, derechos totales y calidad radio.'
                                                : 'Guaranteed delivery, total rights and radio quality.'}
                                        </p>
                                    </div>
                                </div>

                                {/* DYNAMIC SLOTS BANNER (FOMO) */}
                                <div className="bg-red-500/5 border border-red-500/20 rounded-2xl p-4 flex items-center justify-between gap-4 animate-in fade-in slide-in-from-bottom-2">
                                    <div className="flex items-center gap-3">
                                        <div className="relative">
                                            <div className="w-2.5 h-2.5 bg-red-500 rounded-full animate-ping absolute inset-0"></div>
                                            <div className="w-2.5 h-2.5 bg-red-500 rounded-full relative"></div>
                                        </div>
                                        <div>
                                            <p className="text-[11px] font-black text-white uppercase tracking-tight">
                                                {lang === 'es' ? '¡Actividad reciente detectada!' : 'Recent activity detected!'}
                                            </p>
                                            <p className="text-[9px] text-gray-400 uppercase tracking-widest">
                                                {lang === 'es' ? 'Otros productores revisando ahora' : 'Other producers reviewing now'}
                                            </p>
                                        </div>
                                    </div>
                                    <div className="bg-red-500/20 px-3 py-1 rounded-lg border border-red-500/30">
                                        <span className="text-sm font-black text-red-400 tabular-nums transition-all duration-300 inline-block scale-110">
                                            {slots} {lang === 'es' ? (slots === 1 ? 'CUPO RESTANTE' : 'CUPOS RESTANTES') : (slots === 1 ? 'SLOT LEFT' : 'SLOTS LEFT')}
                                        </span>
                                    </div>
                                </div>

                                {/* TRUST GUARANTEE PIE */}
                                <div className="flex flex-col items-center gap-6 py-6 border-t border-white/5 mt-8">
                                    <div className="flex items-center justify-center gap-3 flex-wrap">
                                        {/* Visa */}
                                        <div className="bg-white/[0.06] border border-white/15 rounded-lg px-3 py-2 flex items-center justify-center min-w-[52px] hover:bg-white/10 transition-all">
                                            <span className="text-white font-black text-[13px] italic tracking-tight">VISA</span>
                                        </div>
                                        {/* Mastercard */}
                                        <div className="bg-white/[0.06] border border-white/15 rounded-lg px-3 py-2 flex items-center gap-1.5 hover:bg-white/10 transition-all">
                                            <div className="w-5 h-5 rounded-full bg-red-500 -mr-2.5"></div>
                                            <div className="w-5 h-5 rounded-full bg-yellow-400 opacity-90"></div>
                                        </div>
                                        {/* Stripe */}
                                        <div className="bg-white/[0.06] border border-white/15 rounded-lg px-3 py-2 flex items-center justify-center min-w-[52px] hover:bg-white/10 transition-all">
                                            <span className="text-[#7c75ff] font-black text-[13px] tracking-tight">stripe</span>
                                        </div>
                                        {/* SSL */}
                                        <div className="flex items-center gap-1.5 border border-white/15 rounded-lg px-3 py-2 bg-white/[0.06]">
                                            <Lock className="w-3 h-3 text-green-400" />
                                            <span className="text-[10px] font-black text-green-400 tracking-widest">SSL</span>
                                        </div>
                                    </div>

                                    <div className="flex items-center justify-center gap-4 px-6 py-4 bg-white/[0.02] border border-white/5 rounded-2xl w-full">
                                        <div className="w-10 h-10 rounded-full bg-coffee-medium/10 flex items-center justify-center border border-coffee-medium/20 shrink-0">
                                            <ShieldCheck className="w-5 h-5 text-coffee-medium" />
                                        </div>
                                        <div className="text-left">
                                            <div className="text-[11px] font-black text-white uppercase tracking-widest mb-0.5">{lang === 'es' ? 'Garantía Estándar Struky' : 'Struky Standard Guarantee'}</div>
                                            <div className="text-[9px] text-gray-500 leading-tight uppercase tracking-wider">{lang === 'es' ? 'Tu inversión está protegida. Calidad garantizada o revisamos hasta que ames tu canción.' : 'Your investment is protected. Guaranteed quality or we revise until you love your song.'}</div>
                                        </div>
                                    </div>
                                </div>
                            </motion.div>
                        )}
                    </AnimatePresence>

                    <div className="flex flex-col-reverse md:flex-row gap-4 mt-10">
                        {step > 1 && (
                            <button
                                type="button"
                                onClick={prevStep}
                                className="btn-secondary w-full md:flex-1"
                            >
                                {lang === 'es' ? 'Atrás' : 'Back'}
                            </button>
                        )}
                        <button
                            type="submit"
                            disabled={isLoading}
                            className={`btn-primary w-full md:flex-1 ${step === 4 ? 'bg-[#A67C37] !py-4 shadow-[0_0_30px_rgba(166,124,55,0.4)] hover:bg-[#B88C45]' : ''}`}
                        >
                            {isLoading ? (
                                <Loader2 className="w-6 h-6 animate-spin mx-auto text-white" />
                            ) : (
                                step === 4 ? (
                                    <div className="flex items-center justify-center gap-2 sm:gap-4 py-0.5">
                                        <Sparkles className="w-5 h-5 text-white animate-pulse shrink-0 hidden xs:block" />
                                        <span className="font-black uppercase tracking-tight text-xs sm:text-base text-white text-center leading-tight">
                                            {lang === 'es' ? `¡RESERVAR MI CANCIÓN PROFESIONAL! ($${formData.price})` : `ORDER MY PROFESSIONAL SONG! ($${formData.price})`}
                                        </span>
                                    </div>
                                ) : (
                                    <span className="font-black uppercase tracking-widest text-white/90">
                                        {lang === 'es' ? 'Continuar' : 'Continue'}
                                    </span>
                                )
                            )}
                        </button>
                    </div>
                </form>
            </div>
        </section>
    );
}
