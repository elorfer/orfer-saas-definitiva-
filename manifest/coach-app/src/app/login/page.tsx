"use client";

import React, { useState } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import { 
  IconSparkles, 
  IconMail, 
  IconLock, 
  IconUser, 
  IconArrowRight, 
  IconLoader2 
} from "@tabler/icons-react";
import { createClient } from "@/utils/supabase/client";

export default function LoginPage() {
  const router = useRouter();
  const supabase = createClient();
  
  const [isSignUp, setIsSignUp] = useState(false);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [fullName, setFullName] = useState("");
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState("");
  const [successMsg, setSuccessMsg] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setErrorMsg("");
    setSuccessMsg("");

    try {
      if (isSignUp) {
        // Registro de usuario
        const { error } = await supabase.auth.signUp({
          email,
          password,
          options: {
            data: {
              full_name: fullName,
            },
          },
        });

        if (error) throw error;
        
        setSuccessMsg("¡Registro exitoso! Por favor verifica tu correo electrónico.");
        // Opcional: Auto login o redirección
      } else {
        // Login de usuario
        const { error } = await supabase.auth.signInWithPassword({
          email,
          password,
        });

        if (error) throw error;

        // Redirigir a la app
        router.push("/app");
        router.refresh();
      }
    } catch (err: any) {
      setErrorMsg(err.message || "Ocurrió un error inesperado.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-background text-text-primary flex flex-col justify-center items-center p-4 relative overflow-hidden select-none">
      
      {/* Círculos de brillo decorativos en el fondo */}
      <div className="absolute top-[-20%] left-[-10%] w-[500px] h-[500px] bg-primary/10 rounded-full blur-[100px] pointer-events-none"></div>
      <div className="absolute bottom-[-20%] right-[-10%] w-[500px] h-[500px] bg-accent-purple/10 rounded-full blur-[100px] pointer-events-none"></div>

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="w-full max-w-[440px] glass-card rounded-3xl p-6 sm:p-8 shadow-2xl relative border border-border-primary/80 z-10"
      >
        <div className="text-center mb-8 flex flex-col items-center">
          <div className="w-12 h-12 bg-primary/10 border border-primary/20 rounded-2xl flex items-center justify-center text-primary mb-4 shadow-sm">
            <IconSparkles size={24} className="animate-pulse" />
          </div>
          <h1 className="text-2xl font-black tracking-tight text-text-primary">
            {isSignUp ? "Crear cuenta cuántica" : "Iniciar Alineación"}
          </h1>
          <p className="text-text-secondary text-xs sm:text-sm mt-1 max-w-[280px]">
            {isSignUp 
              ? "Regístrate y comienza a reprogramar tu subconsciente hoy." 
              : "Ingresa tus credenciales para acceder a tu coach 24/7."}
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <AnimatePresence mode="popLayout" initial={false}>
            {isSignUp && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: "auto" }}
                exit={{ opacity: 0, height: 0 }}
                transition={{ duration: 0.2 }}
                className="space-y-1 overflow-hidden"
              >
                <label className="text-[11px] font-bold text-text-secondary uppercase tracking-wider block">Nombre Completo</label>
                <div className="relative">
                  <span className="absolute left-4 top-1/2 -translate-y-1/2 text-text-secondary">
                    <IconUser size={18} />
                  </span>
                  <input
                    type="text"
                    required={isSignUp}
                    value={fullName}
                    onChange={(e) => setFullName(e.target.value)}
                    placeholder="Tu nombre..."
                    className="w-full bg-bg-secondary/50 border border-border-secondary rounded-xl py-3 pl-11 pr-4 text-sm text-text-primary placeholder:text-text-secondary/50 focus:border-primary focus:outline-none transition-colors shadow-inner"
                  />
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          <div className="space-y-1">
            <label className="text-[11px] font-bold text-text-secondary uppercase tracking-wider block">Correo Electrónico</label>
            <div className="relative">
              <span className="absolute left-4 top-1/2 -translate-y-1/2 text-text-secondary">
                <IconMail size={18} />
              </span>
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="ejemplo@correo.com"
                className="w-full bg-bg-secondary/50 border border-border-secondary rounded-xl py-3 pl-11 pr-4 text-sm text-text-primary placeholder:text-text-secondary/50 focus:border-primary focus:outline-none transition-colors shadow-inner"
              />
            </div>
          </div>

          <div className="space-y-1">
            <div className="flex justify-between items-center">
              <label className="text-[11px] font-bold text-text-secondary uppercase tracking-wider block">Contraseña</label>
              {!isSignUp && (
                <button 
                  type="button"
                  className="text-[11px] font-semibold text-primary hover:underline"
                >
                  ¿La olvidaste?
                </button>
              )}
            </div>
            <div className="relative">
              <span className="absolute left-4 top-1/2 -translate-y-1/2 text-text-secondary">
                <IconLock size={18} />
              </span>
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full bg-bg-secondary/50 border border-border-secondary rounded-xl py-3 pl-11 pr-4 text-sm text-text-primary placeholder:text-text-secondary/50 focus:border-primary focus:outline-none transition-colors shadow-inner"
              />
            </div>
          </div>

          {errorMsg && (
            <motion.div 
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              className="p-3 bg-red-500/10 border border-red-500/20 text-red-500 text-xs rounded-xl text-center"
            >
              {errorMsg}
            </motion.div>
          )}

          {successMsg && (
            <motion.div 
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              className="p-3 bg-green-500/10 border border-green-500/20 text-green-600 dark:text-green-400 text-xs rounded-xl text-center"
            >
              {successMsg}
            </motion.div>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3.5 rounded-xl border-none text-[14px] font-bold tracking-wide transition-all bg-primary hover:bg-primary-dark text-white flex justify-center items-center gap-2 shadow-lg shadow-primary/10 disabled:opacity-50 active:scale-[0.98]"
          >
            {loading ? (
              <IconLoader2 size={18} className="animate-spin" />
            ) : (
              <>
                {isSignUp ? "Comenzar gratis" : "Ingresar"} 
                <IconArrowRight size={16} />
              </>
            )}
          </button>
        </form>

        <div className="mt-6 text-center text-xs text-text-secondary border-t border-border-primary/50 pt-4">
          {isSignUp ? (
            <>
              ¿Ya tienes cuenta?{" "}
              <button
                onClick={() => {
                  setIsSignUp(false);
                  setErrorMsg("");
                  setSuccessMsg("");
                }}
                className="font-bold text-primary hover:underline focus:outline-none"
              >
                Inicia sesión aquí
              </button>
            </>
          ) : (
            <>
              ¿No tienes cuenta?{" "}
              <button
                onClick={() => {
                  setIsSignUp(true);
                  setErrorMsg("");
                  setSuccessMsg("");
                }}
                className="font-bold text-primary hover:underline focus:outline-none"
              >
                Regístrate ahora
              </button>
            </>
          )}
        </div>
      </motion.div>
    </div>
  );
}
