'use client';

import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Check, Star, Zap, Crown, Video, ChevronDown } from 'lucide-react';

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
}

export default function OrderForm({ lang }: OrderFormProps) {
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
                    return prev > 1 ? prev - 1 : 2; 
                } else if (rand < 0.2) { // 20% probabilidad de subir
                    return prev < 9 ? prev + 1 : 8;
                }
                return prev; 
            });
        }, 6000); 

        return () => clearInterval(interval);
    }, []);

    const [formData, setFormData] = React.useState({
        name: '',
        email: '',
        genre: 'Pop',
        vocalist: 'Sin preferencia',
        mood: 'Feliz',
        lyrics: '',
        notes: '',
        phone: '',
        plan: 'Starter',
        price: 50
    });

    const nextStep = () => setStep(s => Math.min(s + 1, 4));
    const prevStep = () => setStep(s => Math.max(s - 1, 1));

    const selectPlan = (plan: string, price: number) => {
        setFormData(prev => ({ ...prev, plan, price }));
        setStep(2);
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (step < 4) return nextStep();

        setIsLoading(true);
        try {
            const response = await fetch('/api/checkout', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    ...formData,
                    phone: `${selectedCountry.code} ${formData.phone}`
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

    return (
        <section id="order-form" className="section-padding bg-dark-card/30">
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
                                        className={`h-2 relative w-full rounded-full transition-all duration-500 mb-2 ${
                                            s <= step ? 'bg-gradient-to-r from-coffee-medium to-coffee-light shadow-[0_0_10px_rgba(202,160,82,0.5)]' : 'bg-white/10'
                                        }`}
                                    />
                                    <span className={`text-[9px] font-bold uppercase tracking-wider transition-colors duration-300 ${s <= step ? 'text-coffee-light' : 'text-gray-600'}`}>
                                        {lang === 'es' 
                                            ? (s === 1 ? 'Estilo' : s === 2 ? 'Letra' : s === 3 ? 'Plan' : 'Confirmar') 
                                            : (s === 1 ? 'Style' : s === 2 ? 'Lyrics' : s === 3 ? 'Plan' : 'Confirm')}
                                    </span>
                                </div>
                            </div>
                        ))}
                    </div>
                </div>

                <form onSubmit={handleSubmit} className="glass-morphism rounded-3xl p-8 md:p-12 relative overflow-hidden">
                    <AnimatePresence mode="wait">
                        {step === 1 && (
                            <motion.div 
                                key="step1"
                                initial={{ opacity: 0, x: 20 }}
                                animate={{ opacity: 1, x: 0 }}
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
                                            onChange={e => setFormData({...formData, genre: e.target.value})}
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
                                            onChange={e => setFormData({...formData, vocalist: e.target.value})}
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
                                        className="bg-white/5 p-4 rounded-xl border border-coffee-medium/30"
                                    >
                                        <label className="block text-[10px] font-black text-coffee-light mb-2 uppercase tracking-widest">
                                            {lang === 'es' ? 'Especifica tu género personalizado' : 'Specify your custom genre'}
                                        </label>
                                        <input 
                                            type="text"
                                            placeholder={lang === 'es' ? 'Ej: Bolero, Rock, Jazz...' : 'Ex: Bolero, Rock, Jazz...'}
                                            className="w-full bg-transparent border-b border-white/20 py-2 outline-none focus:border-coffee-light transition-all text-sm"
                                            onChange={e => setFormData({...formData, notes: `Género deseado: ${e.target.value}. ${formData.notes}`})}
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
                                        onChange={e => setFormData({...formData, name: e.target.value})}
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
                                exit={{ opacity: 0, x: -20 }}
                                className="space-y-6"
                            >
                                <div>
                                    <label className="block text-sm font-bold text-gray-400 mb-2 uppercase tracking-widest">{lang === 'es' ? 'Tu Letra' : 'Your Lyrics'}</label>
                                    <textarea 
                                        rows={4}
                                        className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 focus:border-coffee-light transition-all outline-none resize-none"
                                        value={formData.lyrics}
                                        onChange={e => setFormData({...formData, lyrics: e.target.value})}
                                        required
                                        placeholder={lang === 'es' ? 'Pega aquí tus versos...' : 'Paste your lyrics here...'}
                                    />
                                </div>
                                <div className="grid md:grid-cols-2 gap-6">
                                    <div>
                                        <label className="block text-sm font-bold text-gray-400 mb-2 uppercase tracking-widest">{lang === 'es' ? 'Estado de Ánimo' : 'Mood'}</label>
                                        <select 
                                            className="w-full bg-[#1a1a1a] border border-white/10 rounded-xl px-4 py-3 focus:border-coffee-light transition-all outline-none appearance-none text-white"
                                            style={{ colorScheme: 'dark' }}
                                            value={formData.mood}
                                            onChange={e => setFormData({...formData, mood: e.target.value})}
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
                                                className="flex-1 bg-white/5 border border-white/10 rounded-xl px-4 py-3 focus:border-coffee-light transition-all outline-none"
                                                value={formData.phone}
                                                onChange={e => setFormData({...formData, phone: e.target.value})}
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
                                            onChange={e => setFormData({...formData, email: e.target.value})}
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
                                exit={{ opacity: 0, scale: 0.95 }}
                                className="space-y-8"
                            >
                                <div className="text-center mb-4">
                                    <h4 className="text-xl font-bold text-coffee-light">{lang === 'es' ? 'Selecciona el nivel de acabado' : 'Select production level'}</h4>
                                    <p className="text-gray-500 text-sm">{lang === 'es' ? '¿Qué tan lejos quieres llevar tu canción?' : 'How far do you want to take your song?'}</p>
                                </div>
                                <div className="flex lg:grid lg:grid-cols-4 gap-4 lg:gap-6 overflow-x-auto lg:overflow-visible pt-6 lg:pt-0 pb-8 lg:pb-0 px-1 snap-x snap-mandatory custom-scrollbar-hide">
                                    {[
                                        { 
                                            id: 'Test Mode', 
                                            price: 1, 
                                            icon: Zap, 
                                            desc: 'SOLO PARA PRUEBAS REALES',
                                            features: [
                                                'Prueba de pasarela real',
                                                'Verificación de Webhook',
                                                'Test de correo Resend'
                                            ]
                                        },
                                        { 
                                            id: 'Starter', 
                                            price: 50, 
                                            icon: Zap, 
                                            desc: 'Ideal para Guía',
                                            features: [
                                                'Producción básica',
                                                'Calidad Maqueta profesional',
                                                'Entrega en 48-72h'
                                            ]
                                        },
                                        { 
                                            id: 'Pro Master', 
                                            price: 97, 
                                            icon: Star, 
                                            desc: 'Calidad Radio / Spotify', 
                                            hot: true,
                                            features: [
                                                'Producción Completa Premium',
                                                'Video Obsequio incluido',
                                                'Entrega Prioritaria (24-48h)',
                                                'Derechos comerciales'
                                            ]
                                        },
                                        { 
                                            id: 'Elite Studio', 
                                            price: 147, 
                                            icon: Crown, 
                                            desc: 'Fidelidad Máxima',
                                            features: [
                                                'Mezcla y Master de élite',
                                                'Multitracks / STEMS incluidos',
                                                'Video Obsequio Pro',
                                                'Soporte directo con productor'
                                            ]
                                        }
                                    ].map((plan) => (
                                        <button
                                            key={plan.id}
                                            type="button"
                                            onClick={() => {
                                                setFormData(prev => ({ ...prev, plan: plan.id, price: plan.price }));
                                                nextStep();
                                            }}
                                            className={`relative p-8 rounded-3xl border transition-all text-left flex flex-col items-center text-center group/card flex-shrink-0 w-[85%] lg:w-full snap-center ${
                                                formData.plan === plan.id 
                                                ? 'border-coffee-medium bg-coffee-medium/10 shadow-[0_0_30px_rgba(202,160,82,0.15)] scale-[1.02] lg:scale-105 z-10' 
                                                : 'border-white/10 bg-white/5 hover:border-white/20'
                                            }`}
                                        >
                                            {plan.hot && (
                                                <div className="absolute -top-4 left-1/2 -translate-x-1/2 bg-coffee-medium text-black text-[10px] font-black uppercase px-4 py-1.5 rounded-full whitespace-nowrap z-10 shadow-lg">
                                                    Más Popular
                                                </div>
                                            )}
                                            <plan.icon className={`w-12 h-12 mb-5 transition-transform group-hover/card:scale-110 ${formData.plan === plan.id ? 'text-coffee-light' : 'text-coffee-medium'}`} />
                                            <h4 className="font-black text-base mb-1 uppercase tracking-tight">{plan.id}</h4>
                                            <div className="text-4xl font-black mb-3 text-white">${plan.price}<span className="text-xs text-gray-500 ml-1">USD</span></div>
                                            <p className="text-[11px] text-coffee-light font-bold mb-6 uppercase tracking-widest">{plan.desc}</p>
                                            
                                            <ul className="space-y-3 w-full pt-6 border-t border-white/5 text-left">
                                                {plan.features.map(f => (
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
                                    <div className={`w-1.5 h-1.5 rounded-full ${formData.plan === 'Starter' ? 'bg-coffee-light' : 'bg-white/10'}`}></div>
                                    <div className={`w-1.5 h-1.5 rounded-full ${formData.plan === 'Pro Master' ? 'bg-coffee-light' : 'bg-white/10'}`}></div>
                                    <div className={`w-1.5 h-1.5 rounded-full ${formData.plan === 'Elite Studio' ? 'bg-coffee-light' : 'bg-white/10'}`}></div>
                                </div>
                            </motion.div>
                        )}

                        {step === 4 && (
                            <motion.div 
                                key="step4"
                                initial={{ opacity: 0, x: 20 }}
                                animate={{ opacity: 1, x: 0 }}
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
                                            <p className="text-[10px] text-coffee-light font-bold uppercase tracking-[0.3em]">
                                                {formData.plan} Edition
                                            </p>
                                        </div>
                                        <div className="text-right">
                                            <span className="text-3xl font-black text-white">${formData.price}</span>
                                            <span className="text-[10px] text-gray-500 block">USD</span>
                                        </div>
                                    </div>

                                    <div className="grid md:grid-cols-2 gap-8 mb-8">
                                        {/* Columna 1: Datos Personales */}
                                        <div className="space-y-4">
                                            <h4 className="text-[10px] font-black text-gray-500 uppercase tracking-widest border-b border-white/5 pb-2">Información de Contacto</h4>
                                            <div className="grid gap-3">
                                                <div>
                                                    <p className="text-[9px] text-gray-600 uppercase mb-1">Artista / Cliente</p>
                                                    <p className="text-xs text-white font-bold">{formData.name || '-'}</p>
                                                </div>
                                                <div>
                                                    <p className="text-[9px] text-gray-600 uppercase mb-1">WhatsApp de Entrega</p>
                                                    <p className="text-xs text-white font-bold">{selectedCountry.code} {formData.phone || '-'}</p>
                                                </div>
                                                <div>
                                                    <p className="text-[9px] text-gray-600 uppercase mb-1">Correo Electrónico</p>
                                                    <p className="text-xs text-white font-bold">{formData.email || '-'}</p>
                                                </div>
                                            </div>
                                        </div>

                                        {/* Columna 2: Especificaciones */}
                                        <div className="space-y-4">
                                            <h4 className="text-[10px] font-black text-gray-500 uppercase tracking-widest border-b border-white/5 pb-2">Especificaciones Creativas</h4>
                                            <div className="grid grid-cols-2 gap-3">
                                                <div>
                                                    <p className="text-[9px] text-gray-600 uppercase mb-1">Género</p>
                                                    <p className="text-xs text-white font-bold">{formData.genre}</p>
                                                </div>
                                                <div>
                                                    <p className="text-[9px] text-gray-600 uppercase mb-1">Preferencia de Voz</p>
                                                    <p className="text-xs text-white font-bold">{formData.vocalist}</p>
                                                </div>
                                                <div>
                                                    <p className="text-[9px] text-gray-600 uppercase mb-1">Estado de Ánimo</p>
                                                    <p className="text-xs text-white font-bold">{formData.mood}</p>
                                                </div>
                                                <div>
                                                    <p className="text-[9px] text-gray-600 uppercase mb-1">Entrega Estimada</p>
                                                    <p className="text-xs text-coffee-light font-bold">
                                                        {formData.plan === 'Elite Studio' ? '24 HORAS' : formData.plan === 'Pro Master' ? '24-48 HORAS' : '48-72 HORAS'}
                                                    </p>
                                                </div>
                                            </div>
                                        </div>
                                    </div>

                                    {/* Letra */}
                                    <div className="bg-white/5 rounded-2xl p-5 border border-white/5 mb-8">
                                        <p className="text-[9px] text-gray-600 uppercase tracking-widest mb-3">Versos Confirmados</p>
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
                                            <div key={check} className="flex items-center gap-2 text-[9px] text-gray-500 font-bold uppercase">
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
                                        <span className="text-sm font-black text-red-400 tabular-nums transition-all duration-500 inline-block scale-110">
                                            {slots} {lang === 'es' ? (slots === 1 ? 'CUPO RESTANTE' : 'CUPOS RESTANTES') : (slots === 1 ? 'SLOT LEFT' : 'SLOTS LEFT')}
                                        </span>
                                    </div>
                                </div>

                                {/* TRUST GUARANTEE PIE */}
                                <div className="flex items-center justify-center gap-4 py-4 opacity-60">
                                    <div className="w-12 h-12 rounded-full bg-white/5 flex items-center justify-center border border-white/10 shrink-0">
                                        <svg className="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/></svg>
                                    </div>
                                    <div className="text-left">
                                        <div className="text-sm font-bold text-white uppercase tracking-widest">{lang === 'es' ? 'Garantía de Satisfacción Total' : 'Total Satisfaction Guarantee'}</div>
                                        <div className="text-[10px] text-gray-400">{lang === 'es' ? 'Pagos 100% seguros y opciones de revisión musical.' : '100% Secure payments and musical revision options.'}</div>
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
                            className={`btn-primary w-full md:flex-1 ${step === 4 ? 'bg-coffee-medium !py-4' : ''}`}
                        >
                            {isLoading ? '...' : (
                                step === 4 ? (
                                    <div className="flex items-center justify-center gap-2">
                                        <svg className="w-5 h-5 text-black shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/></svg>
                                        <span className="whitespace-nowrap sm:whitespace-normal">{lang === 'es' ? `Finalizar y Pagar ($${formData.price} USD)` : `Finish & Pay ($${formData.price} USD)`}</span>
                                    </div>
                                ) : (
                                    lang === 'es' ? 'Continuar' : 'Continue'
                                )
                            )}
                        </button>
                    </div>
                </form>
            </div>
        </section>
    );
}
