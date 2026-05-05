'use client';

import { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Send, Copy, RotateCcw, MessageSquare, ShieldCheck, Zap, Star, Gem, Crown, Check } from 'lucide-react';

export default function AsistenteVentas() {
  const [input, setInput] = useState('');
  const [response, setResponse] = useState('');
  const [loading, setLoading] = useState(false);
  const [copied, setCopied] = useState(false);

  const handleGenerate = async () => {
    if (!input.trim()) return;
    setLoading(true);
    setResponse('');
    
    try {
      const res = await fetch('/api/asistente', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: input })
      });
      
      const data = await res.json();
      if (data.reply) {
        setResponse(data.reply);
      } else {
        alert(data.error || 'Error al generar respuesta');
      }
    } catch (err) {
      alert('Error de conexión');
    } finally {
      setLoading(false);
    }
  };

  const copyToClipboard = () => {
    navigator.clipboard.writeText(response);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const clear = () => {
    setInput('');
    setResponse('');
  };

  const quickExamples = [
    "¿Cuánto cuesta el plan pro?",
    "Hola, quiero información de los servicios",
    "¿Los derechos de la canción son míos?",
    "Está muy caro, no tengo tanto dinero",
    "¿Cuánto tiempo tardan en entregar?",
    "¿La voz la hace una IA o un humano?"
  ];

  return (
    <div className="min-h-screen bg-[#050505] text-white p-4 md:p-8 font-sans">
      <div className="max-w-3xl mx-auto">
        
        {/* Header */}
        <header className="flex items-center gap-4 mb-8">
          <div className="w-12 h-12 rounded-full bg-gradient-to-br from-coffee-medium to-coffee-light flex items-center justify-center text-2xl shadow-lg shadow-coffee-medium/20">
            🤖
          </div>
          <div>
            <h1 className="text-xl md:text-2xl font-black tracking-tight text-white">Struky Sales Assistant</h1>
            <p className="text-gray-500 text-xs md:text-sm uppercase tracking-widest font-bold">Powered by Claude 3.5 Sonnet</p>
          </div>
        </header>

        {/* Input Card */}
        <div className="bg-white/5 border border-white/10 rounded-3xl p-6 mb-6 backdrop-blur-xl">
          <label className="block text-[10px] uppercase tracking-[0.2em] font-black text-gray-500 mb-4">Mensaje del Cliente</label>
          <textarea 
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Pega aquí lo que te escribió el cliente por WhatsApp..."
            className="w-full bg-black/40 border border-white/5 rounded-2xl p-4 text-sm min-h-[120px] focus:outline-none focus:border-coffee-medium/50 transition-colors resize-none placeholder:text-gray-700"
          />
          
          <div className="flex flex-wrap gap-2 mt-4">
            {quickExamples.map((ex, i) => (
              <button 
                key={i}
                onClick={() => setInput(ex)}
                className="text-[10px] px-3 py-1.5 rounded-full border border-white/5 bg-white/5 hover:bg-white/10 hover:border-white/20 transition-all text-gray-400"
              >
                {ex}
              </button>
            ))}
          </div>

          <button 
            onClick={handleGenerate}
            disabled={loading || !input.trim()}
            className="w-full mt-6 bg-gradient-to-r from-coffee-medium to-coffee-light text-black font-black py-4 rounded-2xl flex items-center justify-center gap-3 hover:opacity-90 transition-all active:scale-[0.98] disabled:opacity-30 disabled:pointer-events-none"
          >
            {loading ? (
              <div className="w-5 h-5 border-2 border-black/20 border-t-black rounded-full animate-spin" />
            ) : (
              <>
                <Send className="w-4 h-4" />
                GENERAR RESPUESTA INTELIGENTE
              </>
            )}
          </button>
        </div>

        {/* Result Area */}
        <AnimatePresence>
          {response && (
            <motion.div 
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              className="bg-white/5 border border-coffee-medium/30 rounded-3xl p-6 mb-8 shadow-2xl shadow-coffee-medium/5"
            >
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
                  <span className="text-[10px] font-black uppercase tracking-widest text-coffee-light">Respuesta Sugerida</span>
                </div>
                <div className="flex gap-2">
                  <button 
                    onClick={copyToClipboard}
                    className={`flex items-center gap-2 px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${copied ? 'bg-green-500 text-black' : 'bg-white/10 text-white hover:bg-white/20'}`}
                  >
                    {copied ? <Check className="w-3 h-3" /> : <Copy className="w-3 h-3" />}
                    {copied ? 'Copiado' : 'Copiar'}
                  </button>
                  <button 
                    onClick={clear}
                    className="p-2 rounded-xl bg-white/5 text-gray-500 hover:bg-white/10 transition-all"
                  >
                    <RotateCcw className="w-4 h-4" />
                  </button>
                </div>
              </div>
              <div className="bg-black/40 rounded-2xl p-5 text-sm md:text-base leading-relaxed text-gray-200 whitespace-pre-wrap border border-white/5">
                {response}
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Plans Reference Bar */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <PlanCard icon={<Zap className="w-3 h-3" />} name="Starter" price="37" />
          <PlanCard icon={<Star className="w-3 h-3" />} name="Pro Master" price="50" highlight />
          <PlanCard icon={<Gem className="w-3 h-3" />} name="Premium" price="97" />
          <PlanCard icon={<Crown className="w-3 h-3" />} name="Elite" price="147" />
        </div>

        <footer className="text-center mt-12 pb-8">
          <p className="text-[10px] text-gray-700 uppercase tracking-[0.3em] font-black">
            Struky Studios · Uso Interno Exclusivo
          </p>
        </footer>

      </div>
    </div>
  );
}

function PlanCard({ icon, name, price, highlight = false }: { icon: any, name: string, price: string, highlight?: boolean }) {
  return (
    <div className={`p-4 rounded-2xl border ${highlight ? 'border-coffee-medium/50 bg-coffee-medium/5' : 'border-white/5 bg-white/2'} flex flex-col items-center gap-1`}>
      <div className={`w-6 h-6 rounded-lg flex items-center justify-center mb-1 ${highlight ? 'bg-coffee-medium text-black' : 'bg-white/10 text-gray-400'}`}>
        {icon}
      </div>
      <p className="text-[8px] uppercase tracking-widest text-gray-500 font-bold">{name}</p>
      <p className="text-sm font-black text-white">${price}</p>
    </div>
  );
}
