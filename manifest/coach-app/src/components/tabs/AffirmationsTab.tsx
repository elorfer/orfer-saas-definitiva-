"use client";

import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import Link from 'next/link';
import { 
  IconRefresh, 
  IconArrowUpRight, 
  IconCheck, 
  IconX, 
  IconSparkles, 
  IconLoader2, 
  IconLock,
  IconCalendar
} from '@tabler/icons-react';
import { twMerge } from 'tailwind-merge';
import { createClient } from '@/utils/supabase/client';

const afirmacionesData: Record<string, string[]> = {
  dinero: ["El dinero fluye hacia mí de forma fácil y abundante", "Soy un imán para la prosperidad y las oportunidades financieras", "Merezco abundancia y la recibo con gratitud", "Mi energía creativa genera ingresos de múltiples fuentes", "La riqueza es mi estado natural y la abrazo completamente"],
  amor: ["Soy digno/a de un amor profundo y auténtico", "Mi corazón está abierto para dar y recibir amor", "Atraigo relaciones saludables y llenas de alegría", "El amor que busco también me está buscando a mí", "Me amo profundamente y ese amor atrae amor verdadero"],
  salud: ["Mi cuerpo es fuerte, sano y lleno de vitalidad", "Cada célula de mi ser vibra en perfecta salud", "Merezco sintiéndome increíble en cuerpo y mente", "Mi energía es renovada y radiante cada día", "Confío plenamente en la sabiduría de mi cuerpo"],
  exito: ["El éxito es mi destino y cada paso me acerca a él", "Mis ideas tienen valor y el mundo las necesita", "Tengo todas las habilidades para alcanzar mis sueños", "Cada desafío es una oportunidad disfrazada de lección", "El universo conspira a mi favor en cada momento"],
  confianza: ["Confío plenamente en mí y en mi camino", "Mi voz importa y merezco ser escuchado/a", "Soy suficiente exactamente como soy hoy", "Avanzo con seguridad hacia la mejor versión de mí", "Mi confianza crece con cada pequeño paso que doy"],
  abundancia: ["Vivo en un universo de abundancia infinita", "Todo lo que necesito llega a mí en el momento perfecto", "La abundancia fluye hacia mí desde todas las direcciones", "Soy receptor/a agradecido/a de todas las bendiciones", "Mi vida está llena de oportunidades, amor y prosperidad"]
};

const areas = [
  { id: 'dinero', icon: '💰', label: 'Dinero' },
  { id: 'amor', icon: '💗', label: 'Amor' },
  { id: 'salud', icon: '🌿', label: 'Salud' },
  { id: 'exito', icon: '🚀', label: 'Éxito' },
  { id: 'confianza', icon: '🦋', label: 'Confianza' },
  { id: 'abundancia', icon: '🌟', label: 'Abundancia' },
];

export default function AffirmationsTab() {
  const supabase = createClient();
  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [selectedArea, setSelectedArea] = useState<string>('abundancia');
  const [currentAffirmation, setCurrentAffirmation] = useState(afirmacionesData['abundancia'][0]);
  const [customAffirmations, setCustomAffirmations] = useState<string[]>([]);
  
  // Estados para el Reto de 30 Días e IA
  const [activeChallenge, setActiveChallenge] = useState<any>(null);
  const [generating, setGenerating] = useState(false);
  const [showDayModal, setShowDayModal] = useState(false);
  const [selectedDay, setSelectedDay] = useState<number | null>(null);
  const [savingDay, setSavingDay] = useState(false);
  
  // Nivel de suscripción y control de pago
  const [isPro, setIsPro] = useState(false);
  const [showUpgradeModal, setShowUpgradeModal] = useState(false);

  useEffect(() => {
    const saved = localStorage.getItem('custom_affirmations');
    if (saved) {
      try {
        const parsed = JSON.parse(saved);
        if (Array.isArray(parsed) && parsed.length > 0) {
          setCustomAffirmations(parsed);
        }
      } catch (e) {
        console.error("Error parsing custom affirmations", e);
      }
    }
  }, []);

  useEffect(() => {
    const fetchUserAndChallenge = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        setUser(user);
        
        // Cargar perfil para ver tier de suscripción
        const { data: profile } = await supabase
          .from('profiles')
          .select('subscription_tier')
          .eq('id', user.id)
          .single();
          
        if (profile) {
          setIsPro(profile.subscription_tier === 'pro');
        }

        if (selectedArea === 'mis_decretos') {
          setActiveChallenge(null);
        } else {
          // Cargar el reto activo para el área seleccionada
          const { data, error } = await supabase
            .from('challenges')
            .select('*')
            .eq('user_id', user.id)
            .eq('area', selectedArea)
            .maybeSingle();

          if (!error && data) {
            setActiveChallenge(data);
          } else {
            setActiveChallenge(null);
          }
        }
      }
      setLoading(false);
    };

    fetchUserAndChallenge();
  }, [selectedArea]);

  const generateAffirmation = (area = selectedArea) => {
    if (!area) return;
    const list = area === 'mis_decretos' ? customAffirmations : afirmacionesData[area];
    if (!list || list.length === 0) {
      setCurrentAffirmation("Comienza a crear decretos en la sección del Triángulo de Manifestación 🔺");
      return;
    }
    const newAffirmation = list[Math.floor(Math.random() * list.length)];
    setCurrentAffirmation(newAffirmation);
  };

  const handleSelectArea = (area: string) => {
    setSelectedArea(area);
    generateAffirmation(area);
  };

  // Crear el reto con IA de 30 días
  const handleCreateChallenge = async () => {
    if (!user) return;
    
    // Bloquear si es usuario free
    if (!isPro) {
      setShowUpgradeModal(true);
      return;
    }

    setGenerating(true);

    try {
      const response = await fetch('/api/challenge/generate', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ area: selectedArea })
      });

      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.error || 'Error al generar el reto');
      }

      setActiveChallenge(data);
    } catch (err: any) {
      console.error(err);
      alert(err.message || 'Ocurrió un error al generar tu reto cuántico con la IA.');
    } finally {
      setGenerating(false);
    }
  };

  // Guardar un día completado en Supabase
  const handleCompleteDay = async () => {
    if (!activeChallenge || selectedDay === null) return;
    setSavingDay(true);

    try {
      const todayStr = new Date().toISOString();
      const updatedCompletedDays = {
        ...activeChallenge.completed_days,
        [selectedDay]: todayStr
      };

      const { error } = await supabase
        .from('challenges')
        .update({ completed_days: updatedCompletedDays })
        .eq('id', activeChallenge.id);

      if (error) throw error;

      setActiveChallenge({
        ...activeChallenge,
        completed_days: updatedCompletedDays
      });
      setShowDayModal(false);
    } catch (err) {
      console.error(err);
      alert('Error al guardar tu progreso. Inténtalo de nuevo.');
    } finally {
      setSavingDay(false);
    }
  };

  // Cancelar / Resetear reto
  const handleResetChallenge = async () => {
    if (!activeChallenge) return;
    const confirmReset = window.confirm('¿Estás seguro de que deseas abandonar este reto? Se perderá todo tu progreso.');
    if (!confirmReset) return;

    setLoading(true);
    try {
      const { error } = await supabase
        .from('challenges')
        .delete()
        .eq('id', activeChallenge.id);
      
      if (error) throw error;
      setActiveChallenge(null);
    } catch (err: any) {
      console.error(err);
      alert('Error al abandonar el reto: ' + (err.message || 'Error de base de datos'));
    } finally {
      setLoading(false);
    }
  };


  // Calcular racha de días consecutivos
  const calculateStreak = (completedDays: Record<string, string>) => {
    const dates = Object.values(completedDays)
      .map(d => new Date(d).toDateString())
      .sort((a, b) => new Date(a).getTime() - new Date(b).getTime());

    if (dates.length === 0) return 0;

    let streak = 0;
    const today = new Date().toDateString();
    const yesterday = new Date(Date.now() - 86400000).toDateString();

    const hasToday = dates.includes(today);
    const hasYesterday = dates.includes(yesterday);

    if (!hasToday && !hasYesterday) return 0;

    let checkDate = hasToday ? new Date() : new Date(Date.now() - 86400000);
    
    while (true) {
      const dateStr = checkDate.toDateString();
      if (dates.includes(dateStr)) {
        streak++;
        checkDate.setDate(checkDate.getDate() - 1);
      } else {
        break;
      }
    }

    return streak;
  };

  const handleOpenDayDetail = (dayNumber: number) => {
    setSelectedDay(dayNumber);
    setShowDayModal(true);
  };

  const displayedAreas = [...areas];
  if (customAffirmations.length > 0) {
    displayedAreas.push({ id: 'mis_decretos', icon: '🔺', label: 'Mis Decretos' });
  }

  if (loading) {
    return (
      <div className="h-full flex items-center justify-center">
        <IconLoader2 size={32} className="animate-spin text-primary" />
      </div>
    );
  }

  // Renderizar contenido si hay un Reto Activo
  if (activeChallenge) {
    const completedDaysCount = Object.keys(activeChallenge.completed_days).length;
    const progressPercent = Math.round((completedDaysCount / 30) * 100);
    
    // Determinar cuál es el siguiente día a completar
    let nextDayToComplete = 1;
    for (let d = 1; d <= 30; d++) {
      if (!activeChallenge.completed_days[d]) {
        nextDayToComplete = d;
        break;
      }
    }

    const isChallengeFinished = completedDaysCount === 30;
    const streak = calculateStreak(activeChallenge.completed_days);

    return (
      <div className="absolute inset-0 p-4 sm:p-6 overflow-y-auto no-scrollbar pb-24 bg-bg-primary">
        
        {/* Cabecera del Reto */}
        <div className="bg-bg-secondary border border-border-primary rounded-2xl p-5 mb-6 relative overflow-hidden shadow-sm">
          <div className="absolute inset-0 bg-gradient-to-br from-primary/5 to-transparent pointer-events-none"></div>
          <div className="flex justify-between items-start relative z-10">
            <div>
              <span className="text-[10px] font-bold uppercase tracking-wider text-accent-gold bg-accent-gold/10 px-2.5 py-1 rounded-full border border-accent-gold/20 flex items-center gap-1 w-fit mb-2">
                <IconSparkles size={12} /> Reto Cuántico
              </span>
              <h2 className="text-[17px] font-bold text-text-primary">
                Alineación en {areas.find(a => a.id === activeChallenge.area)?.label || activeChallenge.area}
              </h2>
              <p className="text-text-secondary text-xs mt-1">Completa una afirmación y acción diaria durante 30 días.</p>
            </div>
            
            {streak > 0 && (
              <div className="text-right">
                <span className="text-2xl block">🔥</span>
                <span className="text-[10px] font-bold text-text-primary uppercase tracking-wider block">{streak} {streak === 1 ? 'DÍA' : 'DÍAS'}</span>
              </div>
            )}
          </div>

          {/* Progreso */}
          <div className="mt-5 space-y-2">
            <div className="flex justify-between text-xs font-semibold text-text-secondary">
              <span>Progreso del Subconsciente</span>
              <span>{completedDaysCount} de 30 ({progressPercent}%)</span>
            </div>
            <div className="h-2 bg-border-primary rounded-full overflow-hidden">
              <motion.div 
                initial={{ width: 0 }}
                animate={{ width: `${progressPercent}%` }}
                className="h-full bg-gradient-to-r from-primary to-accent-gold rounded-full"
              />
            </div>
          </div>
        </div>

        {/* Mensaje de éxito al completar */}
        {isChallengeFinished ? (
          <div className="text-center py-10 px-4 bg-bg-secondary/50 border border-green-500/20 rounded-3xl mb-8 flex flex-col items-center">
            <span className="text-5xl mb-4">🏆</span>
            <h3 className="text-lg font-black text-text-primary mb-2">¡Reto Completado con Éxito!</h3>
            <p className="text-text-secondary text-xs sm:text-sm max-w-xs leading-relaxed mb-6">
              Has completado tus 30 días de reprogramación mental. Sigue manifestando tu nueva realidad con altas vibraciones.
            </p>
            <button 
              onClick={handleResetChallenge}
              className="px-6 py-2.5 rounded-xl bg-primary hover:bg-primary-dark text-white text-xs font-bold uppercase tracking-wider shadow-md"
            >
              Iniciar Nuevo Reto
            </button>
          </div>
        ) : (
          <>
            <div className="text-xs font-bold text-text-secondary uppercase tracking-wider mb-4 flex items-center gap-1.5">
              <IconCalendar size={16} /> Tu Mapa de Reprogramación
            </div>
            
            {/* Grilla de 30 Días */}
            <div className="grid grid-cols-5 gap-3 max-w-[340px] mx-auto mb-8">
              {Array.from({ length: 30 }, (_, i) => {
                const dayNumber = i + 1;
                const isCompleted = !!activeChallenge.completed_days[dayNumber];
                const isCurrent = dayNumber === nextDayToComplete;
                const isLocked = dayNumber > nextDayToComplete;

                return (
                  <button
                    key={dayNumber}
                    disabled={isLocked || isCompleted}
                    onClick={() => handleOpenDayDetail(dayNumber)}
                    className={twMerge(
                      "w-12 h-12 rounded-xl flex items-center justify-center font-bold text-sm transition-all relative",
                      isCompleted && "bg-green-500/10 border border-green-500/20 text-green-500 shadow-inner",
                      isCurrent && "bg-primary text-white shadow-md animate-pulse-slow shadow-primary/20 cursor-pointer hover:bg-primary-dark",
                      isLocked && "bg-bg-secondary/40 border border-border-primary text-text-secondary/30 cursor-not-allowed"
                    )}
                  >
                    {isCompleted ? <IconCheck size={18} stroke={3} /> : dayNumber}
                    {isLocked && (
                      <span className="absolute -top-1 -right-1 text-[8px] opacity-40">
                        <IconLock size={8} />
                      </span>
                    )}
                  </button>
                );
              })}
            </div>

            {/* Acciones de Footer */}
            <div className="text-center">
              <button 
                onClick={handleResetChallenge}
                className="text-xs text-red-500/60 hover:text-red-500 font-semibold transition-colors focus:outline-none"
              >
                Abandonar Reto Actual
              </button>
            </div>
          </>
        )}

        {/* MODAL DE DETALLE DIARIO */}
        <AnimatePresence>
          {showDayModal && selectedDay !== null && (
            <div className="fixed inset-0 bg-black/40 backdrop-blur-[2px] z-50 flex items-center justify-center p-4">
              <motion.div
                initial={{ opacity: 0, scale: 0.95, y: 20 }}
                animate={{ opacity: 1, scale: 1, y: 0 }}
                exit={{ opacity: 0, scale: 0.95, y: 20 }}
                className="bg-bg-primary border border-border-secondary w-full max-w-[380px] rounded-3xl p-6 shadow-2xl relative"
              >
                <button 
                  onClick={() => setShowDayModal(false)}
                  className="absolute top-4 right-4 p-1 text-text-secondary hover:text-text-primary rounded-full hover:bg-bg-secondary transition-all"
                >
                  <IconX size={20} />
                </button>

                <div className="flex gap-2.5 items-center mb-6">
                  <div className="w-10 h-10 rounded-xl bg-primary/10 text-primary flex items-center justify-center font-bold text-sm">
                    Día {selectedDay}
                  </div>
                  <div>
                    <h3 className="text-base font-bold text-text-primary">Alineación Diaria</h3>
                    <p className="text-text-secondary text-xs">Paso del día para tu reprogramación</p>
                  </div>
                </div>

                <div className="space-y-5 mb-8">
                  <div className="bg-bg-secondary p-4 rounded-xl border border-border-primary relative overflow-hidden">
                    <span className="text-[10px] font-bold text-primary uppercase tracking-wider block mb-1">Decreto / Afirmación</span>
                    <p className="text-sm font-medium text-text-primary italic leading-relaxed">
                      "{activeChallenge.content[selectedDay - 1]?.affirmation || 'Decreto de manifestación activa.'}"
                    </p>
                  </div>

                  <div className="p-4 rounded-xl border border-border-secondary">
                    <span className="text-[10px] font-bold text-accent-gold uppercase tracking-wider block mb-1">Acción Física Alineda</span>
                    <p className="text-xs sm:text-sm text-text-secondary leading-relaxed">
                      {activeChallenge.content[selectedDay - 1]?.action || 'Realiza un acto de fe y amor propio hoy.'}
                    </p>
                  </div>
                </div>

                <button
                  onClick={handleCompleteDay}
                  disabled={savingDay}
                  className="w-full py-3.5 rounded-xl border-none text-[14px] font-bold tracking-wide transition-all bg-primary hover:bg-primary-dark text-white flex justify-center items-center gap-2 shadow-lg shadow-primary/10 disabled:opacity-50 active:scale-[0.98]"
                >
                  {savingDay ? <IconLoader2 size={18} className="animate-spin" /> : "✓ Hecho, Elevar Frecuencia"}
                </button>
              </motion.div>
            </div>
          )}
        </AnimatePresence>
      </div>
    );
  }

  // Vista Normal de Afirmaciones (Si no hay reto activo)
  return (
    <div className="absolute inset-0 p-4 sm:p-6 overflow-y-auto no-scrollbar pb-24">
      
      {/* Caja de Afirmación del día */}
      <div className="bg-bg-secondary rounded-2xl p-6 text-center border border-border-primary mb-6 min-h-[140px] flex items-center justify-center relative overflow-hidden shadow-inner">
        <div className="absolute inset-0 bg-gradient-to-br from-primary/5 to-transparent opacity-50"></div>
        <AnimatePresence mode="wait">
          <motion.p
            key={currentAffirmation}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ duration: 0.3 }}
            className="text-lg sm:text-xl font-medium text-primary leading-relaxed relative z-10"
          >
            "{currentAffirmation}"
          </motion.p>
        </AnimatePresence>
      </div>

      <div className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-3">¿En qué quieres enfocarte?</div>
      
      <div className="flex flex-wrap gap-2 mb-8">
        {displayedAreas.map((area) => (
          <button
            key={area.id}
            onClick={() => handleSelectArea(area.id)}
            className={twMerge(
              "px-4 py-2 rounded-full border text-sm transition-all duration-200 flex items-center gap-1.5 cursor-pointer",
              selectedArea === area.id
                ? "bg-primary/10 border-primary text-primary font-medium"
                : "bg-bg-primary border-border-secondary text-text-secondary hover:border-primary/50"
            )}
          >
            <span>{area.icon}</span> {area.label}
          </button>
        ))}
      </div>

      {generating ? (
        <div className="bg-bg-secondary/50 border border-border-primary rounded-2xl p-8 text-center flex flex-col items-center shadow-inner">
          <IconLoader2 size={32} className="animate-spin text-primary mb-4" />
          <h4 className="text-sm font-bold text-text-primary mb-1">Alineando tu frecuencia...</h4>
          <p className="text-xs text-text-secondary max-w-[240px] leading-relaxed">
            Nuestra IA está canalizando tu plan de manifestación cuántica de 30 días. Por favor espera unos segundos.
          </p>
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          <button 
            onClick={() => generateAffirmation()}
            className="w-full py-3.5 rounded-xl border-none text-[15px] font-medium cursor-pointer transition-all bg-primary hover:bg-primary-dark text-white flex justify-center items-center gap-2 shadow-md hover:shadow-lg active:scale-[0.98]"
          >
            <IconRefresh size={20} />
            Generar nueva afirmación
          </button>
          
          <button 
            onClick={handleCreateChallenge}
            className="w-full py-3.5 rounded-xl text-[15px] font-medium cursor-pointer transition-all bg-bg-secondary text-text-primary border border-border-secondary hover:bg-black/5 dark:hover:bg-white/5 flex justify-center items-center gap-2 active:scale-[0.98]"
          >
            Crear plan de 30 días con IA <IconSparkles size={18} className="text-accent-gold" />
          </button>
        </div>
      )}

      {/* MODAL DE ADVERTENCIA DE PAGO (UPGRADE) */}
      <AnimatePresence>
        {showUpgradeModal && (
          <div className="fixed inset-0 bg-black/40 backdrop-blur-[2px] z-50 flex items-center justify-center p-4">
            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 20 }}
              className="bg-bg-primary border border-border-secondary w-full max-w-[380px] rounded-3xl p-6 shadow-2xl relative text-center flex flex-col items-center"
            >
              <button 
                onClick={() => setShowUpgradeModal(false)}
                className="absolute top-4 right-4 p-1 text-text-secondary hover:text-text-primary rounded-full hover:bg-bg-secondary transition-all"
              >
                <IconX size={20} />
              </button>

              <div className="w-12 h-12 bg-accent-gold/20 text-accent-gold rounded-full flex items-center justify-center mb-4 shadow-[0_0_15px_rgba(250,204,21,0.2)] animate-bounce mt-2">
                <IconSparkles size={24} stroke={2.5} />
              </div>

              <h3 className="text-base font-bold text-text-primary mb-1.5">Reto de 30 Días con IA</h3>
              <p className="text-text-secondary text-xs mb-6 max-w-[260px] leading-relaxed">
                El creador de planes de reprogramación mental de 30 días guiado por Inteligencia Artificial es una característica exclusiva para usuarios Pro.
              </p>

              <Link 
                href="/paywall"
                className="w-full py-3.5 rounded-xl border-none text-[14px] font-bold tracking-wide transition-all bg-primary hover:bg-primary-dark text-white flex justify-center items-center gap-1.5 shadow-lg shadow-primary/10 active:scale-[0.98] mb-2 uppercase"
              >
                Obtener Plan Pro <IconArrowUpRight size={16} />
              </Link>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}
