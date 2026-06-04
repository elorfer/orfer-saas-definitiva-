"use client";

import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { IconRefresh, IconArrowUpRight } from '@tabler/icons-react';
import { twMerge } from 'tailwind-merge';

const afirmacionesData: Record<string, string[]> = {
  dinero: ["El dinero fluye hacia mí de forma fácil y abundante", "Soy un imán para la prosperidad y las oportunidades financieras", "Merezco abundancia y la recibo con gratitud", "Mi energía creativa genera ingresos de múltiples fuentes", "La riqueza es mi estado natural y la abrazo completamente"],
  amor: ["Soy digno/a de un amor profundo y auténtico", "Mi corazón está abierto para dar y recibir amor", "Atraigo relaciones saludables y llenas de alegría", "El amor que busco también me está buscando a mí", "Me amo profundamente y ese amor atrae amor verdadero"],
  salud: ["Mi cuerpo es fuerte, sano y lleno de vitalidad", "Cada célula de mi ser vibra en perfecta salud", "Merezco sentirme increíble en cuerpo y mente", "Mi energía es renovada y radiante cada día", "Confío plenamente en la sabiduría de mi cuerpo"],
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
  const [selectedArea, setSelectedArea] = useState<string>('abundancia');
  const [currentAffirmation, setCurrentAffirmation] = useState(afirmacionesData['abundancia'][0]);

  const generateAffirmation = (area = selectedArea) => {
    if (!area) return;
    const list = afirmacionesData[area];
    const newAffirmation = list[Math.floor(Math.random() * list.length)];
    setCurrentAffirmation(newAffirmation);
  };

  const handleSelectArea = (area: string) => {
    setSelectedArea(area);
    generateAffirmation(area);
  };

  return (
    <div className="absolute inset-0 p-4 sm:p-6 overflow-y-auto no-scrollbar pb-24">
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
        {areas.map((area) => (
          <button
            key={area.id}
            onClick={() => handleSelectArea(area.id)}
            className={twMerge(
              "px-4 py-2 rounded-full border text-sm transition-all duration-200 flex items-center gap-1.5",
              selectedArea === area.id
                ? "bg-primary/10 border-primary text-primary font-medium"
                : "bg-bg-primary border-border-secondary text-text-secondary hover:border-primary/50"
            )}
          >
            <span>{area.icon}</span> {area.label}
          </button>
        ))}
      </div>

      <div className="flex flex-col gap-3">
        <button 
          onClick={() => generateAffirmation()}
          className="w-full py-3.5 rounded-xl border-none text-[15px] font-medium cursor-pointer transition-all bg-primary hover:bg-primary-dark text-white flex justify-center items-center gap-2 shadow-md hover:shadow-lg active:scale-[0.98]"
        >
          <IconRefresh size={20} />
          Generar nueva afirmación
        </button>
        
        <button className="w-full py-3.5 rounded-xl text-[15px] font-medium cursor-pointer transition-all bg-bg-secondary text-text-primary border border-border-secondary hover:bg-black/5 dark:hover:bg-white/5 flex justify-center items-center gap-2 active:scale-[0.98]">
          Crear plan de 30 días <IconArrowUpRight size={18} />
        </button>
      </div>
    </div>
  );
}
