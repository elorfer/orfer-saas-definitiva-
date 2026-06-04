"use client";

import React, { useState, useEffect } from 'react';
import { IconArrowUpRight, IconX, IconLoader2, IconCheck } from '@tabler/icons-react';
import { motion, AnimatePresence } from 'framer-motion';
import { createClient } from '@/utils/supabase/client';

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
  
  // Estados para nueva meta
  const [showAddModal, setShowAddModal] = useState(false);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [durationDays, setDurationDays] = useState('90');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const fetchUserAndGoals = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        setUser(user);
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
        // Reset form
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
    if (currentProgress >= 100) return;
    const nextProgress = Math.min(currentProgress + 10, 100);
    
    // Optimista local update
    setGoals(prev => prev.map(g => g.id === goalId ? { ...g, progress: nextProgress } : g));

    const { error } = await supabase
      .from('goals')
      .update({ progress: nextProgress })
      .eq('id', goalId);
      
    if (error) {
      // Revertir en caso de error
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
              goals.map((goal, index) => (
                <motion.div 
                  key={goal.id}
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: index * 0.05 }}
                  className="bg-bg-secondary rounded-2xl p-5 border border-border-primary shadow-sm flex flex-col relative"
                >
                  <div className="flex justify-between items-start mb-2">
                    <div className="inline-block text-[11px] font-bold px-2.5 py-1 rounded-full bg-primary/10 text-primary">
                      🎯 {goal.duration_days} días
                    </div>
                    <button
                      onClick={() => handleIncreaseProgress(goal.id, goal.progress)}
                      disabled={goal.progress >= 100}
                      className={`text-[11px] font-bold px-2.5 py-1 rounded-full border transition-all ${
                        goal.progress >= 100 
                          ? "bg-green-500/10 border-green-500/20 text-green-600 dark:text-green-400" 
                          : "border-primary/20 bg-primary/5 text-primary hover:bg-primary hover:text-white"
                      }`}
                    >
                      {goal.progress >= 100 ? "✓ Manifestada" : "+ 10% Progreso"}
                    </button>
                  </div>
                  <h3 className="text-[15px] font-bold mb-1 text-text-primary">{goal.title}</h3>
                  <p className="text-[13px] text-text-secondary mb-4 leading-relaxed">{goal.description}</p>
                  
                  <div className="h-1.5 bg-border-primary rounded-full overflow-hidden mb-2">
                    <motion.div 
                      initial={{ width: 0 }}
                      animate={{ width: `${goal.progress}%` }}
                      transition={{ duration: 0.8, ease: "easeOut" }}
                      className="h-full bg-primary rounded-full"
                    />
                  </div>
                  <span className="text-[12px] text-text-secondary block font-medium">
                    {goal.progress}% completado · {calculateDaysRemaining(goal.created_at, goal.duration_days)}
                  </span>
                </motion.div>
              ))
            )}
          </div>

          <button 
            onClick={() => setShowAddModal(true)}
            className="w-full py-3.5 rounded-xl border-none text-[15px] font-medium cursor-pointer transition-all bg-primary hover:bg-primary-dark text-white flex justify-center items-center gap-2 shadow-md hover:shadow-lg active:scale-[0.98]"
          >
            + Nueva meta <IconArrowUpRight size={18} />
          </button>
        </>
      )}

      {/* MODAL ANIMADO DE NUEVA META */}
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
    </div>
  );
}
