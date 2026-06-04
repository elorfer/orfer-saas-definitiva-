"use client";

import React, { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { 
  IconSparkles, 
  IconCheck, 
  IconCreditCard, 
  IconLoader2, 
  IconArrowLeft,
  IconLock
} from "@tabler/icons-react";
import { createClient } from "@/utils/supabase/client";

export default function PaywallPage() {
  const router = useRouter();
  const supabase = createClient();

  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [paying, setPaying] = useState(false);
  const [errorMsg, setErrorMsg] = useState("");

  useEffect(() => {
    const checkUser = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        setUser(user);
      }
      setLoading(false);
    };
    checkUser();
  }, []);

  const handleSubscribe = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;
    setPaying(true);
    setErrorMsg("");

    try {
      const response = await fetch("/api/checkout", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || "Error al iniciar Stripe Checkout");
      }

      if (data.url) {
        // Redirigir a la pasarela segura de Stripe
        window.location.href = data.url;
      } else {
        throw new Error("No se recibió la URL de pago de Stripe");
      }
    } catch (err: any) {
      console.error("Error al procesar la suscripción:", err);
      setErrorMsg(err.message || "Ocurrió un error inesperado al procesar la suscripción.");
      setPaying(false);
    }
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
    router.push("/");
    router.refresh();
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <IconLoader2 size={32} className="animate-spin text-primary" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background text-text-primary flex flex-col justify-center items-center p-4 relative overflow-hidden select-none">
      
      {/* Brillos decorativos de fondo */}
      <div className="absolute top-[-10%] left-[-20%] w-[600px] h-[600px] bg-primary/8 rounded-full blur-[120px] pointer-events-none"></div>
      <div className="absolute bottom-[-10%] right-[-20%] w-[600px] h-[600px] bg-accent-gold/5 rounded-full blur-[120px] pointer-events-none"></div>

      {/* Botón de volver */}
      <button 
        onClick={handleLogout}
        className="absolute top-6 left-6 flex items-center gap-1.5 text-xs font-bold text-text-secondary hover:text-text-primary transition-colors cursor-pointer bg-bg-secondary border border-border-primary px-3 py-2 rounded-xl"
      >
        <IconArrowLeft size={16} /> Cerrar Sesión / Volver
      </button>

      <div className="w-full max-w-[860px] grid md:grid-cols-12 gap-8 items-stretch mt-12 md:mt-0 z-10">
        
        {/* Columna Izquierda: Beneficios del Plan Pro */}
        <motion.div 
          initial={{ opacity: 0, x: -20 }}
          animate={{ opacity: 1, x: 0 }}
          className="md:col-span-6 flex flex-col justify-center space-y-6"
        >
          <div className="space-y-3">
            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-accent-purple/10 border border-accent-purple/20 text-xs font-bold text-accent-purple uppercase tracking-wider">
              <IconSparkles size={14} className="animate-pulse" /> Frecuencia Plena
            </div>
            <h1 className="text-3xl sm:text-4xl font-black leading-tight text-text-primary">
              Activa tu <br />
              <span className="bg-gradient-to-r from-primary via-accent-purple to-accent-gold bg-clip-text text-transparent">
                Acceso Premium Pro
              </span>
            </h1>
            <p className="text-text-secondary text-sm leading-relaxed max-w-sm">
              Desbloquea el poder completo de tu mente y el universo. Suscríbete para empezar a usar la aplicación.
            </p>
          </div>

          <div className="space-y-4">
            {[
              { title: "Coach de IA Ilimitado", desc: "Habla sin restricciones de mensajes diarios." },
              { title: "Afirmaciones Personalizadas con IA", desc: "Decretos adaptados exactamente a tu vibración." },
              { title: "Visualización Cuántica Infinita", desc: "Usa el simulador financiero y de metas sin límites." },
              { title: "Diario de Gratitud Avanzado", desc: "Registra tus bendiciones y mantén un historial completo." }
            ].map((benefit, i) => (
              <div key={i} className="flex gap-3">
                <div className="w-5 h-5 rounded-full bg-accent-gold/20 text-accent-gold flex items-center justify-center shrink-0 mt-0.5">
                  <IconCheck size={14} stroke={3} />
                </div>
                <div>
                  <h4 className="font-bold text-sm text-text-primary">{benefit.title}</h4>
                  <p className="text-xs text-text-secondary">{benefit.desc}</p>
                </div>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Columna Derecha: Resumen y Botón de Pago */}
        <motion.div 
          initial={{ opacity: 0, x: 20 }}
          animate={{ opacity: 1, x: 0 }}
          className="md:col-span-6"
        >
          <div className="glass-card rounded-3xl p-6 sm:p-8 shadow-2xl border border-border-primary/80 h-full flex flex-col justify-between">
            <div>
              <div className="flex justify-between items-center mb-6">
                <div>
                  <h3 className="font-black text-lg text-text-primary">Plan Premium Mensual</h3>
                  <p className="text-xs text-text-secondary">Cancela cuando quieras</p>
                </div>
                <div className="text-right">
                  <span className="text-3xl font-black text-text-primary">$9.99</span>
                  <span className="text-xs text-text-secondary block">/ mes</span>
                </div>
              </div>

              <form onSubmit={handleSubscribe} className="space-y-6">
                <div className="bg-bg-secondary/40 border border-border-primary/50 p-4 rounded-2xl space-y-3">
                  <div className="flex justify-between text-xs text-text-secondary">
                    <span>Suscripción Mensual</span>
                    <span>$9.99</span>
                  </div>
                  <div className="flex justify-between text-xs text-text-secondary">
                    <span>Impuestos</span>
                    <span>$0.00</span>
                  </div>
                  <div className="border-t border-border-primary/50 pt-3 flex justify-between text-sm font-bold text-text-primary">
                    <span>Total hoy</span>
                    <span>$9.99</span>
                  </div>
                </div>

                {errorMsg && (
                  <div className="p-3 bg-red-500/10 border border-red-500/20 text-red-500 text-xs rounded-xl text-center">
                    {errorMsg}
                  </div>
                )}

                <div className="flex items-start gap-2.5 text-[11px] text-text-secondary leading-relaxed bg-bg-secondary/50 p-3.5 rounded-xl border border-border-primary/50">
                  <IconLock size={16} className="shrink-0 text-green-500 mt-0.5" />
                  <span>
                    El pago se procesará de forma segura a través de **Stripe**. Al hacer clic abajo, serás redirigido a su pasarela de pago oficial.
                  </span>
                </div>

                <button
                  type="submit"
                  disabled={paying}
                  className="w-full py-4 rounded-xl border-none text-[13px] font-bold tracking-wide transition-all bg-primary hover:bg-primary-dark text-white flex justify-center items-center gap-2 shadow-lg shadow-primary/10 disabled:opacity-50 active:scale-[0.98] uppercase"
                >
                  {paying ? (
                    <IconLoader2 size={18} className="animate-spin" />
                  ) : (
                    <>
                      Proceder al Pago <IconCreditCard size={18} />
                    </>
                  )}
                </button>
              </form>
            </div>

            <div className="text-center text-[10px] text-text-secondary mt-6">
              🔒 Garantía de satisfacción de 7 días. Si no estás feliz, solicita la devolución sin preguntas.
            </div>
          </div>
        </motion.div>

      </div>
    </div>
  );
}
