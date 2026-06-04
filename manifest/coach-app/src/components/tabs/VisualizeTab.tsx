"use client";

import React, { useState, useEffect } from 'react';
import { 
  IconPlayerPlayFilled, 
  IconArrowUpRight, 
  IconCurrencyDollar, 
  IconCheck, 
  IconX,
  IconHeart,
  IconRocket,
  IconSunset,
  IconSparkles,
  IconCalendar,
  IconTriangle,
  IconCopy,
  IconBookmark,
  IconLoader2,
  IconTarget
} from '@tabler/icons-react';
import { motion, AnimatePresence } from 'framer-motion';
import { twMerge } from 'tailwind-merge';
import { createClient } from '@/utils/supabase/client';

const areas = [
  { id: 'dinero', icon: '💰', label: 'Abundancia' },
  { id: 'amor', icon: '💗', label: 'Amor ideal' },
  { id: 'exito', icon: '🚀', label: 'Éxito' },
  { id: 'paz', icon: '🕊', label: 'Paz interior' },
];

export default function VisualizeTab() {
  // Estados: 'selection' | 'input' | 'meditation' | 'reward' | 'guided_session' | 'triangle_session'
  const [mode, setMode] = useState<'selection' | 'input' | 'meditation' | 'reward' | 'guided_session' | 'triangle_session'>('selection');
  const [selectedArea, setSelectedArea] = useState<string>('');
  const [amount, setAmount] = useState<string>('');
  const [intention, setIntention] = useState<string>('');
  const [timer, setTimer] = useState<number>(5); // 5 segundos para la demo
  const [displayAmount, setDisplayAmount] = useState(0);
  
  // Estado para la Sesión Guiada por Pasos:
  // 0: Respiración de Calma (12s)
  // 1: Selección de Enfoque (espera click)
  // 2: Visualización Guiada Activa (10s)
  // 3: Anclaje y Decreto de Cierre (6s)
  const [guidedStep, setGuidedStep] = useState<number>(0);

  const supabase = createClient();
  const [user, setUser] = useState<any>(null);
  const [savedTriangles, setSavedTriangles] = useState<any[]>([]);
  const [loadingTriangles, setLoadingTriangles] = useState<boolean>(true);

  // Estados para el Triángulo de Manifestación:
  const [triangleStep, setTriangleStep] = useState<number>(1);
  const [desire, setDesire] = useState<string>('');
  const [emotion, setEmotion] = useState<string>('');
  const [action, setAction] = useState<string>('');
  const [generatingTriangle, setGeneratingTriangle] = useState<boolean>(false);
  const [generatedAffirmation, setGeneratedAffirmation] = useState<string>('');
  const [savedSuccess, setSavedSuccess] = useState<boolean>(false);
  const [copied, setCopied] = useState<boolean>(false);

  useEffect(() => {
    const fetchUserAndTriangles = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        setUser(user);
        
        // Fetch saved triangles
        const { data, error } = await supabase
          .from('manifestation_triangles')
          .select('*')
          .order('created_at', { ascending: false });
          
        if (!error && data) {
          setSavedTriangles(data);
        }
      }
      setLoadingTriangles(false);
    };
    fetchUserAndTriangles();
  }, []);

  const handleDeleteTriangle = async (id: string) => {
    const confirmDelete = window.confirm("¿Estás seguro de que deseas eliminar este Triángulo de Manifestación?");
    if (!confirmDelete) return;
    
    try {
      const { error } = await supabase
        .from('manifestation_triangles')
        .delete()
        .eq('id', id);
        
      if (error) throw error;
      
      // Update list
      setSavedTriangles(prev => prev.filter(t => t.id !== id));
    } catch (err: any) {
      alert("Error al eliminar el triángulo: " + err.message);
    }
  };

  const handleSaveTriangle = async () => {
    if (!user) {
      alert("Debes iniciar sesión para guardar tus triángulos.");
      return;
    }
    
    try {
      // 1. Guardar el triángulo en la base de datos
      const { data, error } = await supabase
        .from('manifestation_triangles')
        .insert([
          {
            user_id: user.id,
            desire,
            emotion,
            action,
            affirmation: generatedAffirmation
          }
        ])
        .select()
        .single();
        
      if (error) throw error;
      
      // 2. Crear una micro-tarea diaria en la sección de Metas para la acción física
      const { error: goalError } = await supabase
        .from('goals')
        .insert([
          {
            user_id: user.id,
            title: `Acción Inspirada: ${action}`,
            description: `Acción física diaria para manifestar: "${desire}"`,
            duration_days: 1, // Meta de 1 día
            progress: 0
          }
        ]);
        
      if (goalError) {
        console.error("Error al registrar la acción inspirada en Metas:", goalError);
      }
      
      setSavedSuccess(true);
      if (data) {
        setSavedTriangles(prev => [data, ...prev]);
      }
    } catch (err: any) {
      alert("Error al guardar el triángulo: " + err.message);
    }
  };

  const handleAreaClick = (areaId: string) => {
    setSelectedArea(areaId);
    setMode('input');
  };

  const startGuidedBreathing = () => {
    setSelectedArea('guided_breathing');
    setMode('guided_session');
    setGuidedStep(0);
    setTimer(18); // 18 segundos para la fase de respiración (6s inhalar, 6s retener, 6s exhalar)
  };

  const handleSelectGuidedArea = (areaId: string) => {
    setSelectedArea(areaId);
    setGuidedStep(2);
    setTimer(25); // 25 segundos para la visualización guiada activa
  };

  const startMeditation = () => {
    if (selectedArea === 'dinero' && !amount) return;
    if (selectedArea !== 'dinero' && !intention.trim()) return;
    setMode('meditation');
    setTimer(15); // 15 segundos para visualización directa
  };

  useEffect(() => {
    let interval: NodeJS.Timeout;
    if ((mode === 'meditation' || mode === 'guided_session') && timer > 0) {
      interval = setInterval(() => {
        setTimer((prev) => prev - 1);
      }, 1000);
    } else if ((mode === 'meditation' || mode === 'guided_session') && timer === 0) {
      if (mode === 'guided_session') {
        if (guidedStep === 0) {
          // Ir al Paso 1: Selección de Enfoque (espera a que el usuario haga clic)
          setGuidedStep(1);
        } else if (guidedStep === 2) {
          // Ir al Paso 3: Anclaje y Decreto (15 segundos)
          setGuidedStep(3);
          setTimer(15);
        } else if (guidedStep === 3) {
          // Finalizar sesión y lanzar recompensa temática
          setMode('reward');
        }
      } else {
        setMode('reward');
      }
    }
    return () => clearInterval(interval);
  }, [mode, timer, guidedStep]);

  // Animación del número subiendo rápido en el reward (solo para dinero)
  useEffect(() => {
    if (mode === 'reward' && selectedArea === 'dinero') {
      const targetAmount = parseInt(amount.replace(/,/g, ''), 10) || 5000;
      let current = 0;
      const step = Math.ceil(targetAmount / 50) || 100; // 50 pasos
      
      const interval = setInterval(() => {
        current += step;
        if (current >= targetAmount) {
          setDisplayAmount(targetAmount);
          clearInterval(interval);
        } else {
          setDisplayAmount(current);
        }
      }, 30);
      
      return () => clearInterval(interval);
    }
  }, [mode, amount, selectedArea]);

  const getBreathingPhase = () => {
    if (timer > 12) return 'inhale';
    if (timer > 6) return 'hold';
    return 'exhale';
  };
  const phase = getBreathingPhase();

  return (
    <div className="absolute inset-0 overflow-hidden bg-bg-primary">
      <AnimatePresence mode="wait">
        
        {/* MODO SELECCIÓN NORMAL */}
        {mode === 'selection' && (
          <motion.div 
            key="selection"
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: 20 }}
            className="p-4 sm:p-6 overflow-y-auto h-full pb-24 no-scrollbar"
          >
            <div className="text-xs font-bold text-text-secondary uppercase tracking-wider mb-4 pl-1">Técnicas Guiadas Cuánticas</div>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-6">
              {/* Opción 1: Sesión de Respiración */}
              <div className="relative overflow-hidden rounded-3xl p-5 border border-border-primary bg-gradient-to-br from-bg-secondary via-bg-secondary to-primary/5 shadow-sm flex flex-col items-center text-center group hover:border-primary/40 transition-all duration-300">
                <div className="absolute -top-12 -right-12 w-24 h-24 bg-primary/10 rounded-full blur-2xl pointer-events-none"></div>
                
                <div className="relative w-14 h-14 mb-4 flex items-center justify-center">
                  {/* Ondas expansivas pulsantes */}
                  <motion.div 
                    animate={{ scale: [1, 1.25, 1], opacity: [0.4, 0, 0.4] }}
                    transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }}
                    className="absolute inset-0 rounded-full border border-primary/30"
                  />
                  <div className="w-10 h-10 rounded-full bg-gradient-to-br from-primary to-primary-dark text-white flex items-center justify-center shadow-md relative z-10">
                    <IconPlayerPlayFilled size={16} className="ml-0.5 text-white" />
                  </div>
                </div>

                <h3 className="text-sm font-black text-text-primary mb-1 flex items-center gap-1.5 justify-center">
                  <IconSparkles size={14} className="text-accent-gold" /> Respiración Guiada
                </h3>
                <p className="text-text-secondary text-[11px] mb-4 max-w-[200px] leading-relaxed flex-1">
                  Calma profunda, enfoque e impregnación del subconsciente.
                </p>

                <button 
                  onClick={startGuidedBreathing}
                  className="w-full py-2.5 rounded-xl border-none text-[11px] font-bold uppercase tracking-wider transition-all bg-primary hover:bg-primary-dark text-white shadow-md active:scale-95 duration-200 cursor-pointer"
                >
                  Comenzar
                </button>
              </div>

              {/* Opción 2: Triángulo de Manifestación */}
              <div className="relative overflow-hidden rounded-3xl p-5 border border-border-primary bg-gradient-to-br from-bg-secondary via-bg-secondary to-accent-purple/5 shadow-sm flex flex-col items-center text-center group hover:border-accent-purple/40 transition-all duration-300">
                <div className="absolute -top-12 -right-12 w-24 h-24 bg-accent-purple/10 rounded-full blur-2xl pointer-events-none"></div>
                
                <div className="relative w-14 h-14 mb-4 flex items-center justify-center">
                  <motion.div 
                    animate={{ scale: [1, 1.25, 1], opacity: [0.4, 0, 0.4] }}
                    transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }}
                    className="absolute inset-0 rounded-full border border-accent-purple/30"
                  />
                  <div className="w-10 h-10 rounded-full bg-gradient-to-br from-accent-purple to-primary text-white flex items-center justify-center shadow-md relative z-10">
                    <IconTriangle size={18} className="text-white" />
                  </div>
                </div>

                <h3 className="text-sm font-black text-text-primary mb-1 flex items-center gap-1.5 justify-center">
                  Triángulo de Manifestación
                </h3>
                <p className="text-text-secondary text-[11px] mb-4 max-w-[200px] leading-relaxed flex-1">
                  Alinea Deseo, Emoción y Acción con una Afirmación Cuántica con IA.
                </p>

                <button 
                  onClick={() => {
                    setMode('triangle_session');
                    setTriangleStep(1);
                    setDesire('');
                    setEmotion('');
                    setAction('');
                    setGeneratedAffirmation('');
                    setSavedSuccess(false);
                  }}
                  className="w-full py-2.5 rounded-xl border-none text-[11px] font-bold uppercase tracking-wider transition-all bg-gradient-to-r from-accent-purple to-primary hover:from-primary hover:to-accent-purple text-white shadow-md active:scale-95 duration-200 cursor-pointer"
                >
                  Activar Triángulo 🔺
                </button>
              </div>
            </div>

            <div className="text-xs font-bold text-text-secondary uppercase tracking-wider mb-4 mt-8 pl-1">¿Qué deseas manifestar hoy?</div>
            <div className="grid grid-cols-2 gap-3 mb-8">
              {areas.map((area) => (
                <button
                  key={area.id}
                  onClick={() => handleAreaClick(area.id)}
                  className="p-5 rounded-3xl border bg-bg-secondary border-border-primary text-text-primary transition-all duration-200 flex flex-col items-center justify-center gap-2.5 hover:border-primary/50 hover:bg-primary/5 active:scale-95 shadow-sm hover:shadow-md cursor-pointer relative overflow-hidden group"
                >
                  {/* Resplandor al hacer hover */}
                  <div className="absolute inset-0 bg-gradient-to-br from-primary/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none" />
                  
                  <span className="text-3.5xl group-hover:scale-110 transition-transform duration-300">{area.icon}</span> 
                  <span className="text-[11px] font-bold uppercase tracking-wider text-text-secondary group-hover:text-primary transition-colors">{area.label}</span>
                </button>
              ))}
            </div>

            {/* MIS TRIÁNGULOS ACTIVOS */}
            {savedTriangles.length > 0 && (
              <div className="mt-8 mb-8 text-left">
                <div className="text-xs font-bold text-text-secondary uppercase tracking-wider mb-4 pl-1 flex items-center gap-1.5">
                  <IconTriangle size={14} className="text-accent-gold" /> Mis Triángulos Activos
                </div>
                
                <div className="space-y-4">
                  {savedTriangles.map((t) => (
                    <motion.div
                      key={t.id}
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      className="p-5 rounded-3xl bg-bg-secondary border border-border-primary hover:border-primary/20 transition-all duration-200 shadow-sm relative overflow-hidden group"
                    >
                      <div className="absolute top-4 right-4 flex gap-2">
                        <button
                          onClick={() => {
                            navigator.clipboard.writeText(t.affirmation);
                            alert("Afirmación copiada al portapapeles.");
                          }}
                          className="p-1.5 rounded-full hover:bg-black/5 dark:hover:bg-white/5 text-text-secondary hover:text-text-primary transition-all cursor-pointer"
                          title="Copiar Afirmación"
                        >
                          <IconCopy size={16} />
                        </button>
                        <button
                          onClick={() => handleDeleteTriangle(t.id)}
                          className="p-1.5 rounded-full hover:bg-red-500/10 text-text-secondary hover:text-red-500 transition-all cursor-pointer"
                          title="Eliminar Triángulo"
                        >
                          <IconX size={16} />
                        </button>
                      </div>

                      <div className="flex gap-3 mb-3">
                        <span className="text-xl">🔺</span>
                        <div>
                          <h4 className="text-[13px] font-bold text-text-primary uppercase tracking-wide">
                            {t.desire.length > 30 ? t.desire.slice(0, 30) + '...' : t.desire}
                          </h4>
                          <span className="text-[9px] font-semibold text-text-secondary uppercase tracking-wider block">
                            Creado el {new Date(t.created_at).toLocaleDateString()}
                          </span>
                        </div>
                      </div>

                      <div className="grid grid-cols-3 gap-2 border-t border-b border-border-primary/50 py-3 my-3 text-[11px] text-text-secondary">
                        <div>
                          <span className="font-bold text-indigo-400 block mb-0.5">Deseo</span>
                          <span className="line-clamp-2">{t.desire}</span>
                        </div>
                        <div>
                          <span className="font-bold text-pink-400 block mb-0.5">Emoción</span>
                          <span className="line-clamp-2">{t.emotion}</span>
                        </div>
                        <div>
                          <span className="font-bold text-amber-400 block mb-0.5">Acción</span>
                          <span className="line-clamp-2">{t.action}</span>
                        </div>
                      </div>

                      <div className="bg-white/5 border border-white/5 p-3 rounded-xl">
                        <span className="text-[9px] font-bold text-accent-gold uppercase tracking-wider block mb-1">Decreto Cuántico</span>
                        <p className="text-[12px] font-medium text-text-primary italic leading-relaxed">
                          "{t.affirmation}"
                        </p>
                      </div>
                    </motion.div>
                  ))}
                </div>
              </div>
            )}

          </motion.div>
        )}

        {/* MODO INPUT: INGRESAR CANTIDAD O DETALLE */}
        {mode === 'input' && (
          <motion.div 
            key="input"
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.95 }}
            className="p-4 sm:p-6 h-full flex flex-col justify-center pb-24 relative"
          >
            <button onClick={() => { setMode('selection'); setSelectedArea(''); }} className="absolute top-4 left-4 p-2 text-text-secondary hover:text-text-primary z-20">
              <IconX size={24} />
            </button>
            
            <div className="text-center mb-8">
              {selectedArea === 'dinero' && (
                <>
                  <span className="text-4xl mb-4 block">💰</span>
                  <h2 className="text-xl font-medium text-text-primary mb-2">¿Cuánto deseas manifestar?</h2>
                  <p className="text-text-secondary text-sm">El universo ama la claridad. Sé específico.</p>
                </>
              )}
              {selectedArea === 'amor' && (
                <>
                  <span className="text-4xl mb-4 block">💗</span>
                  <h2 className="text-xl font-medium text-text-primary mb-2">¿Cómo es tu relación ideal?</h2>
                  <p className="text-text-secondary text-sm">Describe las cualidades de la pareja o amor que deseas atraer.</p>
                </>
              )}
              {selectedArea === 'exito' && (
                <>
                  <span className="text-4xl mb-4 block">🚀</span>
                  <h2 className="text-xl font-medium text-text-primary mb-2">¿Qué gran meta quieres alcanzar?</h2>
                  <p className="text-text-secondary text-sm">Visualizar el éxito profesional o personal te acerca a él.</p>
                </>
              )}
              {selectedArea === 'paz' && (
                <>
                  <span className="text-4xl mb-4 block">🕊️</span>
                  <h2 className="text-xl font-medium text-text-primary mb-2">¿Qué tensión deseas soltar hoy?</h2>
                  <p className="text-text-secondary text-sm">Para recibir paz, primero debemos dejar ir la resistencia.</p>
                </>
              )}
            </div>

            <div className="w-full max-w-[320px] mx-auto mb-8">
              {selectedArea === 'dinero' ? (
                <div className="relative w-full">
                  <div className="absolute left-4 top-1/2 -translate-y-1/2 text-text-secondary">
                    <IconCurrencyDollar size={24} />
                  </div>
                  <input 
                    type="number" 
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    placeholder="5000"
                    className="w-full bg-bg-secondary border-2 border-primary/30 rounded-2xl py-4 pl-12 pr-4 text-2xl font-bold text-center text-primary outline-none focus:border-primary transition-colors shadow-inner"
                    autoFocus
                  />
                </div>
              ) : (
                <textarea 
                  value={intention}
                  onChange={(e) => setIntention(e.target.value)}
                  placeholder={
                    selectedArea === 'amor' 
                      ? "Ej. Una pareja comprensiva, leal y llena de luz..."
                      : selectedArea === 'exito'
                      ? "Ej. Lanzar mi app y facturar mis primeros $10,000..."
                      : "Ej. La ansiedad por el futuro y el control de las situaciones..."
                  }
                  className="w-full bg-bg-secondary border-2 border-primary/30 rounded-2xl p-4 text-sm text-text-primary outline-none focus:border-primary transition-colors shadow-inner min-h-[100px] resize-none leading-relaxed"
                  autoFocus
                />
              )}
            </div>

            <button 
              onClick={startMeditation}
              disabled={selectedArea === 'dinero' ? !amount : !intention.trim()}
              className="w-full py-4 rounded-xl text-[16px] font-medium transition-all bg-primary text-white flex justify-center items-center gap-2 shadow-lg disabled:opacity-50 active:scale-[0.98] max-w-[250px] mx-auto"
            >
              Iniciar Alineación <IconPlayerPlayFilled size={18} />
            </button>
          </motion.div>
        )}

        {/* MODO MEDITACIÓN: SIMULACIÓN SIMPLE */}
        {mode === 'meditation' && (
          <motion.div 
            key="meditation"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="p-4 sm:p-6 h-full flex flex-col items-center justify-center bg-slate-900 text-white relative overflow-hidden"
          >
            {/* Ondas cerebrales / respiración */}
            <motion.div 
              animate={{ scale: [1, 1.2, 1], opacity: [0.3, 0.6, 0.3] }}
              transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
              className="absolute w-[300px] h-[300px] rounded-full bg-primary/20 blur-3xl"
            />
            
            <h2 className="text-xl font-medium mb-8 relative z-10 text-center font-bold">
              {selectedArea === 'dinero' && <>Respira profundo...<br/>Imagina que ya es tuyo.</>}
              {selectedArea === 'amor' && <>Siente la conexión...<br/>El amor que buscas ya vive en ti.</>}
              {selectedArea === 'exito' && <>Visualízate triunfando...<br/>Siente la gratitud de haberlo logrado.</>}
              {selectedArea === 'paz' && <>Inhala paz, exhala tensión...<br/>Déjalo ir.</>}
            </h2>
            
            <div className="text-5xl font-light tracking-widest relative z-10 mb-8 opacity-80">
              00:0{timer}
            </div>

            <p className="text-white/50 text-sm absolute bottom-32 text-center max-w-[250px]">
              (Sostén tu visualización por {timer} segundos)
            </p>
          </motion.div>
        )}

        {/* MODO SESIÓN DE VISUALIZACIÓN GUIADA INTERACTIVA */}
        {mode === 'guided_session' && (
          <motion.div 
            key="guided_session"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="p-4 sm:p-6 h-full flex flex-col items-center justify-center bg-slate-900 text-white relative overflow-hidden text-center"
          >
            <button onClick={() => { setMode('selection'); setSelectedArea(''); }} className="absolute top-4 left-4 p-2 text-white/60 hover:text-white z-20">
              <IconX size={24} />
            </button>
            
            {/* Ondas de respiración o meditación de fondo */}
            <motion.div 
              animate={{ 
                scale: guidedStep === 0 
                  ? (timer > 12 ? [1, 1.4] : timer > 6 ? [1.4, 1.4] : [1.4, 0.9])
                  : [1, 1.15, 1],
                opacity: [0.3, 0.5, 0.3],
                backgroundColor: guidedStep === 0 
                  ? (timer > 8 ? 'rgba(99, 102, 241, 0.4)' : timer > 4 ? 'rgba(236, 72, 153, 0.4)' : 'rgba(59, 130, 246, 0.4)')
                  : (selectedArea === 'dinero' ? 'rgba(234, 179, 8, 0.3)' : selectedArea === 'amor' ? 'rgba(244, 114, 182, 0.3)' : selectedArea === 'exito' ? 'rgba(249, 115, 22, 0.3)' : 'rgba(6, 182, 212, 0.3)')
              }}
              transition={{ duration: 4, repeat: guidedStep !== 0 ? Infinity : 0, ease: "easeInOut" }}
              className="absolute w-[240px] h-[240px] rounded-full blur-3xl pointer-events-none"
            />

            {/* PASO 0: CALMA / RESPIRACIÓN */}
            {guidedStep === 0 && (
              <>
                <h2 className="text-xl font-bold mb-12 relative z-10 leading-snug">
                  {timer > 12 && <>Inhala profundamente...<br/><span className="text-indigo-300 text-xs sm:text-sm font-normal">Siente el aire llenándote de vida</span></>}
                  {timer <= 12 && timer > 6 && <>Retén el aire...<br/><span className="text-pink-300 text-xs sm:text-sm font-normal">Siente la presencia y tu propia energía</span></>}
                  {timer <= 6 && <>Exhala despacio...<br/><span className="text-blue-300 text-xs sm:text-sm font-normal">Suelta toda la tensión del día</span></>}
                </h2>

                <motion.div 
                  animate={{ 
                    scale: phase === 'inhale' ? 1.35 : phase === 'hold' ? 1.35 : 0.8,
                    backgroundColor: phase === 'inhale' ? '#6366f1' : phase === 'hold' ? '#ec4899' : '#3b82f6',
                    boxShadow: phase === 'inhale' ? '0 0 40px rgba(99, 102, 241, 0.6)' : phase === 'hold' ? '0 0 40px rgba(236, 72, 153, 0.6)' : '0 0 40px rgba(59, 130, 246, 0.6)'
                  }}
                  transition={{ duration: 6, ease: "easeInOut" }}
                  className="w-28 h-28 rounded-full flex flex-col items-center justify-center relative z-10 mb-8"
                >
                  <span className="text-xs font-black text-white uppercase tracking-widest">
                    {phase === 'inhale' && "Inhala"}
                    {phase === 'hold' && "Retén"}
                    {phase === 'exhale' && "Exhala"}
                  </span>
                </motion.div>
                
                <div className="text-3xl font-light tracking-widest relative z-10 opacity-80 mb-4">
                  00:{timer < 10 ? `0${timer}` : timer}
                </div>
                <span className="text-[10px] uppercase font-bold tracking-wider text-white/50">Fase 1: Conexión Inicial</span>
              </>
            )}

            {/* PASO 1: SELECCIÓN DE ENFOQUE */}
            {guidedStep === 1 && (
              <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                className="w-full max-w-sm px-4 z-10"
              >
                <span className="text-4xl mb-4 block animate-bounce">🎯</span>
                <h2 className="text-lg font-black text-white mb-2 uppercase tracking-wide">Paso 2: Define el Enfoque</h2>
                <p className="text-white/70 text-xs sm:text-sm mb-8 leading-relaxed max-w-[280px] mx-auto">
                  ¿En qué área de tu vida quieres proyectar hoy tu energía creadora? Selecciona para continuar:
                </p>

                <div className="grid grid-cols-2 gap-3">
                  {areas.map((area) => (
                    <button
                      key={area.id}
                      onClick={() => handleSelectGuidedArea(area.id)}
                      className="p-4 rounded-2xl bg-white/5 hover:bg-primary border border-white/10 hover:border-primary text-white text-xs font-bold uppercase tracking-wider flex items-center justify-center gap-2 transition-all active:scale-95 cursor-pointer shadow-md"
                    >
                      <span>{area.icon}</span> {area.label}
                    </button>
                  ))}
                </div>
              </motion.div>
            )}

            {/* PASO 2: VISUALIZACIÓN ACTIVA */}
            {guidedStep === 2 && (
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                className="z-10 px-4 max-w-sm"
              >
                <div className="text-4xl mb-5 animate-pulse">
                  {selectedArea === 'dinero' && "💰"}
                  {selectedArea === 'amor' && "💗"}
                  {selectedArea === 'exito' && "🚀"}
                  {selectedArea === 'paz' && "🕊️"}
                </div>

                <h2 className="text-lg font-black uppercase tracking-wider mb-4 text-white">
                  Paso 3: Visualización Activa
                </h2>

                <div className="bg-white/5 border border-white/10 p-5 rounded-2xl mb-8 leading-relaxed italic text-xs sm:text-sm font-medium text-white/90">
                  {selectedArea === 'dinero' && "Imagina el saldo exacto que deseas tener en tu cuenta bancaria. Siente la tranquilidad, la libertad y el alivio de la abundancia financiera."}
                  {selectedArea === 'amor' && "Visualízate rodeado de amor, compartiendo momentos felices con tu pareja ideal o sintiendo un amor propio inquebrantable."}
                  {selectedArea === 'exito' && "Mírate triunfando en tu carrera, firmando ese contrato o recibiendo aplausos. Siente el orgullo del trabajo bien hecho."}
                  {selectedArea === 'paz' && "Imagina un paisaje natural en calma. Siente la brisa fresca y cómo toda tu preocupación se disuelve en el aire."}
                </div>

                <div className="text-4xl font-light tracking-widest opacity-80 mb-3">
                  00:{timer < 10 ? `0${timer}` : timer}
                </div>
                <span className="text-[10px] uppercase font-bold tracking-wider text-accent-gold flex items-center gap-1 justify-center">
                  <IconSparkles size={12} className="animate-pulse" /> Sostén la imagen mental
                </span>
              </motion.div>
            )}

            {/* PASO 3: DECRETAR Y ANCLAR */}
            {guidedStep === 3 && (
              <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                className="z-10 px-4 max-w-sm"
              >
                <span className="text-4xl mb-4 block">🔮</span>
                <h2 className="text-lg font-black text-white uppercase tracking-wider mb-4">
                  Paso 4: Decreto y Liberación
                </h2>

                <div className="bg-white/5 border border-white/10 p-5 rounded-2xl mb-8 leading-relaxed text-xs sm:text-sm font-medium text-slate-200 text-center">
                  Di en voz alta o repite en tu mente con convicción absoluta:
                  <p className="mt-3 text-sm font-bold text-accent-gold italic">
                    "Esto o algo mejor ya está manifestado en mi realidad para el mayor bien de todos. Gracias. Hecho está."
                  </p>
                </div>

                <div className="text-4xl font-light tracking-widest opacity-80 mb-3">
                  00:{timer < 10 ? `0${timer}` : timer}
                </div>
                <span className="text-[10px] uppercase font-bold tracking-wider text-white/50">El universo está organizando tu pedido</span>
              </motion.div>
            )}

          </motion.div>
        )}

        {/* MODO RECOMPENSA: EL JACKPOT ESPIRITUAL */}
        {mode === 'reward' && (
          <motion.div 
            key="reward"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="p-4 sm:p-6 h-full flex flex-col items-center justify-center relative bg-slate-950 overflow-hidden"
          >
            {/* Estallido / Aura central adaptada */}
            <motion.div 
              initial={{ scale: 0, opacity: 1 }}
              animate={{ scale: 5, opacity: 0 }}
              transition={{ duration: 1.5, ease: "easeOut" }}
              className={twMerge(
                "absolute w-64 h-64 rounded-full blur-2xl",
                selectedArea === 'dinero' && "bg-yellow-400",
                selectedArea === 'amor' && "bg-pink-400",
                selectedArea === 'exito' && "bg-orange-400",
                selectedArea === 'paz' && "bg-cyan-400",
                selectedArea === 'guided_breathing' && "bg-indigo-400"
              )}
            />
            
            {/* Resplandor constante adaptado */}
            <motion.div 
              animate={{ scale: [1, 1.1, 1], opacity: [0.5, 0.8, 0.5] }}
              transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }}
              className={twMerge(
                "absolute w-full h-full bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] via-slate-950/80 to-slate-950",
                selectedArea === 'dinero' && "from-yellow-500/20",
                selectedArea === 'amor' && "from-pink-500/20",
                selectedArea === 'exito' && "from-orange-500/20",
                selectedArea === 'paz' && "from-cyan-500/20",
                selectedArea === 'guided_breathing' && "from-indigo-500/20"
              )}
            />

            {/* Partículas adaptadas cayendo */}
            {[...Array(12)].map((_, i) => (
              <motion.div
                key={i}
                initial={{ y: -100, x: Math.random() * 400 - 200, opacity: 0 }}
                animate={{ y: 800, x: (Math.random() * 400 - 200) + (Math.random() * 200 - 100), opacity: [0, 1, 1, 0], rotate: Math.random() * 360 }}
                transition={{ duration: 2 + Math.random() * 2, delay: Math.random() * 0.5, ease: "linear" }}
                className={twMerge(
                  "absolute text-2xl z-0",
                  selectedArea === 'dinero' && "text-yellow-400",
                  selectedArea === 'amor' && "text-pink-400",
                  selectedArea === 'exito' && "text-orange-400",
                  selectedArea === 'paz' && "text-cyan-400",
                  selectedArea === 'guided_breathing' && "text-indigo-400"
                )}
                style={{ left: '50%' }}
              >
                {selectedArea === 'dinero' && "✨"}
                {selectedArea === 'amor' && "💖"}
                {selectedArea === 'exito' && "🚀"}
                {selectedArea === 'paz' && "🕊️"}
                {selectedArea === 'guided_breathing' && "🌟"}
              </motion.div>
            ))}

            <motion.div 
              initial={{ scale: 0.5, opacity: 0, y: 50 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              transition={{ duration: 0.8, delay: 0.3, type: "spring" }}
              className="relative z-10 text-center flex flex-col items-center p-4"
            >
              <div className={twMerge(
                "w-20 h-20 border rounded-full flex items-center justify-center mb-6 shadow-lg",
                selectedArea === 'dinero' && "bg-yellow-400/20 border-yellow-400/50 shadow-[0_0_50px_rgba(250,204,21,0.4)] text-yellow-400",
                selectedArea === 'amor' && "bg-pink-400/20 border-pink-400/50 shadow-[0_0_50px_rgba(244,114,182,0.4)] text-pink-400",
                selectedArea === 'exito' && "bg-orange-400/20 border-orange-400/50 shadow-[0_0_50px_rgba(251,146,60,0.4)] text-orange-400",
                selectedArea === 'paz' && "bg-cyan-400/20 border-cyan-400/50 shadow-[0_0_50px_rgba(34,211,238,0.4)] text-cyan-400",
                selectedArea === 'guided_breathing' && "bg-indigo-400/20 border-indigo-400/50 shadow-[0_0_50px_rgba(129,140,248,0.4)] text-indigo-400"
              )}>
                {selectedArea === 'dinero' && <IconCheck size={40} />}
                {selectedArea === 'amor' && <IconHeart size={40} />}
                {selectedArea === 'exito' && <IconRocket size={40} />}
                {selectedArea === 'paz' && <IconSunset size={40} />}
                {selectedArea === 'guided_breathing' && <IconSparkles size={40} />}
              </div>
              
              <h2 className={twMerge(
                "text-xl font-medium tracking-widest uppercase mb-2",
                selectedArea === 'dinero' && "text-yellow-400",
                selectedArea === 'amor' && "text-pink-400",
                selectedArea === 'exito' && "text-orange-400",
                selectedArea === 'paz' && "text-cyan-400",
                selectedArea === 'guided_breathing' && "text-indigo-400"
              )}>
                {selectedArea === 'guided_breathing' ? "Mente Sintonizada" : "Vibración Alineada"}
              </h2>
              
              {selectedArea === 'dinero' ? (
                <div className="text-6xl font-bold text-white mb-6 tracking-tighter drop-shadow-lg flex items-center justify-center">
                  <span className="text-yellow-400 mr-1">$</span>
                  {displayAmount.toLocaleString()}
                </div>
              ) : (
                <div className="text-sm sm:text-base font-bold text-white mb-6 max-w-[280px] drop-shadow-md px-2 italic">
                  "{selectedArea === 'guided_breathing' ? 'Respiración Consciente' : intention || 'Alineación Completada'}"
                </div>
              )}
              
              <p className="text-slate-300 text-[14px] mb-12 max-w-[280px] leading-relaxed">
                {selectedArea === 'dinero' && "El universo ha recibido tu petición. El dinero ya viene en camino."}
                {selectedArea === 'amor' && "Tu vibración está elevada. El amor ideal fluye naturalmente a tu realidad."}
                {selectedArea === 'exito' && "Frecuencia de éxito establecida. El universo conspira para que alcances tus metas."}
                {selectedArea === 'paz' && "Has liberado la tensión. Tu mente está en calma y tu corazón alineado."}
                {selectedArea === 'guided_breathing' && "Tu energía ha sido reajustada. Estás en sintonía perfecta para manifestar."}
              </p>

              <button 
                onClick={() => { setMode('selection'); setAmount(''); setIntention(''); setSelectedArea(''); setGuidedStep(0); }}
                className={twMerge(
                  "px-8 py-3 rounded-full border hover:bg-white/5 transition-colors uppercase text-sm tracking-widest font-medium",
                  selectedArea === 'dinero' && "border-yellow-400/50 text-yellow-400 hover:bg-yellow-400/10",
                  selectedArea === 'amor' && "border-pink-400/50 text-pink-400 hover:bg-pink-400/10",
                  selectedArea === 'exito' && "border-orange-400/50 text-orange-400 hover:bg-orange-400/10",
                  selectedArea === 'paz' && "border-cyan-400/50 text-cyan-400 hover:bg-cyan-400/10",
                  selectedArea === 'guided_breathing' && "border-indigo-400/50 text-indigo-400 hover:bg-indigo-400/10"
                )}
              >
                Agradecer y Volver
              </button>
            </motion.div>
          </motion.div>
        )}

        {/* MODO TRIÁNGULO DE MANIFESTACIÓN */}
        {mode === 'triangle_session' && (
          <motion.div 
            key="triangle_session"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="p-4 sm:p-6 h-full flex flex-col items-center justify-center bg-slate-900 text-white relative overflow-y-auto no-scrollbar pb-24 text-center"
          >
            {/* Botón de cerrar */}
            <button 
              onClick={() => { setMode('selection'); }} 
              className="absolute top-4 left-4 p-2 text-white/60 hover:text-white z-20"
            >
              <IconX size={24} />
            </button>
            
            {/* Triángulo SVG Interactivo */}
            {triangleStep < 4 && (
              <div className="w-full flex flex-col items-center select-none">
                <svg className="w-64 h-56 mx-auto mb-6 drop-shadow-[0_0_15px_rgba(99,102,241,0.2)]" viewBox="0 0 300 260">
                  <defs>
                    <filter id="glow-triangle" x="-20%" y="-20%" width="140%" height="140%">
                      <feGaussianBlur stdDeviation="5" result="blur" />
                      <feMerge>
                        <feMergeNode in="blur" />
                        <feMergeNode in="SourceGraphic" />
                      </feMerge>
                    </filter>
                    <linearGradient id="loading-grad" x1="0%" y1="0%" x2="100%" y2="100%">
                      <stop offset="0%" stopColor="#6366f1" />
                      <stop offset="50%" stopColor="#ec4899" />
                      <stop offset="100%" stopColor="#f59e0b" />
                    </linearGradient>
                  </defs>
                  
                  {/* Láser de carga cuando se genera */}
                  {generatingTriangle && (
                    <motion.polygon 
                      points="150,40 50,220 250,220" 
                      fill="rgba(245,158,11,0.05)"
                      stroke="url(#loading-grad)"
                      strokeWidth="4"
                      animate={{ 
                        strokeDashoffset: [0, 600],
                        opacity: [0.4, 0.9, 0.4]
                      }}
                      style={{ 
                        strokeDasharray: "15, 30", 
                        filter: "drop-shadow(0 0 8px rgba(236,72,153,0.7))" 
                      }}
                      transition={{ 
                        duration: 4, 
                        repeat: Infinity, 
                        ease: "linear" 
                      }}
                    />
                  )}

                  {/* Líneas de conexión */}
                  <motion.line 
                    x1={150} y1={40} x2={50} y2={220} 
                    animate={generatingTriangle ? { 
                      stroke: ["#6366f1", "#ec4899", "#6366f1"],
                      strokeWidth: [2, 4, 2]
                    } : {}}
                    transition={{ duration: 2, repeat: Infinity }}
                    className="transition-all duration-500"
                    stroke={(!!desire.trim() || triangleStep >= 2) ? "#818cf8" : "rgba(255, 255, 255, 0.1)"}
                    strokeWidth="3"
                    style={{
                      filter: (!!desire.trim() || triangleStep >= 2) ? 'url(#glow-triangle)' : 'none'
                    }}
                  />
                  <motion.line 
                    x1={50} y1={220} x2={250} y2={220.1} 
                    animate={generatingTriangle ? { 
                      stroke: ["#ec4899", "#f59e0b", "#ec4899"],
                      strokeWidth: [2, 4, 2]
                    } : {}}
                    transition={{ duration: 2, repeat: Infinity }}
                    className="transition-all duration-500"
                    stroke={(!!emotion.trim() || triangleStep >= 3) ? "#f472b6" : "rgba(255, 255, 255, 0.1)"}
                    strokeWidth="3"
                    style={{
                      filter: (!!emotion.trim() || triangleStep >= 3) ? 'url(#glow-triangle)' : 'none'
                    }}
                  />
                  <motion.line 
                    x1={250} y1={220} x2={150} y2={40} 
                    animate={generatingTriangle ? { 
                      stroke: ["#f59e0b", "#6366f1", "#f59e0b"],
                      strokeWidth: [2, 4, 2]
                    } : {}}
                    transition={{ duration: 2, repeat: Infinity }}
                    className="transition-all duration-500"
                    stroke={(!!action.trim() || triangleStep >= 4) ? "#fbbf24" : "rgba(255, 255, 255, 0.1)"}
                    strokeWidth="3"
                    style={{
                      filter: (!!action.trim() || triangleStep >= 4) ? 'url(#glow-triangle)' : 'none'
                    }}
                  />

                  {/* Vértice 1: Deseo */}
                  <g className="cursor-pointer" onClick={() => !generatingTriangle && setTriangleStep(1)}>
                    <motion.circle 
                      cx={150} cy={40} r={14} 
                      animate={generatingTriangle ? {
                        scale: [1, 1.25, 1],
                        fill: ["#6366f1", "#ec4899", "#6366f1"]
                      } : {}}
                      transition={{ duration: 1.5, repeat: Infinity, ease: "easeInOut" }}
                      className={twMerge(
                        "transition-all duration-500",
                        triangleStep === 1 ? "fill-indigo-500 stroke-indigo-300 stroke-[3px] animate-pulse" : 
                        desire.trim() ? "fill-indigo-500 stroke-indigo-400 stroke-2" : "fill-white/10 stroke-white/20 stroke-1"
                      )}
                      style={triangleStep >= 1 || desire.trim() ? { filter: 'url(#glow-triangle)' } : {}}
                    />
                    <text x={150} y={15} textAnchor="middle" className="fill-white text-[10px] uppercase font-black tracking-widest">Deseo 🔺</text>
                  </g>

                  {/* Vértice 2: Emoción */}
                  <g className="cursor-pointer" onClick={() => !generatingTriangle && desire.trim() && setTriangleStep(2)}>
                    <motion.circle 
                      cx={50} cy={220} r={14} 
                      animate={generatingTriangle ? {
                        scale: [1, 1.25, 1],
                        fill: ["#ec4899", "#f59e0b", "#ec4899"]
                      } : {}}
                      transition={{ duration: 1.5, repeat: Infinity, ease: "easeInOut", delay: 0.3 }}
                      className={twMerge(
                        "transition-all duration-500",
                        triangleStep === 2 ? "fill-pink-500 stroke-pink-300 stroke-[3px] animate-pulse" : 
                        emotion.trim() ? "fill-pink-500 stroke-pink-400 stroke-2" : "fill-white/10 stroke-white/20 stroke-1"
                      )}
                      style={triangleStep >= 2 || emotion.trim() ? { filter: 'url(#glow-triangle)' } : {}}
                    />
                    <text x={50} y={248} textAnchor="middle" className="fill-white text-[10px] uppercase font-black tracking-widest">Emoción 💗</text>
                  </g>

                  {/* Vértice 3: Acción */}
                  <g className="cursor-pointer" onClick={() => !generatingTriangle && desire.trim() && emotion.trim() && setTriangleStep(3)}>
                    <motion.circle 
                      cx={250} cy={220} r={14} 
                      animate={generatingTriangle ? {
                        scale: [1, 1.25, 1],
                        fill: ["#f59e0b", "#6366f1", "#f59e0b"]
                      } : {}}
                      transition={{ duration: 1.5, repeat: Infinity, ease: "easeInOut", delay: 0.6 }}
                      className={twMerge(
                        "transition-all duration-500",
                        triangleStep === 3 ? "fill-amber-500 stroke-amber-300 stroke-[3px] animate-pulse" : 
                        action.trim() ? "fill-amber-500 stroke-amber-400 stroke-2" : "fill-white/10 stroke-white/20 stroke-1"
                      )}
                      style={triangleStep >= 3 || action.trim() ? { filter: 'url(#glow-triangle)' } : {}}
                    />
                    <text x={250} y={248} textAnchor="middle" className="fill-white text-[10px] uppercase font-black tracking-widest">Acción ⚡</text>
                  </g>
                </svg>
              </div>
            )}

            {/* FORMULARIOS DE PASOS */}
            {triangleStep === 1 && (
              <motion.div 
                initial={{ opacity: 0, y: 15 }} 
                animate={{ opacity: 1, y: 0 }} 
                className="w-full max-w-sm px-4 z-10"
              >
                <span className="text-[10px] font-bold uppercase tracking-widest text-indigo-400 bg-indigo-500/10 px-3 py-1 rounded-full border border-indigo-500/20 mb-3 inline-block">
                  Vértice 1: Deseo
                </span>
                <h3 className="text-lg font-black mb-2 text-white">¿Qué quieres manifestar en tu realidad?</h3>
                <p className="text-white/60 text-xs mb-6 leading-relaxed">
                  Sé sumamente claro, específico y conciso. Escríbelo en tiempo presente.
                </p>

                <textarea
                  value={desire}
                  onChange={(e) => setDesire(e.target.value)}
                  placeholder="Ej. Tener ingresos mensuales de 10,000 USD trabajando en mi propio negocio."
                  className="w-full bg-white/5 border border-white/10 rounded-2xl p-4 text-sm text-white outline-none focus:border-indigo-500 transition-colors shadow-inner min-h-[90px] resize-none leading-relaxed mb-6"
                  autoFocus
                />

                <button
                  disabled={!desire.trim()}
                  onClick={() => setTriangleStep(2)}
                  className="w-full py-3.5 rounded-xl text-xs font-bold uppercase tracking-wider transition-all bg-indigo-600 hover:bg-indigo-500 text-white flex justify-center items-center gap-2 shadow-lg disabled:opacity-50 active:scale-[0.98] cursor-pointer"
                >
                  Siguiente Vértice
                </button>
              </motion.div>
            )}

            {triangleStep === 2 && (
              <motion.div 
                initial={{ opacity: 0, y: 15 }} 
                animate={{ opacity: 1, y: 0 }} 
                className="w-full max-w-sm px-4 z-10"
              >
                <span className="text-[10px] font-bold uppercase tracking-widest text-pink-400 bg-pink-500/10 px-3 py-1 rounded-full border border-pink-500/20 mb-3 inline-block">
                  Vértice 2: Emoción
                </span>
                <h3 className="text-lg font-black mb-2 text-white">¿Cómo te sentirías si ya estuviera cumplido?</h3>
                <p className="text-white/60 text-xs mb-6 leading-relaxed">
                  El sentimiento es el secreto. Escribe las emociones primarias o selecciónalas abajo:
                </p>

                <textarea
                  value={emotion}
                  onChange={(e) => setEmotion(e.target.value)}
                  placeholder="Ej. Siento una inmensa libertad, paz mental profunda y gratitud."
                  className="w-full bg-white/5 border border-white/10 rounded-2xl p-4 text-sm text-white outline-none focus:border-pink-500 transition-colors shadow-inner min-h-[90px] resize-none leading-relaxed mb-4"
                  autoFocus
                />

                {/* Chips rápidos de emociones */}
                <div className="flex flex-wrap gap-2 justify-center mb-6">
                  {['Gratitud 💖', 'Libertad 🦋', 'Seguridad 💪', 'Paz 🕊️', 'Entusiasmo ⚡', 'Amor 💗', 'Alegría 😊'].map((chip) => (
                    <button
                      key={chip}
                      type="button"
                      onClick={() => {
                        const cleanChip = chip.split(' ')[0];
                        if (!emotion.trim()) {
                          setEmotion(cleanChip);
                        } else {
                          setEmotion(prev => prev.includes(cleanChip) ? prev : `${prev}, ${cleanChip}`);
                        }
                      }}
                      className="px-3 py-1.5 rounded-full bg-white/5 hover:bg-pink-500/20 border border-white/10 hover:border-pink-500/30 text-[11px] font-medium text-white transition-all cursor-pointer"
                    >
                      {chip}
                    </button>
                  ))}
                </div>

                <div className="flex gap-3">
                  <button
                    onClick={() => setTriangleStep(1)}
                    className="flex-1 py-3.5 rounded-xl text-xs font-bold uppercase tracking-wider transition-all bg-white/5 hover:bg-white/10 border border-white/10 text-white active:scale-[0.98] cursor-pointer"
                  >
                    Atrás
                  </button>
                  <button
                    disabled={!emotion.trim()}
                    onClick={() => setTriangleStep(3)}
                    className="flex-1 py-3.5 rounded-xl text-xs font-bold uppercase tracking-wider transition-all bg-pink-600 hover:bg-pink-500 text-white flex justify-center items-center gap-2 shadow-lg disabled:opacity-50 active:scale-[0.98] cursor-pointer"
                  >
                    Siguiente Vértice
                  </button>
                </div>
              </motion.div>
            )}

            {triangleStep === 3 && (
              <motion.div 
                initial={{ opacity: 0, y: 15 }} 
                animate={{ opacity: 1, y: 0 }} 
                className="w-full max-w-sm px-4 z-10"
              >
                <span className="text-[10px] font-bold uppercase tracking-widest text-amber-400 bg-amber-500/10 px-3 py-1 rounded-full border border-amber-500/20 mb-3 inline-block">
                  Vértice 3: Acción
                </span>
                <h3 className="text-lg font-black mb-2 text-white">¿Qué acción concreta tomarás hoy?</h3>
                <p className="text-white/60 text-xs mb-6 leading-relaxed">
                  Define un paso físico y real, no importa qué tan pequeño sea. El movimiento activa la energía.
                </p>

                <textarea
                  value={action}
                  onChange={(e) => setAction(e.target.value)}
                  placeholder="Ej. Redactar el plan del proyecto o contactar a dos potenciales clientes."
                  className="w-full bg-white/5 border border-white/10 rounded-2xl p-4 text-sm text-white outline-none focus:border-amber-500 transition-colors shadow-inner min-h-[90px] resize-none leading-relaxed mb-6"
                  autoFocus
                />

                <div className="flex gap-3">
                  <button
                    onClick={() => setTriangleStep(2)}
                    className="flex-1 py-3.5 rounded-xl text-xs font-bold uppercase tracking-wider transition-all bg-white/5 hover:bg-white/10 border border-white/10 text-white active:scale-[0.98] cursor-pointer"
                  >
                    Atrás
                  </button>
                  <button
                    disabled={!action.trim() || generatingTriangle}
                    onClick={async () => {
                      if (!user) {
                        alert("Por favor, inicia sesión para activar y guardar tu Triángulo de Manifestación.");
                        return;
                      }
                      setGeneratingTriangle(true);
                      try {
                        // 1. Generar la afirmación cuántica con la IA
                        const res = await fetch('/api/triangle/generate', {
                          method: 'POST',
                          headers: {
                            'Content-Type': 'application/json',
                          },
                          body: JSON.stringify({ desire, emotion, action })
                        });
                        const data = await res.json();
                        if (!res.ok) throw new Error(data.error || 'Error al generar la afirmación');
                        
                        const newAffirmation = data.affirmation;
                        setGeneratedAffirmation(newAffirmation);

                        // 2. Guardar automáticamente el triángulo en la base de datos de Supabase
                        const { data: savedTri, error: triError } = await supabase
                          .from('manifestation_triangles')
                          .insert([
                            {
                              user_id: user.id,
                              desire,
                              emotion,
                              action,
                              affirmation: newAffirmation
                            }
                          ])
                          .select()
                          .single();
                          
                        if (triError) throw triError;
                        
                        // Actualizar lista local de triángulos
                        if (savedTri) {
                          setSavedTriangles(prev => [savedTri, ...prev]);
                        }

                        // 3. Crear automáticamente una micro-tarea diaria en Metas para la acción física
                        const { error: goalError } = await supabase
                          .from('goals')
                          .insert([
                            {
                              user_id: user.id,
                              title: `Acción Inspirada: ${action}`,
                              description: `Acción física diaria para manifestar: "${desire}"`,
                              duration_days: 1, // Meta de 1 día
                              progress: 0
                            }
                          ]);
                          
                        if (goalError) {
                          console.error("Error al registrar la acción inspirada en Metas:", goalError);
                        }

                        // Ir al paso de resultado (ya se marca como guardado exitosamente)
                        setSavedSuccess(true);
                        setTriangleStep(4);
                      } catch (err: any) {
                        alert(err.message || 'Error al conectar con la IA de Manifestación.');
                      } finally {
                        setGeneratingTriangle(false);
                      }
                    }}
                    className="flex-1 py-3.5 rounded-xl text-xs font-bold uppercase tracking-wider transition-all bg-gradient-to-r from-amber-500 to-amber-600 hover:from-amber-400 hover:to-amber-500 text-white flex justify-center items-center gap-2 shadow-lg disabled:opacity-50 active:scale-[0.98] cursor-pointer"
                  >
                    {generatingTriangle ? (
                      <IconLoader2 size={16} className="animate-spin" />
                    ) : (
                      "Activar Triángulo 🔺"
                    )}
                  </button>
                </div>
              </motion.div>
            )}

            {/* PASO 4: RESULTADO DE LA AFIRMACIÓN CUÁNTICA */}
            {triangleStep === 4 && (
              <motion.div 
                initial={{ opacity: 0, scale: 0.95 }} 
                animate={{ opacity: 1, scale: 1 }} 
                className="w-full max-w-sm px-4 z-10 flex flex-col items-center"
              >
                {/* SVG Triángulo Completamente Iluminado */}
                <motion.div 
                  initial={{ scale: 0.8, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  transition={{ type: 'spring', damping: 15 }}
                  className="mb-2 relative"
                >
                  <svg className="w-40 h-36 drop-shadow-[0_0_20px_rgba(245,158,11,0.5)]" viewBox="0 0 300 260">
                    <defs>
                      <filter id="glow-full" x="-20%" y="-20%" width="140%" height="140%">
                        <feGaussianBlur stdDeviation="6" result="blur" />
                        <feMerge>
                          <feMergeNode in="blur" />
                          <feMergeNode in="SourceGraphic" />
                        </feMerge>
                      </filter>
                    </defs>
                    <polygon 
                      points="150,40 50,220 250,220" 
                      fill="rgba(245,158,11,0.08)"
                      stroke="url(#triangle-grad)"
                      strokeWidth="5"
                      style={{ filter: 'url(#glow-full)' }}
                    />
                    <linearGradient id="triangle-grad" x1="0%" y1="0%" x2="100%" y2="100%">
                      <stop offset="0%" stopColor="#6366f1" />
                      <stop offset="50%" stopColor="#ec4899" />
                      <stop offset="100%" stopColor="#f59e0b" />
                    </linearGradient>
                    <circle cx={150} cy={40} r={12} fill="#6366f1" />
                    <circle cx={50} cy={220} r={12} fill="#ec4899" />
                    <circle cx={250} cy={220} r={12} fill="#f59e0b" />
                  </svg>
                </motion.div>

                <h2 className="text-xl font-black text-white uppercase tracking-wider mb-2">
                  ¡Triángulo Activado! ✨
                </h2>
                <p className="text-white/60 text-[11px] mb-6 leading-relaxed max-w-[280px]">
                  La IA ha alineado tus frecuencias de deseo, emoción y acción. Tu afirmación cuántica está lista:
                </p>

                {/* Tarjeta de la Afirmación */}
                <div className="w-full bg-white/5 border border-white/10 p-6 rounded-2xl mb-5 relative overflow-hidden shadow-inner flex flex-col items-center">
                  <div className="absolute top-2 left-2 text-white/10 font-serif text-6xl leading-none pointer-events-none select-none">“</div>
                  <p className="text-sm font-bold text-accent-gold italic leading-relaxed text-center relative z-10 px-2">
                    "{generatedAffirmation}"
                  </p>
                </div>

                {/* Meta de Acción Creada Automáticamente */}
                <motion.div 
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.15 }}
                  className="w-full bg-gradient-to-r from-indigo-500/10 to-pink-500/10 border border-indigo-500/20 p-4 rounded-2xl mb-6 text-left flex items-start gap-3 shadow-inner relative overflow-hidden"
                >
                  <div className="absolute top-0 right-0 w-16 h-16 bg-gradient-to-br from-indigo-500/10 to-pink-500/10 rounded-full blur-xl pointer-events-none"></div>
                  <div className="w-8 h-8 rounded-full bg-gradient-to-br from-indigo-500 to-pink-500 flex items-center justify-center text-white shrink-0 shadow-md">
                    <IconTarget size={16} stroke={2.5} className="text-white" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <span className="text-[9px] font-black text-indigo-400 dark:text-indigo-300 uppercase tracking-widest block mb-0.5">Meta de Acción Activada</span>
                    <h4 className="text-[12px] font-bold text-white leading-tight mb-1 truncate">
                      Acción Inspirada: {action}
                    </h4>
                    <p className="text-[10px] text-white/60 leading-relaxed">
                      Se ha programado una meta de 1 día en tu pestaña de Metas para concretar tu deseo hoy mismo. ¡El universo responde al movimiento físico!
                    </p>
                  </div>
                </motion.div>

                {/* Acciones */}
                <div className="w-full space-y-3">
                  <div className="flex gap-3">
                    {/* Botón Copiar */}
                    <button
                      onClick={() => {
                        navigator.clipboard.writeText(generatedAffirmation);
                        setCopied(true);
                        setTimeout(() => setCopied(false), 2000);
                      }}
                      className="flex-1 py-3.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-white text-xs font-bold uppercase tracking-wider transition-all flex items-center justify-center gap-2 cursor-pointer active:scale-95"
                    >
                      {copied ? (
                        <>
                          <IconCheck size={16} className="text-green-400" />
                          Copiado
                        </>
                      ) : (
                        <>
                          <IconCopy size={16} />
                          Copiar Decreto
                        </>
                      )}
                    </button>

                    {/* Botón Ver en Metas */}
                    <button
                      onClick={() => {
                        const event = new CustomEvent("change-tab", { detail: "metas" });
                        window.dispatchEvent(event);
                      }}
                      className="flex-1 py-3.5 rounded-xl bg-gradient-to-r from-primary to-accent-purple hover:from-primary-dark hover:to-accent-purple/80 border-transparent text-white text-xs font-bold uppercase tracking-wider transition-all flex items-center justify-center gap-2 cursor-pointer active:scale-95 shadow-md shadow-primary/20"
                    >
                      <IconTarget size={16} stroke={2.5} />
                      Ver en Metas 🎯
                    </button>
                  </div>

                  <button
                    onClick={() => {
                      setMode('selection');
                    }}
                    className="w-full py-3.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-white text-xs font-bold uppercase tracking-wider transition-all active:scale-95 cursor-pointer"
                  >
                    Agradecer y Volver 🔺
                  </button>
                </div>
              </motion.div>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
