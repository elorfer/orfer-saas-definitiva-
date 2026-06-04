"use client";

import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

type GratitudeEntry = {
  id: string;
  text: string;
  timeAgo: string;
};

export default function GratitudeTab() {
  const [text, setText] = useState('');
  const [entries, setEntries] = useState<GratitudeEntry[]>([
    { id: '1', text: 'Mi salud y la energía que tengo cada mañana', timeAgo: 'Hace 1 día' },
    { id: '2', text: 'Una oportunidad nueva que llegó inesperadamente', timeAgo: 'Hace 2 días' },
    { id: '3', text: 'Las personas que me apoyan sin condiciones', timeAgo: 'Hace 3 días' }
  ]);

  const handleAdd = () => {
    if (!text.trim()) return;
    const newEntry: GratitudeEntry = {
      id: Date.now().toString(),
      text: text.trim(),
      timeAgo: 'Ahora mismo'
    };
    setEntries([newEntry, ...entries]);
    setText('');
  };

  return (
    <div className="absolute inset-0 p-4 sm:p-6 overflow-y-auto no-scrollbar pb-24">
      <div className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-3">¿Por qué estás agradecid@ hoy?</div>
      
      <textarea
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="Hoy estoy agradecid@ por..."
        className="w-full p-4 rounded-xl border border-border-secondary text-[14px] min-h-[100px] resize-none bg-bg-primary text-text-primary outline-none focus:border-primary transition-colors leading-relaxed mb-3 shadow-inner"
      />
      
      <button 
        onClick={handleAdd}
        disabled={!text.trim()}
        className="w-full py-3.5 rounded-xl border-none text-[15px] font-medium cursor-pointer transition-all bg-primary hover:bg-primary-dark text-white flex justify-center items-center shadow-md disabled:opacity-50 disabled:cursor-not-allowed active:scale-[0.98]"
      >
        Guardar en mi diario
      </button>

      <div className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-4 mt-8">Entradas recientes</div>
      
      <div className="flex flex-col gap-3">
        <AnimatePresence>
          {entries.map((entry) => (
            <motion.div
              key={entry.id}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, scale: 0.9 }}
              className="bg-bg-secondary rounded-xl p-4 border-l-4 border-l-primary border-y border-r border-y-border-primary border-r-border-primary shadow-sm"
            >
              <p className="text-[14px] leading-relaxed flex gap-2">
                <span className="shrink-0">💜</span> 
                <span className="text-text-primary">{entry.text}</span>
              </p>
              <span className="text-[11px] text-text-secondary mt-2 block ml-6">
                {entry.timeAgo}
              </span>
            </motion.div>
          ))}
        </AnimatePresence>
      </div>
    </div>
  );
}
