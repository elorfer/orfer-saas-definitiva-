"use client";

import React, { useState, useEffect } from "react";
import Link from "next/link";
import { motion, AnimatePresence } from "framer-motion";
import { 
  IconSparkles, 
  IconRobot, 
  IconTarget, 
  IconHeart, 
  IconEye, 
  IconArrowRight, 
  IconDeviceMobile, 
  IconChevronDown, 
  IconCopy, 
  IconCheck, 
  IconPlayerPlayFilled, 
  IconCoins,
  IconBrain,
  IconArrowUpRight,
  IconSun,
  IconMoon,
  IconSend,
  IconTriangle,
  IconLoader2
} from "@tabler/icons-react";

// URLs de Imágenes externas (Cloudflare R2 / CDN) para optimizar recursos y rendimiento en Vercel
const HERO_IMAGE_URL = "/hero.webp"; // Imagen local de alta calidad para el Hero
const APP_INTERACTION_IMAGE_URL = "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?auto=format&fit=crop&q=80&w=1000"; // Reemplazar por tu enlace de Cloudflare
const SUCCESS_GRATITUDE_IMAGE_URL = "https://images.unsplash.com/photo-1506126613408-eca07ce68773?auto=format&fit=crop&q=80&w=1000"; // Reemplazar por tu enlace de Cloudflare

// Lista de afirmaciones por categoría para el widget interactivo
const affirmationsByCategory: Record<string, string[]> = {
  dinero: [
    "El dinero fluye hacia mí de múltiples fuentes de forma constante.",
    "Merezco la abundancia y la recibo con el corazón abierto.",
    "Soy un imán potente para la prosperidad y la riqueza financiera.",
    "Cada centavo que gasto regresa a mí multiplicado por diez."
  ],
  amor: [
    "Atraigo un amor sano, recíproco y profundamente alineado conmigo.",
    "Mi corazón está abierto para dar y recibir amor verdadero.",
    "Me amo incondicionalmente y proyecto esa vibración al universo.",
    "La persona ideal para mí está de camino a mi vida en este instante."
  ],
  exito: [
    "Soy capaz de lograr cualquier meta cuántica que me proponga.",
    "Mis ideas tienen un valor inmenso y el mundo está listo para recibirlas.",
    "El éxito es mi estado natural y lo abrazo con gratitud.",
    "Tengo la disciplina, la fuerza y la sabiduría para triunfar."
  ],
  confianza: [
    "Confío en mi intuición y actúo con seguridad en mí mismo.",
    "Soy valioso, inteligente y suficiente tal y como soy hoy.",
    "Suelto el miedo al juicio y brillo con mi propia luz.",
    "Tengo el control de mi energía y elijo vibrar en abundancia."
  ]
};

// FAQ data
const faqs = [
  {
    question: "¿Qué es Manifiestas AI?",
    answer: "Manifiestas AI es un coach interactivo que combina psicología cognitiva, neurociencia y el arte de la manifestación para ayudarte a reprogramar tu subconsciente. Ofrece diálogos con inteligencia artificial, generación de afirmaciones personalizadas, tableros de visualización y herramientas interactivas."
  },
  {
    question: "¿Cómo funciona el Coach de Manifestación?",
    answer: "Nuestro coach basado en inteligencia artificial te escucha de manera empática y sin juzgarte. Te ayuda a detectar creencias limitantes sobre el dinero, el amor o la salud, y te guía en la creación de planes de manifestación y reprogramación a 30 días."
  },
  {
    question: "¿Qué es el 'Spiritual Jackpot' o Estallido de Abundancia?",
    answer: "Es un estímulo visual y mental interactivo diseñado para liberar dopamina en el cerebro cuando visualizas una meta financiera. El cerebro aprende mediante la emoción y la repetición; este estallido simula visualmente la consecución de tus metas monetarias para consolidar tu fe y alineación."
  },
  {
    question: "¿Es gratis utilizar la aplicación?",
    answer: "Sí, puedes acceder de forma gratuita a las funciones básicas que incluyen las sesiones guiadas, el diario de gratitud y las afirmaciones del día. También ofrecemos opciones premium para sesiones extendidas y análisis del progreso."
  }
];

export default function LandingPage() {
  // Estado de Tema
  const [theme, setTheme] = useState<"light" | "dark">("light");

  // Leer tema inicial
  useEffect(() => {
    if (typeof window !== "undefined") {
      const isDark = document.documentElement.classList.contains("dark");
      setTheme(isDark ? "dark" : "light");
    }
  }, []);

  const toggleTheme = () => {
    if (theme === "dark") {
      document.documentElement.classList.remove("dark");
      localStorage.setItem("theme", "light");
      setTheme("light");
    } else {
      document.documentElement.classList.add("dark");
      localStorage.setItem("theme", "dark");
      setTheme("dark");
    }
  };

  // Estados para el widget de Afirmaciones
  const [selectedCategory, setSelectedCategory] = useState("dinero");
  const [currentAffirmation, setCurrentAffirmation] = useState(
    "El dinero fluye hacia mí de múltiples fuentes de forma constante."
  );
  const [copied, setCopied] = useState(false);

  // Estados para el simulador de Chat
  const [chatMessages, setChatMessages] = useState<Array<{ sender: "ai" | "user"; text: string }>>([
    { sender: "ai", text: "👋 ¡Hola! Soy tu mentor de manifestación. ¿Qué aspecto de tu vida deseas transformar hoy? (💰 Dinero, 💗 Amor o 🚀 Éxito)" }
  ]);
  const [isTyping, setIsTyping] = useState(false);

  // Estados para el simulador del Jackpot
  const [showJackpot, setShowJackpot] = useState(false);
  const [jackpotAmount, setJackpotAmount] = useState("10,000");
  const [displayJackpotAmount, setDisplayJackpotAmount] = useState(0);

  // Estados de FAQs
  const [openFaq, setOpenFaq] = useState<number | null>(null);

  // Estados del Triángulo de Manifestación Interactivo de la Landing
  const [landingStep, setLandingStep] = useState(1);
  const [landingDesire, setLandingDesire] = useState("");
  const [landingEmotion, setLandingEmotion] = useState("");
  const [landingAction, setLandingAction] = useState("");
  const [landingGenerating, setLandingGenerating] = useState(false);
  const [landingAffirmation, setLandingAffirmation] = useState("");
  const [landingCopied, setLandingCopied] = useState(false);

  // Estado para el aviso de cookies
  const [showCookieBanner, setShowCookieBanner] = useState(false);

  useEffect(() => {
    const consent = localStorage.getItem("cookieConsent");
    if (!consent) {
      setShowCookieBanner(true);
    }
  }, []);

  const handleAcceptCookies = () => {
    localStorage.setItem("cookieConsent", "accepted");
    setShowCookieBanner(false);
  };

  const handleActivateLandingTriangle = () => {
    if (!landingDesire.trim() || !landingEmotion.trim() || !landingAction.trim()) return;
    setLandingGenerating(true);
    setTimeout(() => {
      const templates = [
        `Decreto con convicción absoluta que estoy manifestando "${landingDesire}" sintiendo una profunda vibración de "${landingEmotion}". Hoy tomo la acción inspirada de "${landingAction}", sabiendo que el universo me respalda.`,
        `Yo elijo conscientemente experimentar "${landingDesire}" a través del sentimiento puro de "${landingEmotion}". Hoy realizo mi paso físico de "${landingAction}" y abro mi realidad al éxito.`,
        `Agradezco la llegada de "${landingDesire}" en mi vida física. Me inundo de la vibración de "${landingEmotion}" y hoy doy el paso alineado de "${landingAction}". Hecho está.`
      ];
      const randomIndex = Math.floor(Math.random() * templates.length);
      setLandingAffirmation(templates[randomIndex]);
      setLandingGenerating(false);
      setLandingStep(4);
    }, 2000); // 2 segundos de animación láser
  };

  // Cambiar afirmación con animación
  const handleGenerateAffirmation = (category: string) => {
    setSelectedCategory(category);
    const list = affirmationsByCategory[category];
    const randomIndex = Math.floor(Math.random() * list.length);
    setCurrentAffirmation(list[randomIndex]);
    setCopied(false);
  };

  const handleCopy = () => {
    navigator.clipboard.writeText(currentAffirmation);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  // Simular respuesta del chat
  const handleChatOption = (optionText: string, replyText: string) => {
    if (isTyping) return;
    
    setChatMessages(prev => [...prev, { sender: "user", text: optionText }]);
    setIsTyping(true);

    setTimeout(() => {
      setChatMessages(prev => [...prev, { sender: "ai", text: replyText }]);
      setIsTyping(false);
    }, 1000);
  };

  // Ejecutar el Spiritual Jackpot
  const startJackpotSimulation = () => {
    setShowJackpot(true);
    setDisplayJackpotAmount(0);
    const target = parseInt(jackpotAmount.replace(/,/g, ""), 10) || 10000;
    let current = 0;
    const step = Math.ceil(target / 40);

    const interval = setInterval(() => {
      current += step;
      if (current >= target) {
        setDisplayJackpotAmount(target);
        clearInterval(interval);
      } else {
        setDisplayJackpotAmount(current);
      }
    }, 40);
  };

  return (
    <div className="bg-background text-text-primary min-h-screen font-sans overflow-x-hidden transition-colors duration-300 selection:bg-accent-purple/30 selection:text-accent-gold">
      
      {/* GLOW DECORATIVOS DE FONDO (Se ven tenues en tema claro y más intensos en oscuro) */}
      <div className="absolute top-0 left-1/4 w-[40vw] h-[40vw] bg-accent-purple/5 dark:bg-accent-purple/10 rounded-full blur-[120px] pointer-events-none z-0"></div>
      <div className="absolute top-1/3 right-1/4 w-[35vw] h-[35vw] bg-primary/5 dark:bg-primary/10 rounded-full blur-[100px] pointer-events-none z-0"></div>
      <div className="absolute bottom-1/4 left-1/3 w-[30vw] h-[30vw] bg-accent-gold/3 dark:bg-accent-gold/5 rounded-full blur-[100px] pointer-events-none z-0"></div>

      {/* HEADER DE NAVEGACIÓN */}
      <header className="sticky top-0 z-50 glass-card border-b border-border-primary/80 backdrop-blur-md">
        <div className="max-w-7xl mx-auto px-6 py-4 flex justify-between items-center">
          <Link href="/" className="flex items-center gap-2 text-xl font-bold tracking-wider text-text-primary">
            <span className="text-accent-gold text-2xl">✨</span>
            <span className="font-extrabold tracking-tight">MANIFIESTAS AI</span>
          </Link>
          
          <nav className="hidden md:flex items-center gap-8 text-sm font-medium text-text-secondary">
            <a href="#features" className="hover:text-primary dark:hover:text-accent-gold transition-colors">Características</a>
            <a href="#demo" className="hover:text-primary dark:hover:text-accent-gold transition-colors">Demo Interactiva</a>
            <a href="#how-it-works" className="hover:text-primary dark:hover:text-accent-gold transition-colors">Cómo Funciona</a>
            <a href="#faqs" className="hover:text-primary dark:hover:text-accent-gold transition-colors">Preguntas</a>
          </nav>

          <div className="flex items-center gap-4">
            {/* Botón de alternancia de tema */}
            <button 
              onClick={toggleTheme}
              className="p-2.5 rounded-full bg-bg-primary dark:bg-white/5 border border-border-primary hover:border-primary/30 dark:border-white/10 dark:hover:border-white/20 transition-all text-text-secondary hover:text-text-primary"
              aria-label="Cambiar tema"
            >
              {theme === "dark" ? <IconSun size={18} className="text-accent-gold" /> : <IconMoon size={18} className="text-primary" />}
            </button>

            <Link 
              href="/app" 
              className="px-5 py-2.5 rounded-full bg-primary hover:bg-primary-dark text-white font-medium text-sm transition-all duration-300 flex items-center gap-1.5 shadow-md shadow-primary/15 hover:shadow-primary/30 hover:scale-[1.02]"
            >
              Iniciar App <IconArrowUpRight size={16} />
            </Link>
          </div>
        </div>
      </header>

      {/* HERO SECTION */}
      <section className="relative max-w-7xl mx-auto px-6 pt-16 pb-24 md:pt-28 md:pb-36 z-10">
        <div className="grid grid-cols-12 gap-6 md:gap-12 items-center">
          
          {/* Columna Izquierda: Mensaje principal */}
          <div className="col-span-12 md:col-span-7 text-left space-y-6 md:space-y-8 flex flex-col items-start">
            <motion.div 
              initial={{ opacity: 0, y: 15 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-[#534AB7]/8 dark:bg-violet-950/30 border border-[#534AB7]/15 dark:border-violet-800/30 text-[10px] sm:text-xs font-bold text-[#534AB7] dark:text-violet-400 tracking-wide uppercase shadow-sm select-none"
            >
              <IconSparkles size={12} className="animate-pulse" />
              MENTOR DE REPROGRAMACIÓN SUBCONSCIENTE
            </motion.div>
            
            <motion.h1 
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, delay: 0.1 }}
              className="text-4xl sm:text-5xl lg:text-6xl font-black text-text-primary leading-[1.15] md:leading-tight tracking-tight"
            >
              Alinea tu frecuencia. <br />
              <span className="bg-gradient-to-r from-primary via-accent-purple to-accent-gold bg-clip-text text-transparent">
                Materializa tu nueva realidad.
              </span>
            </motion.h1>
            
            <motion.p 
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, delay: 0.2 }}
              className="text-text-secondary text-lg md:text-xl leading-relaxed max-w-xl"
            >
              Reprograma tu mente con Inteligencia Artificial, visualizaciones guiadas y hábitos transformadores.
            </motion.p>
            
            <motion.div 
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, delay: 0.3 }}
              className="flex flex-col sm:flex-row gap-4 pt-2 w-full sm:w-auto"
            >
              <Link 
                href="/app" 
                className="w-full sm:w-auto px-8 py-4 rounded-2xl bg-gradient-to-r from-primary to-accent-purple hover:from-primary-dark hover:to-accent-purple text-white font-bold shadow-lg shadow-primary/20 hover:shadow-primary/30 transition-all duration-300 flex items-center justify-center gap-2 hover:scale-[1.03]"
              >
                Comenzar gratis <IconArrowRight size={20} />
              </Link>
              <a 
                href="#demo" 
                className="w-full sm:w-auto px-8 py-4 rounded-2xl bg-bg-primary dark:bg-white/5 border border-border-secondary dark:border-white/15 text-text-primary dark:text-slate-200 font-bold hover:bg-bg-secondary dark:hover:bg-white/10 transition-all flex items-center justify-center gap-2 shadow-sm"
              >
                Probar Demo
              </a>
              
              <div className="hidden sm:flex w-full text-xs sm:text-sm text-text-secondary/70 items-center gap-1.5 mt-2 select-none">
                <span>🛡️</span> Sin tarjeta de crédito  •  Cancela cuando quieras
              </div>
            </motion.div>
            
            {/* Fila de stats (Solo visible en escritorio) */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.8, delay: 0.4 }}
              className="hidden md:grid pt-8 border-t border-border-primary dark:border-white/5 grid-cols-3 gap-6 max-w-md text-left w-full"
            >
              <div>
                <p className="text-2xl font-black text-text-primary">98%</p>
                <p className="text-xs text-text-secondary mt-1">Vibración positiva</p>
              </div>
              <div>
                <p className="text-2xl font-black text-text-primary">24/7</p>
                <p className="text-xs text-text-secondary mt-1">Disponibilidad</p>
              </div>
              <div>
                <p className="text-2xl font-black text-text-primary">10x</p>
                <p className="text-xs text-text-secondary mt-1">Enfoque mental</p>
              </div>
            </motion.div>
          </div>

          {/* 2. COLUMNA ESCRITORIO (Solo visible en desktop) - Dashboard + Celular superpuesto */}
          <div className="hidden md:flex md:col-span-5 relative w-full h-[550px] lg:h-[600px] justify-center items-center select-none">
            {/* Fondo con brillo espiritual detrás de los mockups */}
            <div className="absolute -inset-4 bg-gradient-to-tr from-primary/10 via-accent-purple/10 to-accent-gold/5 rounded-[40px] blur-3xl opacity-80 pointer-events-none" />

            {/* Dashboard Mockup */}
            <motion.div
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.8, delay: 0.2 }}
              className="flex absolute left-0 top-6 w-[85%] h-[80%] rounded-3xl bg-white/40 dark:bg-[#120b29]/45 backdrop-blur-xl border border-white/20 dark:border-white/10 shadow-2xl flex-col overflow-hidden"
            >
              {/* Browser Window Header */}
              <div className="h-9 px-4 border-b border-border-primary/50 dark:border-white/5 bg-white/20 dark:bg-slate-900/30 flex items-center justify-between shrink-0">
                <div className="flex items-center gap-1.5">
                  <span className="w-2.5 h-2.5 rounded-full bg-red-400/90 inline-block" />
                  <span className="w-2.5 h-2.5 rounded-full bg-yellow-400/90 inline-block" />
                  <span className="w-2.5 h-2.5 rounded-full bg-green-400/90 inline-block" />
                </div>
                <div className="w-[60%] h-5 bg-white/30 dark:bg-white/5 border border-white/10 dark:border-white/5 rounded-md flex items-center justify-center text-[9px] text-text-secondary/70 dark:text-slate-400">
                  app.manifiestas.com/coach
                </div>
                <div className="w-6" />
              </div>

              {/* Dashboard Body */}
              <div className="flex-1 flex overflow-hidden">
                {/* Sidebar */}
                <div className="w-12 border-r border-border-primary/50 dark:border-white/5 bg-white/15 dark:bg-slate-900/10 flex flex-col items-center py-4 gap-4 shrink-0">
                  <span className="text-[12px] opacity-80">💬</span>
                  <span className="text-[12px] opacity-40">📓</span>
                  <span className="text-[12px] opacity-40">🪙</span>
                  <span className="text-[12px] opacity-40">⚙️</span>
                </div>

                {/* Content */}
                <div className="flex-1 p-4 flex flex-col gap-3 overflow-hidden text-[10px]">
                  <div className="flex justify-between items-center pb-2 border-b border-border-primary/50 dark:border-white/5">
                    <div>
                      <div className="font-bold text-text-primary dark:text-white">✨ Coach de Manifestación</div>
                      <div className="text-[8px] text-green-400 flex items-center gap-1">
                        <span className="w-1.5 h-1.5 rounded-full bg-green-400 animate-pulse"></span> En línea
                      </div>
                    </div>
                    <span className="px-2 py-0.5 rounded-full bg-primary/10 text-primary text-[8px] font-bold">Frecuencia Alta</span>
                  </div>

                  <div className="flex-1 flex flex-col gap-2.5 overflow-hidden">
                    <div className="flex gap-2 items-start max-w-[85%] self-start">
                      <span className="w-5 h-5 rounded-full bg-primary/10 flex items-center justify-center text-[9px] shrink-0 border border-primary/20">🤖</span>
                      <div className="bg-bg-primary dark:bg-white/5 border border-border-primary dark:border-white/10 text-text-secondary dark:text-slate-200 px-3 py-2 rounded-2xl rounded-bl-none shadow-sm leading-relaxed">
                        Hola, comencemos tu reprogramación. ¿En qué área deseas enfocar tu intención hoy?
                      </div>
                    </div>
                    
                    <div className="bg-gradient-to-r from-primary to-accent-purple text-white px-3 py-2 rounded-2xl rounded-br-none max-w-[70%] self-end shadow-sm">
                      💰 Deseo manifestar prosperidad financiera.
                    </div>
                  </div>
                </div>
              </div>
            </motion.div>

            {/* Celular Flotante Desktop */}
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ duration: 0.8 }}
              className="absolute right-0 bottom-0 md:-right-4 md:-bottom-2 w-[170px] lg:w-[185px] aspect-[9/18.5] rounded-[36px] bg-bg-primary border-[5px] border-text-primary dark:border-slate-800 shadow-[0_20px_50px_rgba(0,0,0,0.3),_0_0_30px_rgba(139,92,246,0.15)] overflow-hidden flex flex-col z-20"
            >
              {/* Notch */}
              <div className="absolute top-1 left-1/2 -translate-x-1/2 w-16 h-2.5 bg-text-primary dark:bg-slate-800 rounded-full z-30" />

              {/* Status Bar */}
              <div className="pt-5 px-3 pb-1 flex justify-between items-center text-[8px] text-text-secondary/55 dark:text-white/40 font-semibold shrink-0">
                <span>9:41</span>
                <div className="flex items-center gap-1"><span>📶</span><span>🔋</span></div>
              </div>

              {/* Header App Celular */}
              <div className="px-2 py-1.5 bg-gradient-to-br from-primary-dark to-primary text-white flex justify-between items-center shrink-0 shadow-sm">
                <div>
                  <div className="text-[7.5px] font-bold flex items-center gap-0.5">
                    ✨ Manifiestas AI
                  </div>
                  <div className="text-[5.5px] opacity-80 leading-none">
                    Tu coach de manifestación
                  </div>
                </div>
                <div className="text-[5.5px] bg-white/15 px-1 py-0.5 rounded-full border border-white/10 flex items-center gap-0.5 font-semibold leading-none shrink-0">
                  <span className="w-0.5 h-0.5 rounded-full bg-green-400 animate-pulse"></span> 24/7
                </div>
              </div>

              {/* Chat Celular */}
              <div className="flex-1 px-2 py-2 flex flex-col gap-2 overflow-hidden text-[7.5px] leading-snug">
                <div className="flex gap-1 items-end max-w-[88%] self-start">
                  <div className="w-3.5 h-3.5 rounded-full bg-primary/10 flex items-center justify-center text-[5px] shrink-0 border border-primary/20">🤖</div>
                  <div className="bg-bg-secondary dark:bg-white/5 border border-border-primary dark:border-white/10 text-text-secondary dark:text-slate-200 px-1.5 py-1 rounded-lg rounded-bl-none shadow-sm">
                    ¿En qué deseas enfocarte hoy?
                  </div>
                </div>
                
                <div className="bg-gradient-to-r from-primary to-accent-purple text-white px-1.5 py-1 rounded-lg rounded-br-none max-w-[80%] self-end shadow-sm">
                  💰 Dinero y abundancia.
                </div>

                <div className="flex gap-1 items-end max-w-[88%] self-start">
                  <div className="w-3.5 h-3.5 rounded-full bg-primary/10 flex items-center justify-center text-[5px] shrink-0 border border-primary/20">🤖</div>
                  <div className="bg-bg-secondary dark:bg-white/5 border border-border-primary dark:border-white/10 text-text-secondary dark:text-slate-200 px-1.5 py-1 rounded-lg rounded-bl-none space-y-0.5">
                    <div className="font-bold text-accent-gold text-[5px]">✦ Afirmación:</div>
                    <div className="italic">"Merezco la abundancia y la recibo hoy."</div>
                  </div>
                </div>
              </div>

              {/* Input Celular */}
              <div className="p-1 border-t border-border-primary/50 dark:border-white/5 bg-bg-secondary/40 dark:bg-slate-900/30 flex gap-1 items-center shrink-0">
                <div className="flex-1 bg-bg-primary dark:bg-white/5 border border-border-primary/50 dark:border-white/10 rounded-full py-0.5 px-2 text-[5px] text-text-secondary/60 dark:text-slate-400 flex items-center justify-between">
                  <span>Escríbeme lo que sientes...</span>
                  <span>🎙️</span>
                </div>
                <div className="w-3.5 h-3.5 rounded-full bg-primary flex items-center justify-center text-white text-[5px] cursor-pointer shadow-sm shrink-0">
                  <IconSend size={6} />
                </div>
              </div>

              {/* Bottom Navigation Mockup (Desktop Phone) */}
              <div className="border-t border-border-primary/50 dark:border-white/5 bg-bg-secondary/40 dark:bg-slate-900/30 flex shrink-0 justify-around py-1 text-[5px] font-semibold text-text-secondary select-none">
                <div className="flex-1 flex flex-col items-center gap-0.5 text-primary dark:text-violet-400 font-extrabold border-b border-primary dark:border-violet-400 pb-0.5">
                  <IconRobot size={8} stroke={2} />
                  <span>Coach</span>
                </div>
                <div className="flex-1 flex flex-col items-center gap-0.5 opacity-60">
                  <IconSparkles size={8} stroke={1.5} />
                  <span>Afirmar</span>
                </div>
                <div className="flex-1 flex flex-col items-center gap-0.5 opacity-60">
                  <IconTarget size={8} stroke={1.5} />
                  <span>Metas</span>
                </div>
                <div className="flex-1 flex flex-col items-center gap-0.5 opacity-60">
                  <IconHeart size={8} stroke={1.5} />
                  <span>Gratitud</span>
                </div>
                <div className="flex-1 flex flex-col items-center gap-0.5 opacity-60">
                  <IconEye size={8} stroke={1.5} />
                  <span>Visualizar</span>
                </div>
              </div>
            </motion.div>

            {/* Widgets Flotantes Desktop */}
            <div className="absolute top-10 right-4 p-3 rounded-2xl bg-white/70 dark:bg-[#120b29]/70 backdrop-blur-xl border border-white/30 dark:border-white/10 shadow-lg flex items-center gap-2.5 z-30">
              <div className="w-8 h-8 rounded-full bg-green-500/10 flex items-center justify-center text-green-500">
                <IconSparkles size={16} />
              </div>
              <div>
                <p className="text-[8px] text-text-secondary font-semibold uppercase tracking-wider">Frecuencia Mental</p>
                <p className="text-xs font-black text-text-primary dark:text-white flex items-center gap-1">
                  98% Alta <span className="w-1.5 h-1.5 rounded-full bg-green-500 inline-block"></span>
                </p>
              </div>
            </div>

            <div className="hidden lg:flex absolute bottom-20 -left-6 p-3.5 rounded-2xl bg-white/70 dark:bg-[#120b29]/70 backdrop-blur-xl border border-white/30 dark:border-white/10 shadow-xl flex-col gap-1 max-w-[180px] z-30">
              <div className="flex items-center gap-1.5 text-accent-gold">
                <IconSparkles size={12} />
                <span className="text-[7.5px] font-bold uppercase tracking-wider">Alineación Diaria</span>
              </div>
              <p className="text-[9.5px] text-text-primary dark:text-slate-200 font-medium italic leading-relaxed">
                "El dinero fluye hacia mí multiplicado x10."
              </p>
            </div>
          </div>

          {/* 3. COLUMNA MÓVIL (Solo visible en pantallas menores a md) - Celular centrado según diseño recomendado */}
          <div className="col-span-12 md:hidden relative w-full flex flex-col items-center justify-center pt-8 pb-4 overflow-visible select-none">
            
            {/* Fondo curvo degradado lavanda (como en la captura) */}
            <div className="absolute bottom-0 left-1/2 -translate-x-1/2 w-[140%] aspect-[1/0.5] rounded-[100%] bg-gradient-to-t from-violet-100/60 via-violet-50/10 to-transparent dark:from-violet-950/20 dark:via-transparent -z-10" />

            {/* Estrellas decorativas de 4 puntas flotando (SVG de la captura) */}
            {/* Estrella izquierda */}
            <motion.div 
              animate={{ opacity: [0.3, 0.8, 0.3], scale: [0.9, 1.1, 0.9] }}
              transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
              className="absolute left-2 sm:left-4 top-1/3 text-violet-300 dark:text-violet-500 opacity-60"
            >
              <svg className="w-5 h-5 fill-current" viewBox="0 0 24 24">
                <path d="M12 0l3 9 9 3-9 3-3 9-3-9-9-3 9-3z" />
              </svg>
            </motion.div>
            
            {/* Estrella derecha */}
            <motion.div 
              animate={{ opacity: [0.4, 0.9, 0.4], scale: [1, 1.2, 1] }}
              transition={{ duration: 3.5, repeat: Infinity, ease: "easeInOut", delay: 0.5 }}
              className="absolute right-2 sm:right-4 top-1/4 text-violet-300 dark:text-violet-500 opacity-70"
            >
              <svg className="w-6 h-6 fill-current" viewBox="0 0 24 24">
                <path d="M12 0l3 9 9 3-9 3-3 9-3-9-9-3 9-3z" />
              </svg>
            </motion.div>

            {/* Celular Flotante de Alta Fidelidad (Centrado) */}
            <motion.div
              initial={{ opacity: 0, y: 40 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8 }}
              className="relative w-[280px] sm:w-[320px] aspect-[9/18.5] rounded-[36px] sm:rounded-[40px] bg-[#fcfbfe] dark:bg-[#0c0721] border-[6px] border-slate-900 dark:border-slate-800 shadow-[0_25px_60px_-15px_rgba(0,0,0,0.25),_0_0_40px_rgba(139,92,246,0.1)] overflow-hidden flex flex-col transition-colors z-10"
            >
              {/* Notch */}
              <div className="absolute top-2 left-1/2 -translate-x-1/2 w-20 h-3 bg-slate-900 dark:bg-slate-800 rounded-full z-30" />

              {/* Status Bar */}
              <div className="pt-5 px-5 pb-1 flex justify-between items-center text-[9px] text-slate-400 dark:text-white/40 font-semibold shrink-0">
                <span>9:41</span>
                <div className="flex items-center gap-1.5"><span>📶</span><span>🔋</span></div>
              </div>

              {/* Header Real de la App (mismo degradado que Header.tsx) */}
              <div className="px-4 py-3 bg-gradient-to-br from-[#3C3489] to-[#534AB7] text-white flex justify-between items-center shrink-0 relative overflow-hidden shadow-md">
                {/* Círculo decorativo como el real */}
                <div className="absolute -top-4 -right-4 w-14 h-14 bg-white/10 rounded-full blur-xl" />
                <div className="relative z-10">
                  <div className="text-[11px] font-semibold flex items-center gap-1">
                    ✨ Manifiestas AI
                  </div>
                  <div className="text-[8px] opacity-85 leading-tight">
                    Tu coach de manifestación — 24/7
                  </div>
                </div>
                <div className="relative z-10 w-5 h-5 rounded-full bg-white/10 border border-white/15 flex items-center justify-center">
                  <IconMoon size={9} className="text-white" />
                </div>
              </div>

              {/* Chat Celular Móvil */}
              <div className="flex-1 px-3 py-3 flex flex-col gap-2.5 overflow-hidden text-[10px] leading-relaxed bg-[#fcfbfe] dark:bg-[#0c0721]">
                {/* Bubble AI 1 */}
                <div className="flex gap-2 items-end max-w-[88%] self-start">
                  <div className="w-5 h-5 rounded-full bg-primary/10 flex items-center justify-center text-[9px] shrink-0 border border-primary/20">🤖</div>
                  <div className="bg-[#f0ecfa] dark:bg-white/5 border border-[#e2dcf7] dark:border-white/10 text-slate-600 dark:text-slate-200 px-3 py-2 rounded-2xl rounded-bl-none shadow-sm">
                    👋 Hola! Soy tu coach. ¿En qué área de tu vida quieres enfocarte hoy — dinero, amor, salud?
                  </div>
                </div>
                
                {/* Bubble User */}
                <div className="bg-[#534AB7] text-white px-3 py-2 rounded-2xl rounded-br-none max-w-[75%] self-end shadow-sm">
                  💰 Dinero y abundancia
                </div>

                {/* Bubble AI 2 */}
                <div className="flex gap-2 items-end max-w-[90%] self-start">
                  <div className="w-5 h-5 rounded-full bg-primary/10 flex items-center justify-center text-[9px] shrink-0 border border-primary/20">🤖</div>
                  <div className="bg-[#f0ecfa] dark:bg-white/5 border border-[#e2dcf7] dark:border-white/10 text-slate-600 dark:text-slate-200 px-3 py-2 rounded-2xl rounded-bl-none shadow-sm space-y-0.5">
                    <div className="font-bold text-[#f59e0b] text-[8px] uppercase tracking-wider">✦ Afirmación:</div>
                    <div className="italic text-[9px]">"Merezco la abundancia y la recibo hoy."</div>
                  </div>
                </div>
              </div>

              {/* Input bar real de la app */}
              <div className="px-3 py-2 border-t border-[#f0ecfa] dark:border-white/5 bg-[#fcfbfe] dark:bg-[#0c0721] flex gap-2 items-center shrink-0">
                <div className="flex-1 px-3 py-1.5 rounded-xl border border-[#e2dcf7] dark:border-white/10 bg-white dark:bg-white/5 text-[9px] text-slate-400 dark:text-slate-500">
                  Escríbeme lo que sientes...
                </div>
                <div className="w-6 h-6 rounded-lg bg-[#534AB7] flex items-center justify-center text-white cursor-pointer shadow-md shrink-0">
                  <IconSend size={11} />
                </div>
              </div>

              {/* Bottom Navigation Real (idéntico a Navigation.tsx) */}
              <div className="border-t border-[#f0ecfa] dark:border-white/5 bg-[#f8f6fc] dark:bg-[#120b29] flex shrink-0 overflow-x-auto">
                {[
                  { icon: IconRobot, label: "Coach", active: true },
                  { icon: IconSparkles, label: "Afirmar", active: false },
                  { icon: IconTarget, label: "Metas", active: false },
                  { icon: IconHeart, label: "Gratitud", active: false },
                  { icon: IconEye, label: "Visualizar", active: false },
                ].map(({ icon: Icon, label, active }) => (
                  <div
                    key={label}
                    className={`flex-1 min-w-[44px] py-1.5 text-[7px] flex flex-col items-center gap-0.5 border-b-[1.5px] ${
                      active
                        ? "border-[#534AB7] text-[#534AB7] dark:border-violet-400 dark:text-violet-400 font-bold"
                        : "border-transparent text-slate-400 dark:text-slate-500"
                    }`}
                  >
                    <Icon size={11} stroke={active ? 2 : 1.5} />
                    <span className="font-medium">{label}</span>
                  </div>
                ))}
              </div>
            </motion.div>

          </div>
        </div>
      </section>

      {/* CARACTERÍSTICAS PRINCIPALES */}
      <section id="features" className="py-24 border-t border-border-primary dark:border-white/5 bg-bg-primary/50 dark:bg-slate-950/40 relative z-10 transition-colors">
        <div className="max-w-7xl mx-auto px-6 text-center">
          
          <div className="max-w-2xl mx-auto space-y-4 mb-20">
            <h2 className="text-xs font-bold text-primary dark:text-accent-gold uppercase tracking-widest">
              El Sistema de Manifestación Completo
            </h2>
            <p className="text-3xl sm:text-4xl font-black text-text-primary tracking-tight">
              Herramientas de reprogramación diaria en un solo lugar
            </p>
            <p className="text-text-secondary">
              Desarrollamos una metodología digital única para ayudarte a mantenerte alineado en tu frecuencia de logro.
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-8">
            
            {/* Carta 1: AI Coach */}
            <div className="glass-card p-6 rounded-3xl text-left hover:border-primary/40 transition-all duration-300 group flex flex-col justify-between">
              <div>
                <div className="w-12 h-12 rounded-2xl bg-primary/10 border border-primary/20 flex items-center justify-center text-primary mb-6 group-hover:scale-110 transition-transform">
                  <IconRobot size={24} />
                </div>
                <h3 className="text-lg font-bold text-text-primary mb-3">Coach de IA 24/7</h3>
                <p className="text-text-secondary text-xs leading-relaxed">
                  Habla libremente con un mentor virtual entrenado en leyes de atracción, programación neurolingüística y coaching ontológico.
                </p>
              </div>
              <div className="pt-6 flex items-center gap-1.5 text-primary dark:text-accent-gold text-xs font-bold">
                Iniciar diálogo <IconArrowRight size={12} />
              </div>
            </div>

            {/* Carta 2: Triángulo de Manifestación */}
            <div className="glass-card p-6 rounded-3xl text-left hover:border-accent-purple/40 transition-all duration-300 group flex flex-col justify-between">
              <div>
                <div className="w-12 h-12 rounded-2xl bg-accent-purple/10 border border-accent-purple/20 flex items-center justify-center text-accent-purple mb-6 group-hover:scale-110 transition-transform">
                  <IconTriangle size={24} />
                </div>
                <h3 className="text-lg font-bold text-text-primary mb-3">Triángulo de Manifestación</h3>
                <p className="text-text-secondary text-xs leading-relaxed">
                  Alinea tu Deseo, tus Emociones y tu Acción física en un triángulo interactivo con afirmaciones creadas por Gemini y metas automáticas.
                </p>
              </div>
              <div className="pt-6 flex items-center gap-1.5 text-primary dark:text-accent-gold text-xs font-bold">
                Activar triángulo <IconArrowRight size={12} />
              </div>
            </div>

            {/* Carta 3: Reto de 30 Días */}
            <div className="glass-card p-6 rounded-3xl text-left hover:border-accent-gold/40 transition-all duration-300 group flex flex-col justify-between">
              <div>
                <div className="w-12 h-12 rounded-2xl bg-accent-gold/10 border border-accent-gold/20 flex items-center justify-center text-accent-gold mb-6 group-hover:scale-110 transition-transform">
                  <IconTarget size={24} />
                </div>
                <h3 className="text-lg font-bold text-text-primary mb-3">Retos de 30 Días con IA</h3>
                <p className="text-text-secondary text-xs leading-relaxed">
                  Hackea tu subconsciente con un plan gamificado de 30 días con micro-acciones físicas diarias adaptadas por la IA a tu meta.
                </p>
              </div>
              <div className="pt-6 flex items-center gap-1.5 text-primary dark:text-accent-gold text-xs font-bold">
                Generar reto <IconArrowRight size={12} />
              </div>
            </div>

            {/* Carta 4: Visualización Cuántica */}
            <div className="glass-card p-6 rounded-3xl text-left hover:border-blue-400/40 transition-all duration-300 group flex flex-col justify-between">
              <div>
                <div className="w-12 h-12 rounded-2xl bg-blue-500/10 border border-blue-500/20 flex items-center justify-center text-blue-400 mb-6 group-hover:scale-110 transition-transform">
                  <IconEye size={24} />
                </div>
                <h3 className="text-lg font-bold text-text-primary mb-3">Visualización y Calma</h3>
                <p className="text-text-secondary text-xs leading-relaxed">
                  Experimenta ciclos de respiración guiada interactiva y estimuladores cerebrales como el "Spiritual Jackpot" para consolidar tu enfoque.
                </p>
              </div>
              <div className="pt-6 flex items-center gap-1.5 text-primary dark:text-accent-gold text-xs font-bold">
                Iniciar alineación <IconArrowRight size={12} />
              </div>
            </div>

          </div>
        </div>
      </section>

      {/* SECCIÓN INTERMEZZO: CONEXIÓN HUMANA & TECNOLOGÍA */}
      <section className="py-24 border-t border-border-primary dark:border-white/5 relative z-10 transition-colors">
        <div className="max-w-7xl mx-auto px-6">
          <div className="grid md:grid-cols-12 gap-12 items-center">
            
            {/* Columna Izquierda: Imagen de interacción acogedora */}
            <div className="md:col-span-6 flex justify-center">
              <div className="relative rounded-3xl overflow-hidden border border-border-primary dark:border-white/10 shadow-2xl group max-w-md w-full">
                <img 
                  src={APP_INTERACTION_IMAGE_URL} 
                  alt="Uso de Manifest AI en un ambiente relajante" 
                  className="w-full h-[380px] object-cover transition-transform duration-700 group-hover:scale-103"
                />
                <div className="absolute inset-0 border border-white/10 rounded-3xl pointer-events-none"></div>
              </div>
            </div>

            {/* Columna Derecha: Copiado de Valor */}
            <div className="md:col-span-6 space-y-6 text-left">
              <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-accent-purple/10 border border-accent-purple/20 text-xs font-bold text-accent-purple">
                <IconBrain size={14} /> Reprogramación Diaria
              </div>
              <h3 className="text-3xl font-black text-text-primary tracking-tight">
                Diseñado para acompañarte en tus momentos de calma
              </h3>
              <p className="text-text-secondary text-base leading-relaxed">
                Manifestar no es solo desear; es entrenar al cerebro para sintonizar con la gratitud y la abundancia en tu rutina diaria. Abre Manifiestas AI al despertar o antes de dormir, y deja que tu mentor digital limpie el ruido mental del día de forma guiada y sin complicaciones.
              </p>
              
              <div className="space-y-4 pt-2">
                <div className="flex items-start gap-3">
                  <div className="w-6 h-6 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold text-xs shrink-0 mt-0.5">✓</div>
                  <div>
                    <h4 className="font-bold text-text-primary text-sm">Práctica matutina de 3 minutos</h4>
                    <p className="text-xs text-text-secondary">Establece tu intención y genera tus afirmaciones diarias con un toque rápido en la pantalla.</p>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <div className="w-6 h-6 rounded-full bg-primary/10 text-primary flex items-center justify-center font-bold text-xs shrink-0 mt-0.5">✓</div>
                  <div>
                    <h4 className="font-bold text-text-primary text-sm">Reflexión nocturna de gratitud</h4>
                    <p className="text-xs text-text-secondary">Guarda tus lecciones en el diario digital y sella tu vibración mental con emociones de paz.</p>
                  </div>
                </div>
              </div>
            </div>

          </div>
        </div>
      </section>

      {/* DEMO INTERACTIVA */}
      <section id="demo" className="py-24 bg-bg-primary dark:bg-gradient-to-b dark:from-[#080414] dark:to-[#0c0620] relative z-10 transition-colors border-t border-border-primary dark:border-white/5">
        
        {/* Glow de la sección */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-accent-purple/3 dark:bg-accent-purple/5 rounded-full blur-[150px] pointer-events-none"></div>
        
        <div className="max-w-7xl mx-auto px-6">
          <div className="text-center max-w-2xl mx-auto space-y-4 mb-16">
            <p className="text-3xl sm:text-4xl font-black text-text-primary tracking-tight">Siente el poder de Manifiestas AI</p>
            <p className="text-text-secondary">Prueba nuestras dos herramientas principales directamente en la landing page.</p>
          </div>

          <div className="grid lg:grid-cols-12 gap-12 items-start">
            
            {/* WIDGET 1: SIMULADOR INTERACTIVO DEL TRIÁNGULO DE MANIFESTACIÓN */}
            <div className="lg:col-span-6 space-y-6">
              <div className="glass-card rounded-3xl p-6 md:p-8 space-y-6 shadow-xl relative overflow-hidden flex flex-col justify-between min-h-[430px]">
                <div className="absolute -top-10 -right-10 w-32 h-32 bg-accent-purple/5 dark:bg-accent-purple/10 rounded-full blur-2xl pointer-events-none"></div>
                
                <h3 className="text-lg font-bold text-text-primary flex items-center gap-2">
                  <span className="text-accent-purple">🔺</span> Prueba el Triángulo de Manifestación
                </h3>

                <div className="grid grid-cols-1 sm:grid-cols-12 gap-6 items-center flex-1">
                  
                  {/* Triángulo SVG */}
                  <div className="sm:col-span-5 flex justify-center">
                    <svg className="w-40 h-36 drop-shadow-[0_0_12px_rgba(99,102,241,0.25)] select-none" viewBox="0 0 200 170">
                      <defs>
                        <filter id="landing-glow" x="-20%" y="-20%" width="140%" height="140%">
                          <feGaussianBlur stdDeviation="4" result="blur" />
                          <feMerge>
                            <feMergeNode in="blur" />
                            <feMergeNode in="SourceGraphic" />
                          </feMerge>
                        </filter>
                        <linearGradient id="landing-loading-grad" x1="0%" y1="0%" x2="100%" y2="100%">
                          <stop offset="0%" stopColor="#6366f1" />
                          <stop offset="50%" stopColor="#ec4899" />
                          <stop offset="100%" stopColor="#f59e0b" />
                        </linearGradient>
                      </defs>

                      {/* Láser de carga */}
                      {landingGenerating && (
                        <motion.polygon 
                          points="100,25 35,145 165,145" 
                          fill="rgba(245,158,11,0.03)"
                          stroke="url(#landing-loading-grad)"
                          strokeWidth="3.5"
                          animate={{ 
                            strokeDashoffset: [0, 400],
                            opacity: [0.4, 0.9, 0.4]
                          }}
                          style={{ 
                            strokeDasharray: "10, 20", 
                            filter: "drop-shadow(0 0 6px rgba(236,72,153,0.6))" 
                          }}
                          transition={{ 
                            duration: 3, 
                            repeat: Infinity, 
                            ease: "linear" 
                          }}
                        />
                      )}

                      {/* Líneas */}
                      <line 
                        x1={100} y1={25} x2={35} y2={145} 
                        stroke={(!!landingDesire.trim() || landingStep >= 2) ? "#818cf8" : "rgba(255, 255, 255, 0.1)"}
                        strokeWidth="2.5"
                        style={{
                          filter: (!!landingDesire.trim() || landingStep >= 2) ? 'url(#landing-glow)' : 'none'
                        }}
                      />
                      <line 
                        x1={35} y1={145} x2={165} y2={145.1} 
                        stroke={(!!landingEmotion.trim() || landingStep >= 3) ? "#f472b6" : "rgba(255, 255, 255, 0.1)"}
                        strokeWidth="2.5"
                        style={{
                          filter: (!!landingEmotion.trim() || landingStep >= 3) ? 'url(#landing-glow)' : 'none'
                        }}
                      />
                      <line 
                        x1={165} y1={145} x2={100} y2={25} 
                        stroke={(!!landingAction.trim() || landingStep >= 4) ? "#fbbf24" : "rgba(255, 255, 255, 0.1)"}
                        strokeWidth="2.5"
                        style={{
                          filter: (!!landingAction.trim() || landingStep >= 4) ? 'url(#landing-glow)' : 'none'
                        }}
                      />

                      {/* Nodos */}
                      {/* Vértice 1: Deseo */}
                      <circle 
                        cx={100} cy={25} r={9} 
                        className={
                          landingStep === 1 ? "fill-indigo-500 stroke-indigo-300 stroke-[2px] animate-pulse" : 
                          landingDesire.trim() ? "fill-indigo-500 stroke-indigo-400 stroke-1" : "fill-white/10 stroke-white/20"
                        }
                        style={landingStep >= 1 || landingDesire.trim() ? { filter: 'url(#landing-glow)' } : {}}
                      />

                      {/* Vértice 2: Emoción */}
                      <circle 
                        cx={35} cy={145} r={9} 
                        className={
                          landingStep === 2 ? "fill-pink-500 stroke-pink-300 stroke-[2px] animate-pulse" : 
                          landingEmotion.trim() ? "fill-pink-500 stroke-pink-400 stroke-1" : "fill-white/10 stroke-white/20"
                        }
                        style={landingStep >= 2 || landingEmotion.trim() ? { filter: 'url(#landing-glow)' } : {}}
                      />

                      {/* Vértice 3: Acción */}
                      <circle 
                        cx={165} cy={145} r={9} 
                        className={
                          landingStep === 3 ? "fill-amber-500 stroke-amber-300 stroke-[2px] animate-pulse" : 
                          landingAction.trim() ? "fill-amber-500 stroke-amber-400 stroke-1" : "fill-white/10 stroke-white/20"
                        }
                        style={landingStep >= 3 || landingAction.trim() ? { filter: 'url(#landing-glow)' } : {}}
                      />
                    </svg>
                  </div>

                  {/* Formulario */}
                  <div className="sm:col-span-7 flex flex-col justify-center min-h-[220px]">
                    <AnimatePresence mode="wait">
                      {/* PASO 1: DESEO */}
                      {landingStep === 1 && (
                        <motion.div
                          key="l-step1"
                          initial={{ opacity: 0, x: 10 }}
                          animate={{ opacity: 1, x: 0 }}
                          exit={{ opacity: 0, x: -10 }}
                          className="space-y-3"
                        >
                          <div>
                            <span className="text-[9px] font-black text-indigo-400 dark:text-indigo-300 uppercase tracking-widest block mb-1">Paso 1: Deseo</span>
                            <h4 className="text-xs font-bold text-text-primary dark:text-white">¿Qué quieres manifestar hoy?</h4>
                          </div>
                          <textarea
                            value={landingDesire}
                            onChange={(e) => setLandingDesire(e.target.value)}
                            placeholder="Ej. Saldo de $5,000 en mi cuenta bancaria o un nuevo cliente pro..."
                            className="w-full bg-bg-secondary dark:bg-slate-900/60 border border-border-primary dark:border-white/10 rounded-xl p-3 text-xs text-text-primary dark:text-white outline-none focus:border-indigo-500 transition-colors h-16 resize-none leading-relaxed"
                          />
                          <button
                            disabled={!landingDesire.trim()}
                            onClick={() => setLandingStep(2)}
                            className="w-full py-2 bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs uppercase tracking-wider rounded-xl transition-all disabled:opacity-50"
                          >
                            Siguiente Vértice
                          </button>
                        </motion.div>
                      )}

                      {/* PASO 2: EMOCIÓN */}
                      {landingStep === 2 && (
                        <motion.div
                          key="l-step2"
                          initial={{ opacity: 0, x: 10 }}
                          animate={{ opacity: 1, x: 0 }}
                          exit={{ opacity: 0, x: -10 }}
                          className="space-y-3"
                        >
                          <div>
                            <span className="text-[9px] font-black text-pink-400 dark:text-pink-300 uppercase tracking-widest block mb-0.5">Paso 2: Emoción</span>
                            <h4 className="text-xs font-bold text-text-primary dark:text-white">¿Cómo te sentirías al lograrlo?</h4>
                          </div>
                          <textarea
                            value={landingEmotion}
                            onChange={(e) => setLandingEmotion(e.target.value)}
                            placeholder="Ej. Libre, empoderada, sumamente agradecida y en paz..."
                            className="w-full bg-bg-secondary dark:bg-slate-900/60 border border-border-primary dark:border-white/10 rounded-xl p-3 text-xs text-text-primary dark:text-white outline-none focus:border-pink-500 transition-colors h-14 resize-none leading-relaxed"
                          />
                          <div className="flex flex-wrap gap-1.5 justify-center">
                            {['Gratitud 💖', 'Libertad 🦋', 'Paz 🕊️', 'Poder 💪'].map((chip) => (
                              <button
                                key={chip}
                                type="button"
                                onClick={() => {
                                  const clean = chip.split(' ')[0];
                                  if (!landingEmotion.trim()) {
                                    setLandingEmotion(clean);
                                  } else {
                                    setLandingEmotion(prev => prev.includes(clean) ? prev : `${prev}, ${clean}`);
                                  }
                                }}
                                className="px-2 py-1 rounded-full bg-white/5 hover:bg-pink-500/10 border border-white/10 text-[10px] text-text-secondary hover:text-pink-400 transition-all"
                              >
                                {chip}
                              </button>
                            ))}
                          </div>
                          <div className="flex gap-2">
                            <button
                              onClick={() => setLandingStep(1)}
                              className="flex-1 py-2 bg-white/5 border border-white/10 text-text-primary dark:text-slate-200 text-xs font-bold uppercase rounded-xl hover:bg-white/10"
                            >
                              Atrás
                            </button>
                            <button
                              disabled={!landingEmotion.trim()}
                              onClick={() => setLandingStep(3)}
                              className="flex-1 py-2 bg-pink-600 hover:bg-pink-500 text-white font-bold text-xs uppercase tracking-wider rounded-xl transition-all disabled:opacity-50"
                            >
                              Siguiente
                            </button>
                          </div>
                        </motion.div>
                      )}

                      {/* PASO 3: ACCIÓN */}
                      {landingStep === 3 && (
                        <motion.div
                          key="l-step3"
                          initial={{ opacity: 0, x: 10 }}
                          animate={{ opacity: 1, x: 0 }}
                          exit={{ opacity: 0, x: -10 }}
                          className="space-y-3"
                        >
                          <div>
                            <span className="text-[9px] font-black text-amber-400 dark:text-amber-300 uppercase tracking-widest block mb-0.5">Paso 3: Acción</span>
                            <h4 className="text-xs font-bold text-text-primary dark:text-white">¿Qué paso físico darás hoy?</h4>
                          </div>
                          <textarea
                            value={landingAction}
                            onChange={(e) => setLandingAction(e.target.value)}
                            placeholder="Ej. Registrar mi dominio o enviar dos correos importantes..."
                            className="w-full bg-bg-secondary dark:bg-slate-900/60 border border-border-primary dark:border-white/10 rounded-xl p-3 text-xs text-text-primary dark:text-white outline-none focus:border-amber-500 transition-colors h-16 resize-none leading-relaxed"
                          />
                          <div className="flex gap-2">
                            <button
                              disabled={landingGenerating}
                              onClick={() => setLandingStep(2)}
                              className="flex-1 py-2 bg-white/5 border border-white/10 text-text-primary dark:text-slate-200 text-xs font-bold uppercase rounded-xl hover:bg-white/10"
                            >
                              Atrás
                            </button>
                            <button
                              disabled={!landingAction.trim() || landingGenerating}
                              onClick={handleActivateLandingTriangle}
                              className="flex-1 py-2 bg-gradient-to-r from-amber-500 to-amber-600 hover:from-amber-400 hover:to-amber-500 text-white font-bold text-xs uppercase tracking-wider rounded-xl transition-all disabled:opacity-50 flex items-center justify-center gap-1 shadow-md shadow-amber-500/10"
                            >
                              {landingGenerating ? (
                                <IconLoader2 size={12} className="animate-spin" />
                              ) : (
                                <>Activar Triángulo 🔺</>
                              )}
                            </button>
                          </div>
                        </motion.div>
                      )}

                      {/* PASO 4: RESULTADO AFIRMACIÓN Y GOAL */}
                      {landingStep === 4 && (
                        <motion.div
                          key="l-step4"
                          initial={{ opacity: 0, scale: 0.95 }}
                          animate={{ opacity: 1, scale: 1 }}
                          className="space-y-3.5"
                        >
                          <div className="text-center">
                            <span className="text-xs">✨ Triángulo Completado</span>
                            <div className="bg-white/5 border border-white/10 rounded-xl p-3 text-[11px] font-bold text-accent-gold italic leading-normal text-left mt-1.5 relative shadow-inner">
                              "{landingAffirmation}"
                            </div>
                          </div>

                          <div className="bg-[#534AB7]/5 border border-[#534AB7]/10 p-2.5 rounded-xl text-left flex items-start gap-2 shadow-inner">
                            <span className="text-lg">🎯</span>
                            <div>
                              <span className="text-[8px] font-black text-[#534AB7] dark:text-violet-300 uppercase tracking-widest block leading-tight">Meta de Acción Programada</span>
                              <h5 className="text-[10px] font-bold text-text-primary dark:text-white leading-snug">
                                Acción Inspirada: {landingAction}
                              </h5>
                              <p className="text-[8.5px] text-text-secondary/80 leading-normal">
                                En la App real, esta meta se integra con tu agenda física diaria por 1 día para concretar tu manifestación hoy.
                              </p>
                            </div>
                          </div>

                          <div className="flex gap-2">
                            <button
                              onClick={() => {
                                navigator.clipboard.writeText(landingAffirmation);
                                setLandingCopied(true);
                                setTimeout(() => setLandingCopied(false), 2000);
                              }}
                              className="flex-1 py-2 bg-white/5 hover:bg-white/10 border border-white/10 text-[10px] font-bold uppercase rounded-xl text-text-primary dark:text-slate-200"
                            >
                              {landingCopied ? "✓ Copiado" : "Copiar"}
                            </button>
                            <Link
                              href="/app"
                              className="flex-1 py-2 bg-gradient-to-r from-primary to-accent-purple hover:opacity-90 text-[10px] font-bold uppercase rounded-xl text-white text-center flex items-center justify-center gap-1 shadow-md"
                            >
                              Registrar Gratis 🚀
                            </Link>
                          </div>
                          
                          <button
                            onClick={() => {
                              setLandingStep(1);
                              setLandingDesire("");
                              setLandingEmotion("");
                              setLandingAction("");
                              setLandingAffirmation("");
                            }}
                            className="w-full text-center text-[9px] font-bold text-text-secondary hover:text-text-primary underline cursor-pointer"
                          >
                            Hacer otro triángulo
                          </button>
                        </motion.div>
                      )}
                    </AnimatePresence>
                  </div>

                </div>

              </div>
            </div>
            
            {/* WIDGET 2: CHAT CON EL MENTOR SIMULADO */}
            <div className="lg:col-span-6 space-y-6">
              <div className="glass-card rounded-3xl p-6 md:p-8 space-y-6 shadow-xl relative flex flex-col h-[415px]">
                <h3 className="text-lg font-bold text-text-primary flex items-center gap-2 shrink-0">
                  <span className="text-primary">🤖</span> Prueba el Coach Cognitivo
                </h3>

                {/* Area del Chat */}
                <div className="flex-1 bg-bg-secondary dark:bg-slate-950/50 border border-border-primary dark:border-white/5 rounded-2xl p-4 overflow-y-auto space-y-3 flex flex-col no-scrollbar shadow-inner">
                  {chatMessages.map((msg, i) => (
                    <div
                      key={i}
                      className={`max-w-[85%] p-3.5 rounded-2xl text-xs leading-relaxed ${
                        msg.sender === "ai"
                          ? "bg-bg-primary dark:bg-white/5 border border-border-primary dark:border-white/5 text-text-primary dark:text-slate-200 rounded-bl-none self-start shadow-sm"
                          : "bg-primary text-white rounded-br-none self-end"
                      }`}
                    >
                      {msg.text}
                    </div>
                  ))}
                  {isTyping && (
                    <div className="bg-bg-primary dark:bg-white/5 border border-border-primary dark:border-white/5 px-3.5 py-2.5 rounded-2xl rounded-bl-none self-start flex gap-1 items-center shadow-sm">
                      <div className="w-1.5 h-1.5 bg-text-secondary/60 rounded-full animate-bounce" style={{ animationDelay: "0ms" }} />
                      <div className="w-1.5 h-1.5 bg-text-secondary/60 rounded-full animate-bounce" style={{ animationDelay: "150ms" }} />
                      <div className="w-1.5 h-1.5 bg-text-secondary/60 rounded-full animate-bounce" style={{ animationDelay: "300ms" }} />
                    </div>
                  )}
                </div>

                {/* Opciones Preestablecidas */}
                <div className="space-y-2 shrink-0">
                  <div className="text-[10px] text-text-secondary dark:text-slate-500 font-bold tracking-wider uppercase mb-1">
                    Selecciona una respuesta para simular:
                  </div>
                  <div className="flex flex-col gap-2">
                    <button
                      onClick={() => handleChatOption(
                        "💰 Quiero manifestar dinero",
                        "Excelente decisión. Para atraer prosperidad financiera, define una cantidad y sintoniza con el agradecimiento. ¿Cuánto quieres manifestar hoy?"
                      )}
                      disabled={isTyping}
                      className="w-full text-left py-2 px-3 bg-bg-primary dark:bg-white/5 hover:bg-bg-secondary dark:hover:bg-white/10 rounded-xl text-xs text-text-primary dark:text-slate-300 border border-border-primary dark:border-white/5 transition-all disabled:opacity-50 shadow-sm"
                    >
                      💰 Quiero manifestar dinero
                    </button>
                    <button
                      onClick={() => handleChatOption(
                        "💗 Deseo atraer mi amor ideal",
                        "El amor surge de adentro. Escribe las emociones que quieres sentir (seguridad, complicidad, pasión) y prepárate para recibirlas."
                      )}
                      disabled={isTyping}
                      className="w-full text-left py-2 px-3 bg-bg-primary dark:bg-white/5 hover:bg-bg-secondary dark:hover:bg-white/10 rounded-xl text-xs text-text-primary dark:text-slate-300 border border-border-primary dark:border-white/5 transition-all disabled:opacity-50 shadow-sm"
                    >
                      💗 Deseo atraer mi amor ideal
                    </button>
                  </div>
                </div>
              </div>
            </div>

          </div>

          {/* WIDGET 3: PREVIO DEL JACKPOT DE ABUNDANCIA */}
          <div className="mt-12 text-center">
            <div className="glass-card rounded-3xl p-8 max-w-4xl mx-auto relative overflow-hidden">
              
              {/* Estallido de partículas dorado (Siempre usa overlay oscuro por ser efecto teatral) */}
              <AnimatePresence>
                {showJackpot && (
                  <motion.div 
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    className="absolute inset-0 bg-slate-950/95 backdrop-blur-[2px] z-20 flex flex-col items-center justify-center"
                  >
                    {/* Estallido central */}
                    <motion.div
                      initial={{ scale: 0.2, opacity: 1 }}
                      animate={{ scale: 3, opacity: 0 }}
                      transition={{ duration: 1.2, ease: "easeOut" }}
                      className="absolute w-40 h-40 rounded-full bg-yellow-400 blur-xl"
                    />

                    {/* Partículas Cayendo */}
                    {[...Array(15)].map((_, idx) => (
                      <motion.div
                        key={idx}
                        initial={{ y: -80, x: Math.random() * 400 - 200, opacity: 0 }}
                        animate={{ y: 250, x: (Math.random() * 400 - 200), opacity: [0, 1, 1, 0] }}
                        transition={{ duration: 1.5 + Math.random() * 1.5, ease: "linear", repeat: Infinity }}
                        className="absolute text-yellow-400 text-lg"
                      >
                        ✨
                      </motion.div>
                    ))}

                    <div className="relative text-center space-y-4 px-4">
                      <div className="w-14 h-14 bg-yellow-400/20 border border-yellow-400/50 rounded-full flex items-center justify-center mx-auto shadow-[0_0_30px_rgba(250,204,21,0.3)] animate-bounce">
                        <IconCheck size={28} className="text-yellow-400" />
                      </div>
                      <h4 className="text-yellow-400 text-sm font-bold tracking-widest uppercase">Frecuencia Financiera Sintonizada</h4>
                      <div className="text-5xl font-black text-white">
                        <span className="text-yellow-400">$</span>{displayJackpotAmount.toLocaleString()}
                      </div>
                      <p className="text-slate-300 text-xs max-w-sm mx-auto leading-relaxed">
                        ¡Simulación completada! En la aplicación real, esta pantalla estimula tu mente de forma visual y auditiva tras sesiones completas.
                      </p>
                      <button
                        onClick={() => setShowJackpot(false)}
                        className="px-5 py-2 bg-yellow-400/10 hover:bg-yellow-400/20 text-yellow-400 border border-yellow-400/30 rounded-full text-xs uppercase font-bold tracking-wider transition-colors"
                      >
                        Cerrar Simulación
                      </button>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>

              <div className="grid md:grid-cols-12 gap-8 items-center">
                <div className="md:col-span-7 text-left space-y-4">
                  <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-yellow-400/10 border border-yellow-400/20 text-xs font-bold text-accent-gold">
                    <IconCoins size={14} /> Frecuencia de Abundancia
                  </div>
                  <h3 className="text-2xl font-bold text-text-primary">El "Spiritual Jackpot" Estimulador</h3>
                  <p className="text-text-secondary text-sm leading-relaxed">
                    Siente la emoción del éxito financiero. Introduce una meta cuantitativa en dólares para probar nuestro simulador cerebral de manifestación de dinero.
                  </p>
                  
                  <div className="flex gap-2 max-w-xs pt-2">
                    <input 
                      type="text" 
                      value={jackpotAmount}
                      onChange={(e) => setJackpotAmount(e.target.value)}
                      placeholder="10000"
                      className="px-4 py-2.5 bg-bg-secondary dark:bg-slate-950/70 border border-border-secondary dark:border-white/10 rounded-xl text-sm font-bold text-text-primary dark:text-white text-center focus:border-primary dark:focus:border-accent-gold focus:outline-none w-32"
                    />
                    <button
                      onClick={startJackpotSimulation}
                      className="px-4 py-2.5 bg-primary hover:bg-primary-dark dark:bg-accent-gold dark:hover:bg-yellow-500 text-white dark:text-slate-950 font-bold text-xs uppercase tracking-wider rounded-xl transition-all flex items-center gap-1 shadow-md shadow-primary/10 dark:shadow-accent-gold/20"
                    >
                      Alinear Dinero <IconPlayerPlayFilled size={10} />
                    </button>
                  </div>
                </div>

                <div className="md:col-span-5 relative flex justify-center">
                  {/* Visual del Jackpot + Imagen humana de éxito */}
                  <div className="relative w-64 h-80 rounded-3xl overflow-hidden border border-border-primary dark:border-white/10 shadow-xl group">
                    <img 
                      src={SUCCESS_GRATITUDE_IMAGE_URL} 
                      alt="Persona exitosa agradeciendo" 
                      className="absolute inset-0 w-full h-full object-cover transition-transform duration-700 group-hover:scale-105"
                    />
                    {/* Overlay gradiente para el texto */}
                    <div className="absolute inset-0 bg-gradient-to-t from-slate-950/95 via-slate-950/30 to-transparent"></div>
                    
                    <div className="absolute bottom-0 inset-x-0 p-5 text-center flex flex-col items-center justify-end h-full">
                      <div className="w-10 h-10 bg-yellow-400/20 border border-yellow-400/40 rounded-full flex items-center justify-center mb-2 animate-bounce">
                        <IconCoins size={20} className="text-accent-gold" />
                      </div>
                      <div className="text-[10px] text-yellow-400 font-bold uppercase tracking-widest">Sintonización Activa</div>
                      <div className="text-2xl font-black text-white mt-1">
                        ${parseInt(jackpotAmount.replace(/,/g, "") || "10000").toLocaleString()}
                      </div>
                      <p className="text-[10px] text-slate-300 mt-1 max-w-[200px]">El universo refleja tu gratitud.</p>
                    </div>
                  </div>
                </div>
              </div>

            </div>
          </div>

        </div>
      </section>

      {/* CÓMO FUNCIONA */}
      <section id="how-it-works" className="py-24 border-t border-border-primary dark:border-white/5 relative z-10">
        <div className="max-w-7xl mx-auto px-6 text-center">
          
          <div className="max-w-2xl mx-auto space-y-4 mb-20">
            <h2 className="text-xs font-bold text-primary dark:text-accent-gold uppercase tracking-widest">Método Cuántico</h2>
            <p className="text-3xl sm:text-4xl font-black text-text-primary tracking-tight">Tu Ruta de Reprogramación en 3 Pasos</p>
            <p className="text-text-secondary">Diseñado científicamente para integrar nuevos hábitos y creencias de éxito.</p>
          </div>

          <div className="grid md:grid-cols-3 gap-12 text-left relative">
            {/* Línea conectora */}
            <div className="hidden md:block absolute top-16 left-[15%] right-[15%] h-0.5 bg-gradient-to-r from-primary/20 to-accent-gold/20 z-0"></div>
            
            {/* Paso 1 */}
            <div className="space-y-4 relative z-10">
              <div className="w-12 h-12 rounded-full bg-bg-primary dark:bg-slate-900 border border-primary text-primary dark:text-white flex items-center justify-center font-bold text-lg shadow-md">
                1
              </div>
              <h3 className="text-lg font-bold text-text-primary">Define tu Intención</h3>
              <p className="text-text-secondary text-sm leading-relaxed">
                Plantea tus objetivos financieros, personales o de salud. La claridad en el subconsciente es la mitad del camino.
              </p>
            </div>

            {/* Paso 2 */}
            <div className="space-y-4 relative z-10">
              <div className="w-12 h-12 rounded-full bg-bg-primary dark:bg-slate-900 border border-accent-purple text-accent-purple dark:text-white flex items-center justify-center font-bold text-lg shadow-md">
                2
              </div>
              <h3 className="text-lg font-bold text-text-primary">Reprograma con tu Coach</h3>
              <p className="text-text-secondary text-sm leading-relaxed">
                Interactúa con la IA para identificar bloqueos internos y generar afirmaciones potentes basadas en tu psicología.
              </p>
            </div>

            {/* Paso 3 */}
            <div className="space-y-4 relative z-10">
              <div className="w-12 h-12 rounded-full bg-bg-primary dark:bg-slate-900 border border-accent-gold text-accent-gold dark:text-white flex items-center justify-center font-bold text-lg shadow-md">
                3
              </div>
              <h3 className="text-lg font-bold text-text-primary">Sintoniza la Frecuencia</h3>
              <p className="text-text-secondary text-sm leading-relaxed">
                Visualiza tus logros diariamente con estímulos de dopamina para acostumbrar a tu mente al sentimiento del éxito.
              </p>
            </div>

          </div>
        </div>
      </section>

      {/* ===== TESTIMONIOS ===== */}
      <section id="testimonios" className="py-24 border-t border-border-primary dark:border-white/5 relative z-10 overflow-hidden transition-colors">
        <div className="absolute inset-0 bg-gradient-to-b from-primary/5 via-transparent to-accent-gold/5 pointer-events-none" />
        <div className="max-w-7xl mx-auto px-6 relative">
          <div className="text-center space-y-4 mb-16">
            <h2 className="text-xs font-bold text-primary dark:text-accent-gold uppercase tracking-widest">Ellas Ya Lo Viven</h2>
            <p className="text-3xl sm:text-4xl font-black text-text-primary dark:text-white tracking-tight">
              Vidas que se están{" "}
              <span className="bg-gradient-to-r from-primary to-accent-gold bg-clip-text text-transparent">transformando</span>
            </p>
            <p className="text-text-secondary max-w-xl mx-auto">
              Más de 2,000 mujeres ya están alineando su frecuencia y manifestando sus deseos con Manifiestas AI.
            </p>
          </div>

          <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {[
              { name: "Valeria M.", location: "Ciudad de México", avatar: "💜", text: "En menos de 30 días recibí una oferta de trabajo con el salario exacto que había declarado en mis afirmaciones. Esto no es coincidencia.", tag: "Manifestó su trabajo ideal" },
              { name: "Daniela R.", location: "Bogotá, Colombia", avatar: "✨", text: "El coach de IA entiende exactamente en qué frecuencia estoy. Nunca había tenido un espacio tan personal y sin juicios para hablar de mis sueños.", tag: "Amor propio y claridad" },
              { name: "Sofía L.", location: "Buenos Aires, Argentina", avatar: "🌟", text: "Empecé la visualización cuántica antes de dormir. En 3 semanas, manifesté el apartamento al precio que pedí. Sigo sin creerlo.", tag: "Manifestó su hogar ideal" },
              { name: "Camila T.", location: "Lima, Perú", avatar: "🔮", text: "Las afirmaciones personalizadas son otro nivel. No son frases genéricas — el sistema las adapta a mis bloqueos específicos. Realmente me conoce.", tag: "Reprogramación de creencias" },
              { name: "Andrea P.", location: "Santiago, Chile", avatar: "💎", text: "Hoy tengo 3 fuentes de ingreso que no tenía hace 4 meses. La consistencia con las afirmaciones diarias lo cambió todo.", tag: "Abundancia financiera" },
              { name: "Isabella F.", location: "Medellín, Colombia", avatar: "🌙", text: "El coach me ayudó a identificar el bloqueo que me saboteaba en el amor. Dos meses después conocí a la persona que buscaba.", tag: "Manifestó su relación ideal" },
            ].map(({ name, location, avatar, text, tag }) => (
              <div key={name} className="glass-card p-7 rounded-3xl flex flex-col gap-4 hover:border-primary/30 hover:-translate-y-1 transition-all duration-300">
                <div className="flex gap-0.5">
                  {Array.from({ length: 5 }).map((_, i) => (
                    <span key={i} className="text-accent-gold text-sm">★</span>
                  ))}
                </div>
                <p className="text-text-secondary dark:text-slate-300 text-sm leading-relaxed flex-1 italic">&ldquo;{text}&rdquo;</p>
                <span className="self-start px-3 py-1 rounded-full bg-primary/10 border border-primary/20 text-primary dark:text-violet-300 text-[11px] font-semibold">✦ {tag}</span>
                <div className="flex items-center gap-3 pt-1 border-t border-border-primary dark:border-white/5">
                  <div className="w-9 h-9 rounded-full bg-gradient-to-br from-primary/20 to-accent-gold/20 flex items-center justify-center text-lg shrink-0">{avatar}</div>
                  <div>
                    <p className="text-sm font-bold text-text-primary dark:text-white">{name}</p>
                    <p className="text-[11px] text-text-secondary">{location}</p>
                  </div>
                </div>
              </div>
            ))}
          </div>

          <div className="mt-16 flex flex-col sm:flex-row items-center justify-center gap-8 sm:gap-16 text-center">
            {[
              { value: "2,300+", label: "Usuarias activas" },
              { value: "98%", label: "Satisfacción reportada" },
              { value: "4.9 / 5", label: "Calificación promedio" },
            ].map(({ value, label }) => (
              <div key={label}>
                <p className="text-3xl sm:text-4xl font-black bg-gradient-to-r from-primary to-accent-gold bg-clip-text text-transparent">{value}</p>
                <p className="text-sm text-text-secondary mt-1">{label}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ===== PRECIOS ===== */}
      <section id="precios" className="py-24 border-t border-border-primary dark:border-white/5 bg-bg-primary/50 dark:bg-slate-950/30 relative z-10 transition-colors">
        <div className="max-w-5xl mx-auto px-6">
          <div className="text-center space-y-4 mb-16">
            <h2 className="text-xs font-bold text-primary dark:text-accent-gold uppercase tracking-widest">Planes</h2>
            <p className="text-3xl sm:text-4xl font-black text-text-primary dark:text-white tracking-tight">Empieza gratis. Eleva tu frecuencia.</p>
            <p className="text-text-secondary max-w-xl mx-auto">Comienza sin costo. Cuando estés lista para ir más profundo, el plan Pro te espera.</p>
          </div>

          <div className="grid md:grid-cols-2 gap-8 max-w-3xl mx-auto">
            {/* Plan Gratuito */}
            <div className="glass-card p-8 rounded-3xl flex flex-col gap-6">
              <div>
                <p className="text-xs font-bold text-text-secondary uppercase tracking-widest mb-2">Gratis para siempre</p>
                <p className="text-4xl font-black text-text-primary dark:text-white">$0</p>
                <p className="text-text-secondary text-sm mt-1">Sin tarjeta de crédito</p>
              </div>
              <ul className="space-y-3 flex-1">
                {["Coach de IA — 5 mensajes/día", "Diario de gratitud (hasta 3 entradas)", "Triángulo de Manifestación básico", "Visualizaciones guiadas", "Seguimiento de 1 meta activa"].map((item) => (
                  <li key={item} className="flex items-start gap-2.5 text-sm text-text-secondary">
                    <span className="text-green-500 mt-0.5 shrink-0">✓</span>{item}
                  </li>
                ))}
              </ul>
              <Link href="/app" className="w-full py-3.5 rounded-xl border-2 border-primary/40 text-primary dark:text-violet-300 font-bold text-center hover:bg-primary/5 transition-all">
                Empezar Gratis
              </Link>
            </div>

            {/* Plan Pro */}
            <div className="relative rounded-3xl p-[1.5px] bg-gradient-to-br from-primary via-accent-purple to-accent-gold shadow-2xl shadow-primary/20">
              <div className="absolute -top-3.5 left-1/2 -translate-x-1/2 px-4 py-1 rounded-full bg-gradient-to-r from-primary to-accent-gold text-white text-[11px] font-bold uppercase tracking-wider shadow-lg whitespace-nowrap">
                ✦ Más Popular
              </div>
              <div className="bg-bg-primary dark:bg-[#0c0721] rounded-[calc(1.5rem-1.5px)] p-8 flex flex-col gap-6 h-full">
                <div>
                  <p className="text-xs font-bold text-primary dark:text-accent-gold uppercase tracking-widest mb-2">Pro — Frecuencia Plena</p>
                  <div className="flex items-baseline gap-2">
                    <p className="text-4xl font-black text-text-primary dark:text-white">$9.99</p>
                    <p className="text-text-secondary text-sm">/ mes</p>
                  </div>
                  <p className="text-text-secondary text-sm mt-1">O $79.99/año — ahorra 33%</p>
                </div>
                <ul className="space-y-3 flex-1">
                  {["Coach de IA — mensajes ilimitados", "Triángulos de Manifestación ilimitados", "Retos de 30 Días con IA personalizados", "Diario de gratitud ilimitado", "Metas de Acción ilimitadas con avance por días", "Decretos de abundancia guardados (Mis Decretos 🔺)", "Visualizaciones cuánticas ilimitadas", "Gestión de facturación con Stripe"].map((item) => (
                    <li key={item} className="flex items-start gap-2.5 text-sm text-text-secondary dark:text-slate-300">
                      <span className="text-accent-gold mt-0.5 shrink-0">✦</span>{item}
                    </li>
                  ))}
                </ul>
                <Link href="/app" className="w-full py-3.5 rounded-xl bg-gradient-to-r from-primary to-accent-purple hover:opacity-90 text-white font-bold text-center transition-all shadow-lg shadow-primary/20">
                  Empezar con Pro — 7 días gratis
                </Link>
              </div>
            </div>
          </div>

          <p className="text-center text-sm text-text-secondary mt-10">
            🔒 Garantía de satisfacción de 7 días. Si no estás feliz, te devolvemos tu dinero sin preguntas.
          </p>
        </div>
      </section>

      {/* PREGUNTAS FRECUENTES (FAQs) */}
      <section id="faqs" className="py-24 bg-bg-primary/40 dark:bg-slate-950/20 border-t border-border-primary dark:border-white/5 relative z-10">

        <div className="max-w-4xl mx-auto px-6">
          <div className="text-center space-y-4 mb-16">
            <h2 className="text-xs font-bold text-primary dark:text-accent-gold uppercase tracking-widest">Preguntas Frecuentes</h2>
            <p className="text-3xl font-black text-text-primary tracking-tight">Resuelve tus dudas</p>
          </div>

          <div className="space-y-4">
            {faqs.map((faq, idx) => (
              <div 
                key={idx} 
                className="glass-card rounded-2xl overflow-hidden"
              >
                <button
                  onClick={() => setOpenFaq(openFaq === idx ? null : idx)}
                  className="w-full px-6 py-5 flex justify-between items-center text-left text-text-primary hover:bg-primary/5 transition-colors"
                >
                  <span className="font-bold text-sm sm:text-base">{faq.question}</span>
                  <motion.span
                    animate={{ rotate: openFaq === idx ? 180 : 0 }}
                    transition={{ duration: 0.2 }}
                    className="text-text-secondary shrink-0"
                  >
                    <IconChevronDown size={20} />
                  </motion.span>
                </button>
                
                <AnimatePresence initial={false}>
                  {openFaq === idx && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: "auto", opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.25, ease: "easeInOut" }}
                    >
                      <div className="px-6 pb-6 text-text-secondary text-xs sm:text-sm leading-relaxed border-t border-border-primary/50 dark:border-white/5 pt-4">
                        {faq.answer}
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            ))}
          </div>

        </div>
      </section>

      {/* FOOTER & FINAL CTA */}
      <section className="py-24 bg-bg-secondary dark:bg-[#05030d] border-t border-border-primary dark:border-white/5 text-center relative z-10 transition-colors">
        
        {/* Glow final */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[350px] h-[350px] bg-primary/5 rounded-full blur-[100px] pointer-events-none"></div>

        <div className="max-w-4xl mx-auto px-6 space-y-8">
          <h2 className="text-3xl sm:text-4xl lg:text-5xl font-black text-text-primary tracking-tight">
            ¿Listo para sintonizar tu mente con el éxito?
          </h2>
          <p className="text-text-secondary text-base max-w-xl mx-auto leading-relaxed">
            Únete hoy mismo a miles de personas reprogramando sus vidas. Tu camino cuántico hacia la abundancia comienza ahora.
          </p>
          
          <div className="pt-4">
            <Link
              href="/app"
              className="px-10 py-5 rounded-full bg-gradient-to-r from-primary to-accent-purple hover:scale-[1.03] transition-all text-white font-bold tracking-wide shadow-xl shadow-primary/20 inline-flex items-center gap-2"
            >
              Comenzar Mi Viaje Gratis <IconArrowRight size={20} />
            </Link>
          </div>

          <div className="pt-20 border-t border-border-primary dark:border-white/5 flex flex-col sm:flex-row justify-between items-center gap-4 text-xs text-text-secondary">
            <div className="flex items-center gap-2">
              <span className="text-accent-gold text-lg">✨</span>
              <span className="font-extrabold text-text-primary">MANIFIESTAS AI</span>
              <span>© {new Date().getFullYear()} Todos los derechos reservados.</span>
            </div>
            
            <div className="flex flex-wrap justify-center gap-6">
              <Link href="/terms" className="hover:text-primary dark:hover:text-white transition-colors">Términos de servicio</Link>
              <Link href="/privacy" className="hover:text-primary dark:hover:text-white transition-colors">Política de privacidad</Link>
              <Link href="/refunds" className="hover:text-primary dark:hover:text-white transition-colors">Política de reembolso</Link>
            </div>
          </div>
        </div>
      </section>

      {/* AVISO DE COOKIES INTERACTIVO */}
      <AnimatePresence>
        {showCookieBanner && (
          <motion.div
            initial={{ opacity: 0, y: 50, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 20, scale: 0.95 }}
            transition={{ duration: 0.3 }}
            className="fixed bottom-6 right-6 z-50 max-w-sm w-[calc(100vw-3rem)] glass-card rounded-3xl p-6 border border-white/10 dark:border-white/10 shadow-2xl backdrop-blur-xl flex flex-col gap-4 text-left"
          >
            <div className="flex items-start gap-3">
              <span className="text-2xl">🍪</span>
              <div className="space-y-1">
                <h4 className="text-xs font-black text-text-primary dark:text-white uppercase tracking-wider">Aviso de Cookies</h4>
                <p className="text-[11px] text-text-secondary leading-relaxed">
                  Utilizamos cookies esenciales y de análisis para garantizar la seguridad de tus pagos mediante Stripe y optimizar el rendimiento de la plataforma. Al continuar, aceptas nuestra <Link href="/privacy" className="underline hover:text-primary dark:hover:text-white">Política de Privacidad</Link>.
                </p>
              </div>
            </div>
            <div className="flex gap-2 justify-end">
              <button
                onClick={() => setShowCookieBanner(false)}
                className="px-3.5 py-1.5 rounded-lg bg-white/5 hover:bg-white/10 border border-white/10 text-[10px] font-bold text-text-secondary dark:text-slate-300 transition-colors uppercase tracking-wider cursor-pointer"
              >
                Rechazar
              </button>
              <button
                onClick={handleAcceptCookies}
                className="px-4 py-1.5 rounded-lg bg-gradient-to-r from-primary to-accent-purple hover:opacity-90 text-[10px] font-bold text-white transition-all uppercase tracking-wider shadow-md cursor-pointer"
              >
                Aceptar
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

    </div>
  );
}
