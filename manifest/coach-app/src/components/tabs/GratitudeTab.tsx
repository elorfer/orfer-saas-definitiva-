"use client";

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { motion, AnimatePresence } from 'framer-motion';
import { IconLoader2, IconTrash, IconX, IconSparkles, IconArrowUpRight } from '@tabler/icons-react';
import { createClient } from '@/utils/supabase/client';

type GratitudeEntry = {
  id: string;
  text: string;
  created_at: string;
};

export default function GratitudeTab() {
  const supabase = createClient();
  const [user, setUser] = useState<any>(null);
  const [text, setText] = useState('');
  const [entries, setEntries] = useState<GratitudeEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [isPro, setIsPro] = useState(false);
  const [showUpgradeModal, setShowUpgradeModal] = useState(false);

  useEffect(() => {
    const fetchUserAndEntries = async () => {
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

        // Cargar registros
        const { data, error } = await supabase
          .from('gratitude_entries')
          .select('*')
          .order('created_at', { ascending: false });
        
        if (!error && data) {
          setEntries(data);
        }
      }
      setLoading(false);
    };

    fetchUserAndEntries();
  }, []);

  const handleAdd = async () => {
    if (!text.trim() || !user) return;

    // Si ya tiene 3 registros y no es PRO, bloquear con paywall
    if (entries.length >= 3 && !isPro) {
      setShowUpgradeModal(true);
      return;
    }

    setSaving(true);

    try {
      const { data, error } = await supabase
        .from('gratitude_entries')
        .insert([
          {
            text: text.trim(),
            user_id: user.id
          }
        ])
        .select();

      if (error) throw error;

      if (data && data.length > 0) {
        setEntries([data[0], ...entries]);
        setText('');
      }
    } catch (err) {
      console.error("Error al guardar en el diario:", err);
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id: string) => {
    setEntries(prev => prev.filter(e => e.id !== id));

    const { error } = await supabase
      .from('gratitude_entries')
      .delete()
      .eq('id', id);

    if (error) {
      console.error("Error al eliminar la entrada:", error);
      const { data } = await supabase
        .from('gratitude_entries')
        .select('*')
        .order('created_at', { ascending: false });
      if (data) setEntries(data);
    }
  };

  const formatTimeAgo = (createdAtStr: string) => {
    const createdAt = new Date(createdAtStr);
    const now = new Date();
    const diffMs = now.getTime() - createdAt.getTime();
    const diffMins = Math.floor(diffMs / (1000 * 60));
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

    if (diffMins < 1) return 'Ahora mismo';
    if (diffMins < 60) return `Hace ${diffMins} min`;
    if (diffHours < 24) return `Hace ${diffHours} ${diffHours === 1 ? 'hora' : 'horas'}`;
    return `Hace ${diffDays} ${diffDays === 1 ? 'día' : 'días'}`;
  };

  return (
    <div className="absolute inset-0 p-4 sm:p-6 overflow-y-auto no-scrollbar pb-24 bg-bg-primary">
      {loading ? (
        <div className="h-full flex items-center justify-center">
          <IconLoader2 size={32} className="animate-spin text-primary" />
        </div>
      ) : (
        <>
          <div className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-3">¿Por qué estás agradecid@ hoy?</div>
          
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            disabled={saving}
            placeholder="Hoy estoy agradecid@ por..."
            className="w-full p-4 rounded-xl border border-border-secondary text-[14px] min-h-[100px] resize-none bg-bg-primary text-text-primary outline-none focus:border-primary transition-colors leading-relaxed mb-3 shadow-inner"
          />
          
          <button 
            onClick={handleAdd}
            disabled={!text.trim() || saving}
            className="w-full py-3.5 rounded-xl border-none text-[15px] font-bold tracking-wide transition-all bg-primary hover:bg-primary-dark text-white flex justify-center items-center shadow-md disabled:opacity-50 disabled:cursor-not-allowed active:scale-[0.98]"
          >
            {saving ? <IconLoader2 size={18} className="animate-spin" /> : "Guardar en mi diario"}
          </button>

          <div className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-4 mt-8">Entradas recientes</div>
          
          <div className="flex flex-col gap-3">
            {entries.length === 0 ? (
              <div className="text-center py-6 text-text-secondary text-sm bg-bg-secondary rounded-2xl border border-border-primary p-4">
                🌿 Tu diario está vacío. Escribe algo por lo que sientas gratitud arriba.
              </div>
            ) : (
              <div className="flex flex-col gap-3">
                <AnimatePresence>
                  {entries.map((entry) => (
                    <motion.div
                      key={entry.id}
                      initial={{ opacity: 0, x: -20 }}
                      animate={{ opacity: 1, x: 0 }}
                      exit={{ opacity: 0, scale: 0.9 }}
                      className="bg-bg-secondary rounded-xl p-4 border-l-4 border-l-primary border-y border-r border-y-border-primary border-r-border-primary shadow-sm flex justify-between items-start group"
                    >
                      <div className="flex-1 pr-2">
                        <p className="text-[14px] leading-relaxed flex gap-2">
                          <span className="shrink-0">💜</span> 
                          <span className="text-text-primary">{entry.text}</span>
                        </p>
                        <span className="text-[11px] text-text-secondary mt-2 block ml-6">
                          {formatTimeAgo(entry.created_at)}
                        </span>
                      </div>
                      
                      <button
                        onClick={() => handleDelete(entry.id)}
                        className="opacity-0 group-hover:opacity-100 p-1 text-text-secondary hover:text-red-500 rounded hover:bg-black/5 dark:hover:bg-white/5 transition-all self-center"
                        title="Eliminar de mi diario"
                      >
                        <IconTrash size={16} />
                      </button>
                    </motion.div>
                  ))}
                </AnimatePresence>
              </div>
            )}
          </div>
        </>
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

              <h3 className="text-base font-bold text-text-primary mb-1.5">Límite de diario alcanzado</h3>
              <p className="text-text-secondary text-xs mb-6 max-w-[260px] leading-relaxed">
                En el plan gratuito solo puedes registrar hasta 3 entradas en tu diario de gratitud. Actualiza a Pro para escribir de manera ilimitada.
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
