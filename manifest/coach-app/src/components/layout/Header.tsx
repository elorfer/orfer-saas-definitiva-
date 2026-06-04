"use client";

import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { IconSun, IconMoon, IconSparkles } from '@tabler/icons-react';
import { createClient } from '@/utils/supabase/client';

export default function Header() {
  const supabase = createClient();
  const [theme, setTheme] = useState<'light' | 'dark'>('light');
  const [subscriptionTier, setSubscriptionTier] = useState<string>('free');

  useEffect(() => {
    if (typeof window !== 'undefined') {
      const isDark = document.documentElement.classList.contains('dark');
      setTheme(isDark ? 'dark' : 'light');
    }
  }, []);

  useEffect(() => {
    const fetchTier = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        const { data } = await supabase
          .from('profiles')
          .select('subscription_tier')
          .eq('id', user.id)
          .single();
        if (data) {
          setSubscriptionTier(data.subscription_tier);
        }
      }
    };
    fetchTier();
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
      
      <div className="relative z-10 flex items-center gap-3">
        {/* Botón/Badge de Suscripción */}
        {subscriptionTier === 'pro' ? (
          <span className="hidden sm:inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-accent-gold/20 border border-accent-gold/30 text-xs font-bold text-accent-gold shadow-sm animate-pulse-slow">
            <IconSparkles size={12} /> Premium Pro
          </span>
        ) : (
          <Link 
            href="/paywall"
            className="inline-flex items-center gap-1 px-3 py-1.5 rounded-full bg-accent-gold hover:bg-yellow-500 text-slate-950 text-xs font-extrabold shadow-md transition-all active:scale-95"
          >
            <IconSparkles size={12} stroke={3} /> Subir a Pro
          </Link>
        )}

        {/* Botón de alternancia de tema */}
        <button 
          onClick={toggleTheme}
          className="p-2.5 rounded-full bg-white/10 hover:bg-white/20 transition-all text-white border border-white/10 shadow-inner"
          aria-label="Cambiar tema"
        >
          {theme === 'dark' ? <IconSun size={18} className="text-accent-gold" /> : <IconMoon size={18} className="text-white" />}
        </button>
      </div>

      {/* Decorative background circle */}
      <div className="absolute -top-10 -right-10 w-32 h-32 bg-white/10 rounded-full blur-2xl animate-pulse-slow"></div>
    </header>
  );
}
