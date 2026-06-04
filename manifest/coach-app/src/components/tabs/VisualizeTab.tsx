"use client";

import React, { useState, useEffect } from 'react';
import { IconPlayerPlayFilled, IconArrowUpRight, IconCurrencyDollar, IconCheck, IconX } from '@tabler/icons-react';
import { motion, AnimatePresence } from 'framer-motion';
import { twMerge } from 'tailwind-merge';

const areas = [
  { id: 'dinero', icon: '💰', label: 'Abundancia' },
  { id: 'amor', icon: '💗', label: 'Amor ideal' },
  { id: 'exito', icon: '🚀', label: 'Éxito' },
  { id: 'paz', icon: '🕊', label: 'Paz interior' },
];

export default function VisualizeTab() {
  // Estados: 'selection' | 'input' | 'meditation' | 'reward'
  const [mode, setMode] = useState<'selection' | 'input' | 'meditation' | 'reward'>('selection');
  const [selectedArea, setSelectedArea] = useState<string>('');
  const [amount, setAmount] = useState<string>('');
  const [timer, setTimer] = useState<number>(5); // 5 segundos para la demo
  const [displayAmount, setDisplayAmount] = useState(0);

  const handleAreaClick = (areaId: string) => {
    setSelectedArea(areaId);
    if (areaId === 'dinero') {
      setMode('input');
    }
  };

  const startMeditation = () => {
    if (!amount) return;
    setMode('meditation');
    setTimer(5);
  };

  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (mode === 'meditation' && timer > 0) {
      interval = setInterval(() => {
        setTimer((prev) => prev - 1);
      }, 1000);
    } else if (mode === 'meditation' && timer === 0) {
      // Finaliza la meditación y muestra la recompensa
      setMode('reward');
    }
    return () => clearInterval(interval);
  }, [mode, timer]);

  // Animación del número subiendo rápido en el reward
  useEffect(() => {
    if (mode === 'reward') {
      const targetAmount = parseInt(amount.replace(/,/g, ''), 10) || 5000;
      let current = 0;
      const step = Math.ceil(targetAmount / 50); // 50 pasos
      
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
  }, [mode, amount]);

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
            <div className="bg-bg-secondary rounded-2xl p-6 text-center border border-border-primary mb-6 shadow-sm flex flex-col items-center">
              <div className="relative inline-flex items-center justify-center w-16 h-16 rounded-full bg-primary/10 mb-5">
                <div className="absolute inset-0 rounded-full border-2 border-primary/30 animate-pulse-slow scale-110"></div>
                <div className="absolute inset-0 rounded-full border border-primary/20 animate-pulse-slow scale-125" style={{ animationDelay: '1s' }}></div>
                <IconPlayerPlayFilled size={28} className="text-primary ml-1" />
              </div>
              <h3 className="text-base font-medium mb-1.5 text-text-primary">Sesión de visualización guiada</h3>
              <p className="text-[13px] text-text-secondary mb-5 max-w-[200px]">5 minutos para conectar con tu versión más próspera</p>
              <button className="w-full py-3 rounded-xl border-none text-[14px] font-medium transition-all bg-primary hover:bg-primary-dark text-white flex justify-center items-center gap-2 shadow-md">
                Iniciar sesión guiada <IconArrowUpRight size={16} />
              </button>
            </div>

            <div className="text-xs font-semibold text-text-secondary uppercase tracking-wider mb-3 mt-8">¿Qué deseas manifestar hoy?</div>
            <div className="flex flex-wrap gap-2 mb-8">
              {areas.map((area) => (
                <button
                  key={area.id}
                  onClick={() => handleAreaClick(area.id)}
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
          </motion.div>
        )}

        {/* MODO INPUT: INGRESAR CANTIDAD */}
        {mode === 'input' && (
          <motion.div 
            key="input"
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.95 }}
            className="p-4 sm:p-6 h-full flex flex-col justify-center pb-24"
          >
            <button onClick={() => setMode('selection')} className="absolute top-4 left-4 p-2 text-text-secondary hover:text-text-primary">
              <IconX size={24} />
            </button>
            
            <div className="text-center mb-8">
              <span className="text-4xl mb-4 block">💰</span>
              <h2 className="text-xl font-medium text-text-primary mb-2">¿Cuánto deseas manifestar?</h2>
              <p className="text-text-secondary text-sm">El universo ama la claridad. Sé específico.</p>
            </div>

            <div className="relative mb-8 max-w-[250px] mx-auto w-full">
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

            <button 
              onClick={startMeditation}
              disabled={!amount}
              className="w-full py-4 rounded-xl text-[16px] font-medium transition-all bg-primary text-white flex justify-center items-center gap-2 shadow-lg disabled:opacity-50 active:scale-[0.98] max-w-[250px] mx-auto"
            >
              Iniciar Alineación <IconPlayerPlayFilled size={18} />
            </button>
          </motion.div>
        )}

        {/* MODO MEDITACIÓN: SIMULACIÓN */}
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
            
            <h2 className="text-xl font-medium mb-8 relative z-10 text-center">Respira profundo...<br/>Imagina que ya es tuyo.</h2>
            
            <div className="text-5xl font-light tracking-widest relative z-10 mb-8 opacity-80">
              00:0{timer}
            </div>

            <p className="text-white/50 text-sm absolute bottom-32 text-center max-w-[250px]">
              (Demo: Espera {timer} segundos para ver la manifestación)
            </p>
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
            {/* Estallido Dorado - Aura central */}
            <motion.div 
              initial={{ scale: 0, opacity: 1 }}
              animate={{ scale: 5, opacity: 0 }}
              transition={{ duration: 1.5, ease: "easeOut" }}
              className="absolute w-64 h-64 rounded-full bg-yellow-400 blur-2xl"
            />
            
            {/* Resplandor constante */}
            <motion.div 
              animate={{ scale: [1, 1.1, 1], opacity: [0.5, 0.8, 0.5] }}
              transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }}
              className="absolute w-full h-full bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-yellow-500/20 via-slate-950/80 to-slate-950"
            />

            {/* Partículas cayendo simuladas (podrían ser muchas, usamos unas cuantas para el efecto) */}
            {[...Array(12)].map((_, i) => (
              <motion.div
                key={i}
                initial={{ y: -100, x: Math.random() * 400 - 200, opacity: 0 }}
                animate={{ y: 800, x: (Math.random() * 400 - 200) + (Math.random() * 200 - 100), opacity: [0, 1, 1, 0], rotate: Math.random() * 360 }}
                transition={{ duration: 2 + Math.random() * 2, delay: Math.random() * 0.5, ease: "linear" }}
                className="absolute text-yellow-400 text-2xl z-0"
                style={{ left: '50%' }}
              >
                ✨
              </motion.div>
            ))}

            <motion.div 
              initial={{ scale: 0.5, opacity: 0, y: 50 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              transition={{ duration: 0.8, delay: 0.3, type: "spring" }}
              className="relative z-10 text-center flex flex-col items-center"
            >
              <div className="w-20 h-20 bg-yellow-400/20 border border-yellow-400/50 rounded-full flex items-center justify-center mb-6 shadow-[0_0_50px_rgba(250,204,21,0.4)]">
                <IconCheck size={40} className="text-yellow-400" />
              </div>
              
              <h2 className="text-yellow-400 text-xl font-medium tracking-widest uppercase mb-2">Vibración Alineada</h2>
              
              <div className="text-6xl font-bold text-white mb-6 tracking-tighter drop-shadow-lg flex items-center justify-center">
                <span className="text-yellow-400 mr-1">$</span>
                {displayAmount.toLocaleString()}
              </div>
              
              <p className="text-slate-300 text-[15px] mb-12 max-w-[250px] leading-relaxed">
                El universo ha recibido tu petición. El dinero ya viene en camino.
              </p>

              <button 
                onClick={() => { setMode('selection'); setAmount(''); }}
                className="px-8 py-3 rounded-full border border-yellow-400/50 text-yellow-400 hover:bg-yellow-400/10 transition-colors uppercase text-sm tracking-widest font-medium"
              >
                Agradecer y Volver
              </button>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
