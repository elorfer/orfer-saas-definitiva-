'use client';

import React, { useState, useEffect, useRef } from 'react';
import Image from 'next/image';
import { motion, AnimatePresence } from 'framer-motion';
import confetti from 'canvas-confetti';
import { translations } from '../lib/translations';
import { PLANS, PLAN_IDS } from '../lib/plans';
import { Check, Video, ChevronDown, ChevronLeft, ChevronRight, Sparkles, Wand2, Loader2, Lock, ShieldCheck, CreditCard, Zap, MessageCircle, Plus, Minus, Music } from 'lucide-react';
import { playSuccess, playCashRegister, playWhoosh, playMagic, playTick } from '../lib/soundEngine';

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
    const [showCountrySelect, setShowCountrySelect] = React.useState(false);
    const [selectedCountry, setSelectedCountry] = React.useState(COUNTRIES[0]);
    const [isLoaded, setIsLoaded] = React.useState(false);

    const [formData, setFormData] = React.useState({
        name: '',
        email: '',
        genre: 'Pop',
        vocalist: 'Me sorprendes tú',
        mood: 'Feliz',
        lyrics: '',
        notes: '',
        phone: '',
        plan: PLAN_IDS.PRO as string, // Default to Pro
        price: 50
    });

    const [isGenerating, setIsGenerating] = useState(false);
    const [aiIdea, setAiIdea] = useState('');
    const [showAiInput, setShowAiInput] = useState(false);
    const [genCount, setGenCount] = useState(0);
    const [lyricsExpanded, setLyricsExpanded] = useState(false);
    const [sendLater, setSendLater] = useState(false);
    const [planActiveIndex, setPlanActiveIndex] = useState(1); // Default to middle card (Pro)
    const [notification, setNotification] = useState<string | null>(null);
    const [songQuantity, setSongQuantity] = useState(1);

    const isInitialRender = useRef(true);
    const planScrollRef = useRef<HTMLDivElement>(null);

    // Cargar datos persistidos de localStorage al montar (seguro para SSR/hidratación)
    useEffect(() => {
        try {
            const savedFormData = localStorage.getItem('struky_order_form_data');
            if (savedFormData) {
                const parsed = JSON.parse(savedFormData);
                setFormData(prev => ({ ...prev, ...parsed }));
            }

            const savedStep = localStorage.getItem('struky_order_form_step');
            if (savedStep) {
                setStep(parseInt(savedStep, 10));
            }

            const savedSendLater = localStorage.getItem('struky_order_form_send_later');
            if (savedSendLater) {
                setSendLater(savedSendLater === 'true');
            }

            const savedSongQuantity = localStorage.getItem('struky_order_form_song_quantity');
            if (savedSongQuantity) {
                setSongQuantity(parseInt(savedSongQuantity, 10));
            }

            const savedCountryCode = localStorage.getItem('struky_order_form_country_code');
            if (savedCountryCode) {
                const matchedCountry = COUNTRIES.find(c => c.code === savedCountryCode);
                if (matchedCountry) {
                    setSelectedCountry(matchedCountry);
                }
            }
        } catch (e) {
            console.error('Error al cargar datos desde localStorage:', e);
        } finally {
            setIsLoaded(true);
        }
    }, []);

    // Persistir cambios en localStorage después de que termine la hidratación
    useEffect(() => {
        if (!isLoaded) return;
        try {
            localStorage.setItem('struky_order_form_data', JSON.stringify(formData));
        } catch (e) {
            console.error('Error al guardar formData en localStorage:', e);
        }
    }, [formData, isLoaded]);

    useEffect(() => {
        if (!isLoaded) return;
        try {
            localStorage.setItem('struky_order_form_step', step.toString());
        } catch (e) {
            console.error('Error al guardar step en localStorage:', e);
        }
    }, [step, isLoaded]);

    useEffect(() => {
        if (!isLoaded) return;
        try {
            localStorage.setItem('struky_order_form_send_later', sendLater.toString());
        } catch (e) {
            console.error('Error al guardar sendLater en localStorage:', e);
        }
    }, [sendLater, isLoaded]);

    useEffect(() => {
        if (!isLoaded) return;
        try {
            localStorage.setItem('struky_order_form_song_quantity', songQuantity.toString());
        } catch (e) {
            console.error('Error al guardar songQuantity en localStorage:', e);
        }
    }, [songQuantity, isLoaded]);

    useEffect(() => {
        if (!isLoaded) return;
        try {
            localStorage.setItem('struky_order_form_country_code', selectedCountry.code);
        } catch (e) {
            console.error('Error al guardar el código de país en localStorage:', e);
        }
    }, [selectedCountry, isLoaded]);

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

    // Discount: Flat 10% if 3 or more songs are selected
    const discountPercent = songQuantity >= 3 ? 10 : 0;
    const unitPriceWithDiscount = formData.price * (1 - discountPercent / 100);
    const totalPrice = Math.ceil(unitPriceWithDiscount * songQuantity);
    const totalSavings = Math.round((formData.price * songQuantity - totalPrice) * 100) / 100;

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
        playWhoosh();
        // Si ya hay un plan seleccionado (desde la tabla externa) y estamos en el paso 1, 
        // saltamos el paso 2 (que es volver a elegir plan) e ir directo al 3 (confirmar).
        if (step === 1 && formData.plan && initialPlan) {
            setStep(3);
        } else {
            setStep(s => Math.min(s + 1, 3));
        }
    };
    const prevStep = () => {
        playWhoosh();
        setStep(s => Math.max(s - 1, 1));
    };



    const scrollToPlanIndex = (index: number) => {
        playTick();
        const container = planScrollRef.current;
        if (container && container.children[index]) {
            const card = container.children[index] as HTMLElement;
            const scrollAmount = card.offsetLeft - (container.clientWidth / 2) + (card.clientWidth / 2);
            container.scrollTo({ left: scrollAmount, behavior: 'smooth' });
            setPlanActiveIndex(index);
        }
    };

    const nextPlan = () => {
        const next = planActiveIndex < PLANS.length - 1 ? planActiveIndex + 1 : 0;
        scrollToPlanIndex(next);
    };

    const prevPlan = () => {
        const prev = planActiveIndex > 0 ? planActiveIndex - 1 : PLANS.length - 1;
        scrollToPlanIndex(prev);
    };

    // Efecto de Confetti Premium (Colores Struky)
    const triggerSuccessConfetti = () => {
        playSuccess();
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
        if (step === 2 && formData.plan) {
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
        setStep(1);
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        if (step < 3) return nextStep();

        playCashRegister();
        setIsLoading(true);
        
        // --- META CAPI & Pixel: InitiateCheckout (Now fired only when definitively proceeding to checkout) ---
        const eventID = `ic_${Date.now()}_${formData.email.split('@')[0]}`;
        
        if (typeof window !== 'undefined' && (window as any).fbq) {
            // Advanced Matching: re-init pixel with user data (official Meta approach)
            // This updates the pixel's user data for better match rates on subsequent events
            const pixelId = process.env.NEXT_PUBLIC_META_PIXEL_ID || "1681899642811715";
            (window as any).fbq('init', pixelId, {
                em: formData.email.toLowerCase().trim(),
                ph: `${selectedCountry.code}${formData.phone}`.replace(/\D/g, ''),
                fn: formData.name.toLowerCase().trim()
            });
            
            (window as any).fbq('track', 'InitiateCheckout', {
                value: totalPrice,
                currency: 'USD',
                content_name: formData.plan
            }, { 
                eventID: eventID 
            });
        }
        
        // Capture Meta cookies from browser
        const getCookie = (name: string) => {
            const value = `; ${document.cookie}`;
            const parts = value.split(`; ${name}=`);
            if (parts.length === 2) return parts.pop()?.split(';').shift();
            return null;
        };

        const fbp = getCookie('_fbp');
        let fbc = getCookie('_fbc');

        // Fallback chain for fbc:
        // cookie → localStorage (already contains proper fbc with original timestamp)
        // NEVER re-construct fbc with Date.now() — Meta flags this as "modified fbclid"
        if (!fbc) {
            try { fbc = localStorage.getItem('_struky_fbc'); } catch(e) { /* private browsing */ }
        }

        try {
            const response = await fetch('/api/checkout', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    ...formData,
                    price: totalPrice,
                    songQuantity,
                    unitPrice: formData.price,
                    discountPercent,
                    plan: t.pricing.plans[formData.plan as keyof typeof t.pricing.plans]?.name || formData.plan,
                    phone: `${selectedCountry.code} ${formData.phone}`,
                    metaEventId: eventID,
                    fbp,
                    fbc
                }),
            });
            const data = await response.json();
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
                playMagic();
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
            const container = planScrollRef.current;
            const scrollLeft = container.scrollLeft;
            const containerWidth = container.offsetWidth;
            // Find the closest card to center
            let closestIndex = 0;
            let closestDist = Infinity;
            for (let i = 0; i < container.children.length; i++) {
                const card = container.children[i] as HTMLElement;
                const cardCenter = card.offsetLeft + card.offsetWidth / 2;
                const viewCenter = scrollLeft + containerWidth / 2;
                const dist = Math.abs(cardCenter - viewCenter);
                if (dist < closestDist) {
                    closestDist = dist;
                    closestIndex = i;
                }
            }
            if (closestIndex !== planActiveIndex) {
                setPlanActiveIndex(closestIndex);
            }
        }
    };

    return (
        <section id="order-form" className="py-16 md:py-24 bg-dark-card/30 scroll-mt-24 md:scroll-mt-32">
            <div className={`mx-auto relative transition-all duration-500 ${step === 2 ? 'max-w-7xl' : 'max-w-3xl'}`}>
                <div className="text-center mb-12 relative z-10 flex flex-col items-center px-6">
                    <h2 className="text-3xl md:text-5xl font-bold mb-4 w-full">
                        {lang === 'es' ? 'Crea tu' : 'Create your'} <span className="text-gradient">{lang === 'es' ? 'canción ahora' : 'song now'}</span>
                    </h2>
                    <div className="flex justify-center items-center gap-2 mt-8 max-w-lg mx-auto">
                        {[1, 2, 3].map((s, index) => (
                            <div key={s} className="flex items-center flex-1">
                                <div className="flex flex-col items-center flex-1">
                                    <div
                                        className={`h-2 relative w-full rounded-full transition-all duration-300 mb-2 ${s <= step ? 'bg-gradient-to-r from-coffee-medium to-coffee-light shadow-[0_0_10px_rgba(202,160,82,0.5)]' : 'bg-white/10'
                                            }`}
                                    />
                                    <span className={`text-[9px] font-bold uppercase tracking-wider transition-colors duration-200 ${s <= step ? 'text-coffee-light' : 'text-gray-600'}`}>
                                        {lang === 'es'
                                            ? (s === 1 ? 'Canción' : s === 2 ? 'Plan' : 'Pago')
                                            : (s === 1 ? 'Song' : s === 2 ? 'Plan' : 'Payment')}
                                    </span>
                                </div>
                            </div>
                        ))}
                    </div>
                </div>

                <form onSubmit={handleSubmit} className="glass-morphism sm:rounded-3xl p-5 sm:p-8 md:p-12 relative overflow-hidden border-x-0 sm:border-x border-y border-white/10">
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
                                        <label className="block text-sm font-bold text-gray-400 mb-2 uppercase tracking-widest">
                                            {formData.plan === 'youtube' 
                                                ? (lang === 'es' ? 'Temática del Canal' : 'Channel Topic') 
                                                : (lang === 'es' ? 'Género' : 'Genre')}
                                        </label>
                                        <select
                                            className="w-full bg-[#1a1a1a] border border-white/10 rounded-xl px-4 py-3 focus:border-coffee-light transition-all outline-none appearance-none text-white"
                                            style={{ colorScheme: 'dark' }}
                                            value={formData.genre}
                                            onChange={e => {
                                                playTick();
                                                setFormData({ ...formData, genre: e.target.value });
                                            }}
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

                                        {formData.genre === 'Otro' && (
                                            <motion.div
                                                initial={{ opacity: 0, y: -10 }}
                                                animate={{ opacity: 1, y: 0 }}
                                                transition={{ duration: 0.2 }}
                                                className="bg-white/5 p-4 rounded-xl border border-coffee-medium/30 mt-4"
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
                                    </div>
                                    {formData.plan !== 'youtube' && (
                                        <div>
                                            <label className="block text-sm font-bold text-gray-400 mb-2 uppercase tracking-widest">{lang === 'es' ? 'Voz' : 'Vocalist'}</label>
                                            <select
                                                className="w-full bg-[#1a1a1a] border border-white/10 rounded-xl px-4 py-3 focus:border-coffee-light transition-all outline-none appearance-none text-white"
                                                style={{ colorScheme: 'dark' }}
                                                value={formData.vocalist}
                                                onChange={e => {
                                                    playTick();
                                                    setFormData({ ...formData, vocalist: e.target.value });
                                                }}
                                            >
                                                <option value="Voz masculina" className="bg-[#1a1a1a]">{lang === 'es' ? 'Voz masculina' : 'Male voice'}</option>
                                                <option value="Voz femenina" className="bg-[#1a1a1a]">{lang === 'es' ? 'Voz femenina' : 'Female voice'}</option>
                                                <option value="Mixta" className="bg-[#1a1a1a]">{lang === 'es' ? 'Mixta (Dúo)' : 'Mixed (Duet)'}</option>
                                                <option value="Me sorprendes tú" className="bg-[#1a1a1a]">{lang === 'es' ? 'Me sorprendes tú' : 'Surprise me'}</option>
                                            </select>
                                        </div>
                                    )}
                                </div>


                                {formData.plan !== 'youtube' && (
                                    <div>
                                        <label className="block text-sm font-bold text-gray-400 mb-2 uppercase tracking-widest">{lang === 'es' ? '¿Cómo quieres aparecer en los créditos?' : 'How do you want to appear in the credits?'}</label>
                                        <input
                                            type="text"
                                            placeholder={lang === 'es' ? 'Ej: Tu nombre o seudónimo' : 'Ex: Your name or pseudonym'}
                                            className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 focus:border-coffee-light transition-all outline-none"
                                            value={formData.name}
                                            onChange={e => {
                                                setFormData({ ...formData, name: e.target.value });
                                            }}
                                            required={formData.plan !== 'youtube'}
                                        />
                                    </div>
                                )}

                                <div className="pt-4 border-t border-white/5">
                                    <div className="flex items-center justify-between mb-4">
                                        <label className="block text-sm font-bold text-gray-400 uppercase tracking-widest">{lang === 'es' ? 'Tu Letra' : 'Your Lyrics'}</label>
                                        <button
                                            type="button"
                                            onClick={() => {
                                                setShowAiInput(!showAiInput);
                                                setSendLater(false); // Asegurar que el textarea se vea si usa la IA
                                            }}
                                            data-fb-ignore="true"
                                            fb-pii="ignore"
                                            className="text-xs font-black uppercase tracking-widest px-3 py-1.5 rounded-lg bg-gradient-to-r from-[#9c88ff] to-[#8c7ae6] text-white flex items-center gap-2 hover:scale-105 transition-all shadow-lg shadow-purple-500/20"
                                        >
                                            <Sparkles className="w-3 h-3" />
                                            {t.form.labels.aiButton}
                                        </button>
                                    </div>

                                    {/* OPCIÓN: ENVIAR DESPUÉS (MÁS PROMINENTE) */}
                                    <div className="grid grid-cols-2 gap-3 sm:gap-4 mb-6">
                                        <button
                                            type="button"
                                            onClick={() => {
                                                playTick();
                                                setSendLater(false);
                                                setFormData({ ...formData, lyrics: '' });
                                            }}
                                            className={`p-3 sm:p-4 rounded-2xl border transition-all flex flex-col items-center text-center gap-2 ${!sendLater ? 'bg-white/10 border-coffee-medium shadow-[0_0_20px_rgba(202,160,82,0.15)]' : 'bg-white/5 border-white/10 hover:bg-white/10'}`}
                                        >
                                            <div className={`w-8 h-8 sm:w-10 sm:h-10 rounded-full flex items-center justify-center ${!sendLater ? 'bg-coffee-medium text-black' : 'bg-white/10 text-gray-400'}`}>
                                                <Zap className="w-4 h-4 sm:w-5 sm:h-5" />
                                            </div>
                                            <span className="text-[10px] sm:text-xs font-black uppercase tracking-widest text-white">
                                                {lang === 'es' ? 'Escribir ahora' : 'Write now'}
                                            </span>
                                        </button>

                                        <button
                                            type="button"
                                            onClick={() => {
                                                playTick();
                                                setSendLater(true);
                                                setFormData({ ...formData, lyrics: lang === 'es' ? 'Enviaré la letra/audio por WhatsApp después del pago.' : 'I will send the lyrics/audio via WhatsApp after payment.' });
                                            }}
                                            className={`p-3 sm:p-4 rounded-2xl border transition-all flex flex-col items-center text-center gap-2 ${sendLater ? 'bg-[#25D366]/20 border-[#25D366] shadow-[0_0_20px_rgba(37,211,102,0.2)]' : 'bg-white/5 border-white/10 hover:bg-white/10'}`}
                                        >
                                            <div className={`w-8 h-8 sm:w-10 sm:h-10 rounded-full flex items-center justify-center ${sendLater ? 'bg-[#25D366] text-white shadow-lg shadow-[#25D366]/50' : 'bg-white/10 text-gray-400'}`}>
                                                <MessageCircle className="w-4 h-4 sm:w-5 sm:h-5" />
                                            </div>
                                            <span className="text-[10px] sm:text-xs font-black uppercase tracking-widest text-white">
                                                {lang === 'es' ? 'Enviar después' : 'Send later'}
                                            </span>
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
                                        {!sendLater && (
                                            <textarea
                                                rows={4}
                                                style={{ minHeight: lyricsExpanded ? '400px' : '120px' }}
                                                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 focus:border-coffee-light transition-[border-color] outline-none resize-none sm:resize-y text-white placeholder:text-gray-600 text-base sm:text-sm max-h-[60vh] pb-10 overflow-y-auto"
                                                value={formData.lyrics}
                                                onChange={e => setFormData({ ...formData, lyrics: e.target.value })}
                                                onInput={e => {
                                                    if (window.innerWidth < 640) {
                                                        const el = e.currentTarget;
                                                        el.style.height = 'auto';
                                                        el.style.height = Math.min(el.scrollHeight, window.innerHeight * 0.6) + 'px';
                                                    }
                                                }}
                                                required={!sendLater}
                                                placeholder={lang === 'es' 
                                                    ? 'Ej: Llegaste a mi vida como lluvia en verano / y ahora sin ti el sol ya no me calienta igual...' 
                                                    : 'Ex: You came into my life like summer rain / and now without you the sun doesn\'t warm me the same...'}
                                            />
                                        )}
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
                                    

                                    

                                </div>

                                <div className="grid md:grid-cols-1 gap-6 pt-4 border-t border-white/5">
                                    <div>
                                        <label className="block text-sm font-bold text-gray-400 mb-2 uppercase tracking-widest">{lang === 'es' ? 'Sentimiento de la canción' : 'Song Feeling'}</label>
                                        <select
                                            className="w-full bg-[#1a1a1a] border border-white/10 rounded-xl px-4 py-3 focus:border-coffee-light transition-all outline-none appearance-none text-white"
                                            style={{ colorScheme: 'dark' }}
                                            value={formData.mood}
                                            onChange={e => {
                                                playTick();
                                                setFormData({ ...formData, mood: e.target.value });
                                            }}
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
                                </div>
                            </motion.div>
                        )}

                        {step === 2 && (
                            <motion.div
                                key="step2"
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
                                    className="relative flex lg:grid lg:grid-cols-4 gap-6 overflow-x-auto lg:overflow-visible pt-10 pb-4 lg:pb-0 -mx-5 sm:-mx-8 px-5 sm:px-8 lg:mx-0 lg:px-0 snap-x snap-mandatory scroll-px-6 custom-scrollbar-hide"
                                >
                                    {PLANS.map((plan) => (
                                        <button
                                            key={plan.id}
                                            type="button"
                                            onClick={() => {
                                                setFormData(prev => ({ ...prev, plan: plan.id, price: plan.price }));
                                                triggerSuccessConfetti();
                                            }}
                                            className={`relative p-6 rounded-[2rem] border transition-all text-left flex flex-col items-center text-center group/card flex-shrink-0 w-[88%] lg:w-full snap-center ${formData.plan === plan.id
                                                ? (plan.id === 'elite' ? 'border-purple-600 bg-purple-600/5' : plan.id === 'premium' ? 'border-emerald-500 bg-emerald-500/5' : 'border-coffee-medium bg-coffee-medium/5')
                                                : 'border-white/5 bg-[#111]'
                                                }`}
                                        >
                                            {plan.highlight && (
                                                <div className={`absolute -top-3.5 left-1/2 -translate-x-1/2 text-white text-[9px] font-black uppercase px-6 py-1.5 rounded-full z-10 border whitespace-nowrap shadow-xl ${plan.id === 'elite' ? 'bg-purple-600 border-white/20' : 'bg-coffee-medium text-white border-white/10'}`}>
                                                    {t.pricing.popular}
                                                </div>
                                            )}
                                            <div className="relative mb-6">
                                                <plan.icon className={`w-12 h-12 transition-all ${formData.plan === plan.id ? (plan.id === 'elite' ? 'text-purple-400' : 'text-coffee-light') : 'text-gray-600'}`} />
                                            </div>
                                            <h4 className="font-black text-lg mb-1 uppercase tracking-tight text-white">{t.pricing.plans[plan.id].name}</h4>
                                            {plan.id === 'pro' && (
                                                <div className="mb-2 flex items-center gap-1 justify-center">
                                                    <Sparkles className="w-2.5 h-2.5 text-coffee-medium animate-pulse" />
                                                    <span className="text-[9px] text-coffee-medium font-black uppercase tracking-wider">
                                                        {lang === 'es' ? 'Elegido por el 78% de artistas' : 'Chosen by 78% of artists'}
                                                    </span>
                                                </div>
                                            )}
                                            <div className="text-4xl font-black mb-2 text-white">${plan.price}<span className="text-[10px] text-gray-600 ml-1 uppercase tracking-widest font-black">USD</span></div>
                                            <p className="text-gray-200 text-sm font-bold mb-4">{t.pricing.plans[plan.id].desc}</p>
                                            
                                            <ul className="space-y-4 w-full pt-8 border-t border-white/5 text-left">
                                                {t.pricing.plans[plan.id].features.map((f: string) => (
                                                    <li key={f} className="text-[11px] text-gray-400 font-medium flex items-start gap-3">
                                                        <Check className={`w-3.5 h-3.5 shrink-0 mt-0.5 ${plan.id === 'elite' ? 'text-purple-500' : plan.id === 'premium' ? 'text-emerald-500' : 'text-coffee-medium'}`} />
                                                        <span className="leading-tight">{f}</span>
                                                    </li>
                                                ))}
                                            </ul>
                                        </button>
                                    ))}
                                </div>

                                <div className="flex justify-center items-center gap-8 lg:hidden">
                                    <button 
                                        type="button"
                                        onClick={prevPlan}
                                        className="w-12 h-12 rounded-full border border-white/10 flex items-center justify-center bg-[#111] active:bg-purple-600 transition-all"
                                    >
                                        <ChevronLeft className="w-6 h-6 text-white" />
                                    </button>
                                    
                                    <div className="flex gap-3">
                                        {PLANS.map((_, i) => (
                                            <button
                                                key={i}
                                                type="button"
                                                onClick={() => scrollToPlanIndex(i)}
                                                className={`h-2 rounded-full transition-all duration-300 ${planActiveIndex === i ? 'w-8 bg-purple-600' : 'w-2 bg-white/10 hover:bg-white/20'}`}
                                            />
                                        ))}
                                    </div>

                                    <button 
                                        type="button"
                                        onClick={nextPlan}
                                        className="w-12 h-12 rounded-full border border-white/10 flex items-center justify-center bg-[#111] active:bg-purple-600 transition-all"
                                    >
                                        <ChevronRight className="w-6 h-6 text-white" />
                                    </button>
                                </div>
                            </motion.div>
                        )}

                        {step === 3 && (
                            <motion.div
                                key="step3"
                                initial={{ opacity: 0, x: 20 }}
                                animate={{ opacity: 1, x: 0 }}
                                transition={{ duration: 0.25 }}
                                exit={{ opacity: 0, x: -20 }}
                                className="space-y-8"
                            >
                                {/* CONTACT INFORMATION SECTION */}
                                <div className="bg-[#0a0a0a] border border-white/10 rounded-3xl p-6 sm:p-10 shadow-2xl">
                                    <h4 className="text-sm font-black text-[#dcfc44] mb-8 uppercase tracking-[0.3em] flex items-center gap-3">
                                        <div className="w-2.5 h-2.5 rounded-full bg-[#dcfc44] shadow-[0_0_10px_rgba(220,252,68,0.5)]"></div>
                                        {lang === 'es' ? 'Datos de Entrega' : 'Delivery Details'}
                                    </h4>
                                    <div className="grid md:grid-cols-2 gap-8">
                                        <div className="relative min-w-0">
                                            <label className="block text-xs font-black text-gray-200 mb-4 uppercase tracking-[0.2em] md:h-10 flex items-center leading-tight">
                                                {formData.plan === 'youtube'
                                                    ? (lang === 'es' ? '¿A qué WhatsApp te contactamos?' : 'What WhatsApp should we use to contact you?')
                                                    : (lang === 'es' ? '¿A qué WhatsApp te enviamos tu canción?' : 'Where should we send your song via WhatsApp?')}
                                            </label>
                                            <div className="flex gap-2">
                                                <button
                                                    type="button"
                                                    onClick={() => setShowCountrySelect(!showCountrySelect)}
                                                    className="bg-white/5 border border-white/20 rounded-2xl px-4 py-4 flex items-center gap-2 hover:bg-white/10 transition-all min-w-[100px] justify-center shrink-0 group"
                                                >
                                                    <span className="text-xl leading-none">{selectedCountry.flag}</span>
                                                    <span className="text-sm font-black text-white leading-none">{selectedCountry.code}</span>
                                                    <ChevronDown className={`w-4 h-4 text-gray-400 transition-transform group-hover:text-white ${showCountrySelect ? 'rotate-180' : ''}`} />
                                                </button>
                                                <input
                                                    type="tel"
                                                    placeholder="300 123 4567"
                                                    className="w-full min-w-0 bg-white/5 border border-white/20 rounded-2xl px-5 sm:px-6 py-4 focus:border-[#dcfc44] focus:bg-white/10 transition-all outline-none text-white text-lg font-bold placeholder:text-gray-600"
                                                    value={formData.phone}
                                                    onChange={e => setFormData({ ...formData, phone: e.target.value })}
                                                    required
                                                />
                                            </div>

                                            {showCountrySelect && (
                                                <div className="absolute top-full left-0 mt-3 w-full max-w-[300px] max-h-72 overflow-y-auto bg-[#111] border border-white/20 rounded-2xl shadow-[0_20px_50px_rgba(0,0,0,0.8)] z-50 p-2 custom-scrollbar">
                                                    {COUNTRIES.map((country) => (
                                                        <button
                                                            key={country.name}
                                                            type="button"
                                                            className="w-full flex items-center gap-4 px-4 py-3 hover:bg-[#dcfc44]/10 rounded-xl transition-all text-left group"
                                                            onClick={() => {
                                                                setSelectedCountry(country);
                                                                setShowCountrySelect(false);
                                                            }}
                                                        >
                                                            <span className="text-2xl">{country.flag}</span>
                                                            <div className="flex flex-col">
                                                                <span className="text-xs font-black text-white group-hover:text-[#dcfc44] transition-colors">{country.name}</span>
                                                                <span className="text-[10px] text-gray-500 font-bold">{country.code}</span>
                                                            </div>
                                                        </button>
                                                    ))}
                                                </div>
                                            )}
                                        </div>
                                        <div className="min-w-0">
                                            <label className="block text-xs font-black text-gray-200 mb-4 uppercase tracking-[0.2em] md:h-10 flex items-center">Email de entrega</label>
                                            <input
                                                type="email"
                                                placeholder="tu@email.com"
                                                className="w-full bg-white/5 border border-white/20 rounded-2xl px-6 py-4 focus:border-[#dcfc44] focus:bg-white/10 transition-all outline-none text-white text-lg font-bold placeholder:text-gray-600"
                                                value={formData.email}
                                                onChange={e => setFormData({ ...formData, email: e.target.value })}
                                                required
                                            />
                                        </div>
                                    </div>
                                </div>

                                {/* ORDER SUMMARY TICKET */}
                                {/* ORDER SUMMARY TICKET */}
                                <div className="bg-black/40 border-y sm:border border-white/10 sm:rounded-3xl p-5 sm:p-8 relative overflow-hidden shadow-2xl -mx-5 sm:mx-0">
                                    <div className="absolute top-0 left-0 w-2 h-full bg-coffee-medium"></div>
                                    <div className="flex flex-col sm:flex-row justify-between items-start gap-4 mb-8">
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
                                                    onClick={() => setStep(2)}
                                                    className="text-[9px] text-gray-500 hover:text-coffee-light border border-white/10 hover:border-coffee-medium/30 px-2 py-0.5 rounded transition-all uppercase font-black"
                                                >
                                                    {lang === 'es' ? 'Cambiar Plan' : 'Change Plan'}
                                                </button>
                                            </div>
                                        </div>
                                    <div className="text-left sm:text-right w-full sm:w-auto">
                                            {songQuantity > 1 ? (
                                                <>
                                                    <span className="text-lg text-gray-500 line-through">${formData.price * songQuantity}</span>
                                                    <span className="text-3xl font-black text-white ml-2">${totalPrice}</span>
                                                    <span className="text-[10px] text-gray-500 block">USD</span>
                                                </>
                                            ) : (
                                                <>
                                                    <span className="text-3xl font-black text-white">${formData.price}</span>
                                                    <span className="text-[10px] text-gray-500 block">USD</span>
                                                </>
                                            )}
                                        </div>
                                    </div>

                                    {/* SONG QUANTITY UPSELL */}
                                    {formData.plan !== 'youtube' && (
                                        <motion.div 
                                            initial={{ opacity: 0, y: 10 }}
                                            animate={{ opacity: 1, y: 0 }}
                                            transition={{ delay: 0.3 }}
                                            className="bg-[#0a0a0a] border border-[#dcfc44]/30 rounded-3xl p-4 sm:p-6 mb-6 relative overflow-hidden shadow-[0_10px_30px_rgba(0,0,0,0.5)]"
                                        >
                                            <div className="absolute top-0 left-0 w-full h-px bg-gradient-to-r from-transparent via-[#dcfc44]/40 to-transparent"></div>
                                            
                                            <div className="flex items-center justify-between mb-4">
                                                <div className="flex items-center gap-4">
                                                    <div className="w-10 h-10 rounded-xl bg-[#dcfc44]/10 flex items-center justify-center border border-[#dcfc44]/20">
                                                        <Music className="w-5 h-5 text-[#dcfc44]" />
                                                    </div>
                                                    <div>
                                                        <h5 className="text-sm font-black text-white uppercase tracking-wider">
                                                            {lang === 'es' ? '¿Quieres más canciones?' : 'Want more songs?'}
                                                        </h5>
                                                        <p className="text-[11px] text-gray-400 font-medium">
                                                            {lang === 'es' ? 'Lleva 3 o más y obtén 10% de descuento total' : 'Get 3 or more and get 10% total discount'}
                                                        </p>
                                                    </div>
                                                </div>
                                            </div>

                                            <div className="flex flex-col sm:flex-row items-center sm:items-end justify-between gap-6 sm:gap-4">
                                                <div className="flex items-center gap-3 bg-white/5 p-1.5 rounded-2xl border border-white/5">
                                                    <button
                                                        type="button"
                                                        onClick={() => { playTick(); setSongQuantity(q => Math.max(1, q - 1)); }}
                                                        disabled={songQuantity <= 1}
                                                        className="w-10 h-10 rounded-xl border border-white/10 flex items-center justify-center bg-white/5 hover:bg-white/10 disabled:opacity-20 disabled:cursor-not-allowed transition-all active:scale-95"
                                                    >
                                                        <Minus className="w-4 h-4 text-white" />
                                                    </button>
                                                    <div className="text-center min-w-[50px]">
                                                        <span className="text-2xl font-black text-white">{songQuantity}</span>
                                                        <p className="text-[8px] text-gray-500 uppercase tracking-widest font-black">
                                                            {songQuantity === 1 ? (lang === 'es' ? 'unidad' : 'unit') : (lang === 'es' ? 'unidades' : 'units')}
                                                        </p>
                                                    </div>
                                                    <button
                                                        type="button"
                                                        onClick={() => { playTick(); setSongQuantity(q => Math.min(10, q + 1)); }}
                                                        disabled={songQuantity >= 10}
                                                        className="w-10 h-10 rounded-xl border border-[#dcfc44]/30 flex items-center justify-center bg-[#dcfc44]/20 hover:bg-[#dcfc44]/30 disabled:opacity-20 disabled:cursor-not-allowed transition-all active:scale-95 shadow-[0_0_15px_rgba(220,252,68,0.1)]"
                                                    >
                                                        <Plus className="w-4 h-4 text-[#dcfc44]" />
                                                    </button>
                                                </div>

                                                {songQuantity > 1 && (
                                                    <motion.div
                                                        initial={{ opacity: 0, scale: 0.8 }}
                                                        animate={{ opacity: 1, scale: 1 }}
                                                        className="text-center sm:text-right w-full sm:w-auto"
                                                    >
                                                        <div className={`inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full mb-1 border shadow-lg ${discountPercent > 0 ? 'bg-[#dcfc44] border-[#dcfc44] text-black' : 'bg-white/5 border-white/10 text-gray-400'}`}>
                                                            <Sparkles className={`w-3.5 h-3.5 ${discountPercent > 0 ? 'text-black' : 'text-gray-500'}`} />
                                                            <span className="text-[11px] font-black uppercase tracking-wider">
                                                                {discountPercent > 0 
                                                                    ? (lang === 'es' ? `Ahorras $${totalSavings}` : `Save $${totalSavings}`)
                                                                    : (lang === 'es' ? 'Sin descuento' : 'No discount')}
                                                            </span>
                                                        </div>
                                                        <p className="text-[10px] text-gray-400 uppercase tracking-wider font-bold">
                                                            {discountPercent}% OFF  •  ${unitPriceWithDiscount.toFixed(2)} {lang === 'es' ? 'c/u' : 'each'}
                                                        </p>
                                                    </motion.div>
                                                )}
                                            </div>

                                            {/* Discount tier preview */}
                                            {songQuantity < 3 && (
                                                <div className="mt-4 pt-4 border-t border-white/5">
                                                    <p className="text-[10px] text-[#dcfc44] text-center font-black uppercase tracking-widest animate-pulse">
                                                        {lang === 'es' 
                                                            ? `💡 ¡Faltan ${3 - songQuantity} para el 10% de descuento!`
                                                            : `💡 Need ${3 - songQuantity} more for 10% OFF!`}
                                                    </p>
                                                </div>
                                            )}
                                        </motion.div>
                                    )}

                                    <div className="grid md:grid-cols-2 gap-8 mb-8">
                                        <div className="space-y-4">
                                            <h4 className="text-[11px] font-black text-gray-400 uppercase tracking-widest border-b border-white/10 pb-2">Información del Artista</h4>
                                            <div className="grid gap-3">
                                                <div>
                                                    <p className="text-[10px] text-gray-400 uppercase tracking-wider mb-1">Artista / Cliente</p>
                                                    <p className="text-xs text-white font-bold">{formData.name || '-'}</p>
                                                </div>
                                                <div>
                                                    <p className="text-[10px] text-gray-400 uppercase tracking-wider mb-1">Género</p>
                                                    <p className="text-xs text-white font-bold">{formData.genre}</p>
                                                </div>
                                            </div>
                                        </div>

                                        <div className="space-y-4">
                                            <h4 className="text-[11px] font-black text-gray-400 uppercase tracking-widest border-b border-white/10 pb-2">Especificaciones Creativas</h4>
                                            <div className="grid grid-cols-2 gap-3">
                                                <div>
                                                    <p className="text-[10px] text-gray-400 uppercase tracking-wider mb-1">Preferencia de Voz</p>
                                                    <p className="text-xs text-white font-bold">{formData.vocalist}</p>
                                                </div>
                                                <div>
                                                    <p className="text-[10px] text-gray-400 uppercase tracking-wider mb-1">Sentimiento</p>
                                                    <p className="text-xs text-white font-bold">{formData.mood}</p>
                                                </div>
                                                <div className="col-span-2">
                                                    <p className="text-[10px] text-gray-400 uppercase tracking-wider mb-1">Entrega Estimada</p>
                                                    <p className="text-xs text-coffee-light font-bold uppercase">
                                                        {formData.plan === 'elite' || formData.plan === 'premium' ? '24 HORAS' : '24-48 HORAS'}
                                                    </p>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

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

                                    <div className="flex flex-wrap gap-4 justify-center">
                                        {[
                                            'Producción por Humanos + IA',
                                            'Derechos de Autoría 100% (Legal)',
                                            formData.plan !== 'starter' ? 'Video Obsequio Incluido' : 'Audio en Alta Calidad',
                                            'Certificado de Propiedad'
                                        ].map(check => (
                                            <div key={check} className="flex items-center gap-2 text-[10px] text-gray-300 font-bold uppercase">
                                                <Check className="w-3 h-3 text-coffee-medium" />
                                                {check}
                                            </div>
                                        ))}
                                    </div>
                                </div>

                                {/* TRUST GUARANTEE PIE */}
                                <div className="flex flex-col items-center gap-6 py-6 border-t border-white/5 mt-8">
                                    <div className="flex items-center justify-center gap-3 flex-wrap">
                                        <div className="bg-white/[0.06] border border-white/15 rounded-lg px-3 py-2 flex items-center justify-center min-w-[52px] hover:bg-white/10 transition-all">
                                            <span className="text-white font-black text-[13px] italic tracking-tight">VISA</span>
                                        </div>
                                        <div className="bg-white/[0.06] border border-white/15 rounded-lg px-3 py-2 flex items-center gap-1.5 hover:bg-white/10 transition-all">
                                            <div className="w-5 h-5 rounded-full bg-red-500 -mr-2.5"></div>
                                            <div className="w-5 h-5 rounded-full bg-yellow-400 opacity-90"></div>
                                        </div>
                                        <div className="bg-white/[0.06] border border-white/15 rounded-lg px-3 py-2 flex items-center justify-center min-w-[52px] hover:bg-white/10 transition-all">
                                            <span className="text-[#7c75ff] font-black text-[13px] tracking-tight">stripe</span>
                                        </div>
                                        <div className="flex items-center gap-1.5 border border-white/15 rounded-lg px-3 py-2 bg-white/[0.06]">
                                            <Lock className="w-3 h-3 text-green-400" />
                                            <span className="text-[10px] font-black text-green-400 tracking-widest">SSL</span>
                                        </div>
                                    </div>

                                    <div className="flex items-center justify-center gap-4 px-6 py-5 bg-white/[0.05] border border-white/10 rounded-2xl w-full">
                                        <div className="w-12 h-12 rounded-full bg-coffee-medium/20 flex items-center justify-center border border-coffee-medium/30 shrink-0">
                                            <ShieldCheck className="w-6 h-6 text-coffee-medium" />
                                        </div>
                                        <div className="text-left">
                                            <p className="text-white font-black text-sm uppercase italic tracking-tight">
                                                {formData.plan === 'elite' || formData.plan === 'premium' ? '24 HORAS' : '24-48 HORAS'}
                                            </p>
                                            <div className="text-sm font-black text-white uppercase tracking-widest mb-1">{lang === 'es' ? 'Garantía Estándar Struky' : 'Struky Standard Guarantee'}</div>
                                            <div className="text-xs text-gray-300 leading-tight uppercase tracking-wider font-medium">{lang === 'es' ? 'Tu inversión está protegida. Calidad garantizada o revisamos hasta que ames tu canción.' : 'Your investment is protected. Guaranteed quality or we revise until you love your song.'}</div>
                                        </div>
                                    </div>
                                </div>
                            </motion.div>
                        )}
                    </AnimatePresence>

                    {step === 3 && (
                        <div className="text-center mt-8 mb-2 animate-pulse">
                            <p className="text-[10px] md:text-xs font-black text-coffee-medium uppercase tracking-[0.2em]">
                                {lang === 'es' 
                                    ? '🔥 Cupos limitados por atención humana real' 
                                    : '🔥 Limited spots due to real human attention'}
                            </p>
                        </div>
                    )}

                    <div className="flex flex-col gap-3 mt-6">
                        {step === 3 && (
                            <div className="flex justify-center mb-6">
                                <div className="inline-flex items-center gap-2 px-4 py-2 bg-emerald-500/10 border border-emerald-500/20 rounded-full text-emerald-400 shadow-[0_0_15px_rgba(16,185,129,0.1)]">
                                    <ShieldCheck className="w-3.5 h-3.5 shrink-0" />
                                    <span className="text-[9px] sm:text-[10px] font-black uppercase tracking-widest leading-none">
                                        {lang === 'es' ? 'Calidad garantizada o te devolvemos el dinero — sin preguntas.' : 'Guaranteed quality or your money back — no questions asked.'}
                                    </span>
                                </div>
                            </div>
                        )}
                        <div className={`flex ${step === 3 ? 'flex-col-reverse md:flex-row' : 'flex-row'} gap-3 sm:gap-4`}>
                            {step > 1 && (
                                <button
                                    type="button"
                                    onClick={prevStep}
                                    className={`btn-secondary ${step === 3 ? 'w-full md:flex-1' : 'w-1/3 md:flex-1'} !py-3 sm:!py-4 !px-2 sm:!px-4 text-[11px] sm:text-base shrink-0`}
                                >
                                    {lang === 'es' ? 'Atrás' : 'Back'}
                                </button>
                            )}
                            <button
                                type="submit"
                                disabled={isLoading}
                                className={`btn-primary ${step === 3 ? 'w-full md:flex-1 bg-[#A67C37] !py-4 sm:!py-4 !px-2 sm:!px-4 shadow-[0_0_30px_rgba(166,124,55,0.4)] hover:bg-[#B88C45]' : 'flex-1 !py-3 sm:!py-4 text-[11px] sm:text-base'}`}
                            >
                                {isLoading ? (
                                    <Loader2 className="w-5 h-5 sm:w-6 sm:h-6 animate-spin mx-auto text-white" />
                                ) : (
                                    step === 3 ? (
                                        <div className="flex items-center justify-center gap-1 sm:gap-4 py-0.5">
                                            <Sparkles className="w-4 h-4 sm:w-5 sm:h-5 text-white animate-pulse shrink-0 hidden sm:block" />
                                            <span className="font-black uppercase tracking-tight text-sm sm:text-xl text-white text-center leading-tight">
                                                {formData.plan === 'youtube'
                                                    ? (lang === 'es' ? `¡SOLICITAR SERVICIO! ($${totalPrice})` : `REQUEST SERVICE! ($${totalPrice})`)
                                                    : (lang === 'es' 
                                                        ? `¡CREAR ${songQuantity > 1 ? `MIS ${songQuantity} CANCIONES` : 'MI CANCIÓN'}! ($${totalPrice})`
                                                        : `CREATE ${songQuantity > 1 ? `MY ${songQuantity} SONGS` : 'MY SONG'}! ($${totalPrice})`)}
                                            </span>
                                        </div>
                                    ) : (
                                        <span className="font-black uppercase tracking-widest text-white/90 text-[11px] sm:text-base">
                                            {lang === 'es' ? 'Continuar' : 'Continue'}
                                        </span>
                                    )
                                )}
                            </button>
                        </div>
                        {step === 1 && (
                            <p className="text-center text-[10px] text-gray-500 uppercase tracking-widest font-bold">
                                {lang === 'es' 
                                    ? 'Sin compromiso — puedes cambiar el género después.' 
                                    : 'No commitment — you can change the genre later.'}
                            </p>
                        )}
                    </div>
                </form>

                {/* MASSIVE GUARANTEE BADGE */}
                <div className="max-w-4xl mx-auto mt-16">
                    <div className="bg-[#0A0A0A] border border-coffee-medium/20 rounded-3xl p-8 md:p-12 text-center relative overflow-hidden shadow-[0_10px_30px_rgba(0,0,0,0.5)]">
                        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[200%] md:w-full h-px bg-gradient-to-r from-transparent via-coffee-medium to-transparent opacity-50 z-20"></div>
                        
                        <div className="relative z-20 w-20 h-20 md:w-24 md:h-24 mx-auto bg-coffee-medium/10 rounded-full flex items-center justify-center mb-6 border border-coffee-medium/30 shadow-[0_0_50px_rgba(202,160,82,0.2)]">
                            <ShieldCheck className="w-10 h-10 md:w-12 md:h-12 text-coffee-medium" />
                        </div>
                        
                        <h3 className="relative z-20 text-2xl md:text-3xl font-black text-white uppercase tracking-tighter mb-4 italic">
                            {lang === 'es' ? 'Garantía 100%' : '100% Guarantee'} <span className="text-coffee-medium">{lang === 'es' ? 'Anti-Riesgo' : 'Risk-Free'}</span>
                        </h3>
                        <p className="relative z-20 text-gray-300 text-sm md:text-base max-w-2xl mx-auto leading-relaxed font-medium">
                            {lang === 'es' 
                                ? <>Nuestra misión es crear el hit que tienes en la cabeza. Si al recibir tu canción sientes que no tiene calidad de industria, <strong className="text-white">la rehacemos junto contigo hasta que te encante</strong>, o te devolvemos tu dinero. Sin letras pequeñas.</>
                                : <>Our mission is to create the hit you have in your head. If upon receiving your song you feel it lacks industry quality, <strong className="text-white">we will remake it with you until you love it</strong>, or you get your money back. No fine print.</>
                            }
                        </p>
                    </div>
                </div>
            </div>
        </section>
    );
}
