"use client";

import React, { useState, useEffect } from 'react';
import { IconSun, IconMoon } from '@tabler/icons-react';

export default function Header() {
  const [theme, setTheme] = useState<'light' | 'dark'>('light');

  useEffect(() => {
    if (typeof window !== 'undefined') {
      const isDark = document.documentElement.classList.contains('dark');
      setTheme(isDark ? 'dark' : 'light');
    }
  }, []);

  const toggleTheme = () => {
    if (theme === 'dark') {
      document.documentElement.classList.remove('dark');
      localStorage.setItem('theme', 'light');
      setTheme('light');
    } else {
      document.documentElement.classList.add('dark');
      localStorage.setItem('theme', 'dark');
      setTheme('dark');
    }
  };

  return (
    <header className="bg-gradient-to-br from-primary-dark to-primary p-5 sm:p-6 text-white shadow-md relative overflow-hidden shrink-0 flex justify-between items-center">
      <div className="relative z-10">
        <h1 className="text-xl font-semibold mb-1 flex items-center gap-2">
          ✨ Manifiestas AI
        </h1>
        <p className="text-xs sm:text-sm opacity-85">Tu coach de manifestación personal — disponible 24/7</p>
      </div>
      
      {/* Botón de alternancia de tema */}
      <button 
        onClick={toggleTheme}
        className="relative z-10 p-2.5 rounded-full bg-white/10 hover:bg-white/20 transition-all text-white border border-white/10 shadow-inner"
        aria-label="Cambiar tema"
      >
        {theme === 'dark' ? <IconSun size={18} className="text-accent-gold" /> : <IconMoon size={18} className="text-white" />}
      </button>

      {/* Decorative background circle */}
      <div className="absolute -top-10 -right-10 w-32 h-32 bg-white/10 rounded-full blur-2xl animate-pulse-slow"></div>
    </header>
  );
}
