"use client";

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { IconArrowUpRight, IconX, IconLoader2, IconSparkles, IconCheck, IconMinus } from '@tabler/icons-react';
import { motion, AnimatePresence } from 'framer-motion';
import { createClient } from '@/utils/supabase/client';
import { twMerge } from 'tailwind-merge';

type Goal = {
  id: string;
  title: string;
  description: string;
  progress: number;
  duration_days: number;
  created_at: string;
};

export default function GoalsTab() {
  const supabase = createClient();
  const [user, setUser] = useState<any>(null);
  const [goals, setGoals] = useState<Goal[]>([]);
  const [loading, setLoading] = useState(true);
  const [isPro, setIsPro] = useState(false);
  
  // Estados para modales
  const [showAddModal, setShowAddModal] = useState(false);
  const [showUpgradeModal, setShowUpgradeModal] = useState(false);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [durationDays, setDurationDays] = useState('90');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const fetchUserAndGoals = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        setUser(user);
        
        // Cargar perfil para ver tier
        const { data: profile } = await supabase
          .from('profiles')
          .select('subscription_tier')
          .eq('id', user.id)
          .single();
          
        if (profile) {
          setIsPro(profile.subscription_tier === 'pro');
        }

        // Cargar metas
        const { data, error } = await supabase
          .from('goals')
          .select('*')
          .order('created_at', { ascending: false });
        
        if (!error && data) {
          setGoals(data);
        }
      }
      setLoading(false);
    };

    fetchUserAndGoals();
  }, []);

  const handleOpenAdd = () => {
    // Si ya tiene 1 meta y no es PRO, mostrar advertencia de pago
    if (goals.length >= 1 && !isPro) {
      setShowUpgradeModal(true);
    } else {
      setShowAddModal(true);
    }
  };

  const handleAddGoal = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !user) return;
    setSaving(true);

    try {
      const duration = parseInt(durationDays, 10) || 90;
      const { data, error } = await supabase
        .from('goals')
        .insert([
          {
            title: title.trim(),
            description: description.trim(),
            duration_days: duration,
            progress: 0,
            user_id: user.id
          }
        ])
        .select();

      if (error) throw error;

      if (data && data.length > 0) {
        setGoals([data[0], ...goals]);
        setTitle('');
        setDescription('');
        setDurationDays('90');
        setShowAddModal(false);
      }
    } catch (err) {
      console.error("Error al guardar la meta:", err);
    } finally {
      setSaving(false);
    }
  };

  const calculateDaysRemaining = (createdAtStr: string, durationDays: number) => {
    const createdAt = new Date(createdAtStr);
    const targetDate = new Date(createdAt.getTime() + durationDays * 24 * 60 * 60 * 1000);
    const today = new Date();
    const diffTime = targetDate.getTime() - today.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    return diffDays > 0 ? `${diffDays} días restantes` : 'Plazo vencido';
  };

  const handleIncreaseProgress = async (goalId: string, currentProgress: number) => {
    const goal = goals.find(g => g.id === goalId);
    if (!goal) return;
    
    const completedDays = Math.round((currentProgress / 100) * goal.duration_days);
    if (completedDays >= goal.duration_days) return;
    
    const nextCompleted = completedDays + 1;
    const nextProgress = Math.min(Math.round((nextCompleted / goal.duration_days) * 100), 100);
    
    setGoals(prev => prev.map(g => g.id === goalId ? { ...g, progress: nextProgress } : g));

    const { error } = await supabase
      .from('goals')
      .update({ progress: nextProgress })
      .eq('id', goalId);
      
    if (error) {
      setGoals(prev => prev.map(g => g.id === goalId ? { ...g, progress: currentProgress } : g));
      console.error(error);
    }
  };

  const handleDecreaseProgress = async (goalId: string, currentProgress: number) => {
    const goal = goals.find(g => g.id === goalId);
    if (!goal) return;
    
    const completedDays = Math.round((currentProgress / 100) * goal.duration_days);
    if (completedDays <= 0) return;
    
    const nextCompleted = completedDays - 1;
    const nextProgress = Math.max(Math.round((nextCompleted / goal.duration_days) * 100), 0);
    
    setGoals(prev => prev.map(g => g.id === goalId ? { ...g, progress: nextProgress } : g));

    const { error } = await supabase
      .from('goals')
      .update({ progress: nextProgress })
      .eq('id', goalId);
      
    if (error) {
      setGoals(prev => prev.map(g => g.id === goalId ? { ...g, progress: currentProgress } : g));
      console.error(error);
    }
  };

  return (
    <div className="absolute inset-0 p-4 sm:p-6 overflow-y-auto no-scrollbar pb-24 bg-bg-primary">
      {loading ? (
        <div className="h-full flex items-center justify-center">
          <IconLoader2 size={32} className="animate-spin text-primary" />
        </div>
      ) : (
        <>
          <div className="flex flex-col gap-4 mb-6">
            {goals.length === 0 ? (
              <div className="text-center py-10 text-text-secondary text-sm bg-bg-secondary rounded-2xl border border-border-primary p-6">
                ✨ No tienes metas de manifestación creadas. ¡Define tu primera intención de 90 días abajo!
              </div>
            ) : (
              goals.map((goal, index) => {
                const completedDays = Math.round((goal.progress / 100) * goal.duration_days);
                const remainingDays = Math.max(goal.duration_days - completedDays, 0);

                return (
                  <motion.div 
                    key={goal.id}
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: index * 0.05 }}
                    className="bg-bg-secondary rounded-2xl p-5 border border-border-primary shadow-sm flex flex-col relative"
                  >
                    <div className="flex justify-between items-start mb-2">
                      <div className="inline-block text-[11px] font-bold px-2.5 py-1 rounded-full bg-primary/10 text-primary">
                        🎯 {goal.duration_days} {goal.duration_days === 1 ? 'día' : 'días'}
                      </div>
                      <div className="flex items-center gap-1.5">
                        {/* Botón Disminuir Progreso (-1 Día) */}
                        {completedDays > 0 && (
                          <motion.button
                            whileHover={{ scale: 1.05 }}
                            whileTap={{ scale: 0.95 }}
                            onClick={() => handleDecreaseProgress(goal.id, goal.progress)}
                            className="text-[11px] font-bold px-2.5 py-1.5 rounded-full border border-red-500/30 bg-red-500/5 text-red-400 hover:bg-red-500/10 hover:text-red-300 hover:border-red-500/50 transition-all flex items-center gap-1 cursor-pointer"
                            title="Restar 1 Día"
                          >
                            <IconMinus size={11} stroke={3} />
                            <span>-1 Día</span>
                          </motion.button>
                        )}

                        {/* Botón Aumentar Progreso (+1 Día) */}
                        <motion.button
                          whileHover={{ scale: goal.progress >= 100 ? 1 : 1.05 }}
                          whileTap={{ scale: goal.progress >= 100 ? 1 : 0.95 }}
                          onClick={() => handleIncreaseProgress(goal.id, goal.progress)}
                          disabled={goal.progress >= 100}
                          className={twMerge(
                            "text-[11px] font-bold px-3 py-1.5 rounded-full border transition-all flex items-center gap-1.5 cursor-pointer",
                            goal.progress >= 100 
                              ? "bg-green-500/20 border-green-500/30 text-green-400 font-bold shadow-[0_0_12px_rgba(34,197,94,0.15)]" 
                              : "bg-gradient-to-r from-indigo-500 to-pink-500 border-transparent text-white shadow-[0_0_15px_rgba(99,102,241,0.25)] hover:shadow-[0_0_20px_rgba(99,102,241,0.45)]"
                          )}
                        >
                          {goal.progress >= 100 ? (
                            <>
                              <IconCheck size={12} stroke={3} />
                              <span>Manifestada</span>
                            </>
                          ) : (
                            <>
                              <IconSparkles size={12} className="animate-pulse text-yellow-300" />
                              <span>+1 Día</span>
                            </>
                          )}
                        </motion.button>
                      </div>
                    </div>
                    <h3 className="text-[15px] font-bold mb-1 text-text-primary">{goal.title}</h3>
                    <p className="text-[13px] text-text-secondary mb-4 leading-relaxed">{goal.description}</p>
                    
                    <div className="h-2 bg-border-primary/50 dark:bg-white/5 rounded-full overflow-hidden mb-2 p-[2px] border border-white/5 shadow-inner">
                      <motion.div 
                        initial={{ width: 0 }}
                        animate={{ width: `${goal.progress}%` }}
                        transition={{ duration: 0.8, ease: "easeOut" }}
                        className="h-full bg-gradient-to-r from-indigo-500 via-pink-500 to-amber-500 rounded-full shadow-[0_0_10px_rgba(236,72,153,0.5)]"
                      />
                    </div>
                    <span className="text-[12px] text-text-secondary block font-medium">
                      {completedDays} de {goal.duration_days} {goal.duration_days === 1 ? 'día completado' : 'días completados'} · {remainingDays} {remainingDays === 1 ? 'día restante' : 'días restantes'}
                    </span>
                  </motion.div>
                );
              })
            )}
          </div>

          <button 
            onClick={handleOpenAdd}
            className="w-full py-3.5 rounded-xl border-none text-[15px] font-medium cursor-pointer transition-all bg-primary hover:bg-primary-dark text-white flex justify-center items-center gap-2 shadow-md hover:shadow-lg active:scale-[0.98]"
          >
            + Nueva meta <IconArrowUpRight size={18} />
          </button>
        </>
      )}

      {/* MODAL DE NUEVA META */}
      <AnimatePresence>
        {showAddModal && (
          <div className="fixed inset-0 bg-black/40 backdrop-blur-[2px] z-50 flex items-center justify-center p-4">
            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 20 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 20 }}
              className="bg-bg-primary border border-border-secondary w-full max-w-[400px] rounded-3xl p-6 shadow-2xl relative"
            >
              <button 
                onClick={() => setShowAddModal(false)}
                className="absolute top-4 right-4 p-1 text-text-secondary hover:text-text-primary rounded-full hover:bg-bg-secondary transition-all"
              >
                <IconX size={20} />
              </button>

              <div className="flex gap-2.5 items-center mb-6">
                <span className="text-2xl">🎯</span>
                <div>
                  <h3 className="text-base font-bold text-text-primary">Nueva Meta Cuántica</h3>
                  <p className="text-text-secondary text-xs">Define tu intención de forma específica</p>
                </div>
              </div>

              <form onSubmit={handleAddGoal} className="space-y-4">
                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-text-secondary uppercase tracking-wider block">¿Qué deseas manifestar?</label>
                  <input
                    type="text"
                    required
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    placeholder="Ej. Libertad financiera o Amor propio..."
                    className="w-full bg-bg-secondary/50 border border-border-secondary rounded-xl py-3 px-4 text-sm text-text-primary placeholder:text-text-secondary/50 focus:border-primary focus:outline-none transition-colors shadow-inner"
                    autoFocus
                  />
                </div>

                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-text-secondary uppercase tracking-wider block">Detalles / Acciones Alineadas</label>
                  <textarea
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    placeholder="Ej. Generar $3,000 al mes trabajando 4 horas al día..."
                    className="w-full bg-bg-secondary/50 border border-border-secondary rounded-xl py-3 px-4 text-sm text-text-primary placeholder:text-text-secondary/50 focus:border-primary focus:outline-none transition-colors shadow-inner min-h-[80px] resize-none"
                  />
                </div>

                <div className="space-y-1">
                  <label className="text-[11px] font-bold text-text-secondary uppercase tracking-wider block">Plazo de manifestación</label>
                  <select
                    value={durationDays}
                    onChange={(e) => setDurationDays(e.target.value)}
                    className="w-full bg-bg-secondary/50 border border-border-secondary rounded-xl py-3 px-4 text-sm text-text-primary focus:border-primary focus:outline-none transition-colors"
                  >
                    <option value="30">30 días (Corto plazo)</option>
                    <option value="90">90 días (Sintonía cuántica estándar)</option>
                    <option value="180">180 días (Largo plazo)</option>
                  </select>
                </div>

                <button
                  type="submit"
                  disabled={saving}
                  className="w-full py-3.5 rounded-xl border-none text-[14px] font-bold tracking-wide transition-all bg-primary hover:bg-primary-dark text-white flex justify-center items-center gap-2 shadow-lg shadow-primary/10 disabled:opacity-50 active:scale-[0.98] mt-2"
                >
                  {saving ? <IconLoader2 size={18} className="animate-spin" /> : "Guardar en mi realidad"}
                </button>
              </form>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

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

              <h3 className="text-base font-bold text-text-primary mb-1.5">Límite de metas alcanzado</h3>
              <p className="text-text-secondary text-xs mb-6 max-w-[260px] leading-relaxed">
                En el plan gratuito solo puedes seguir 1 meta a la vez. Actualiza a Pro para registrar metas de manifestación ilimitadas.
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
