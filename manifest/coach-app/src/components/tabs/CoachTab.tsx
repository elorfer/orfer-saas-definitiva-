"use client";

import React, { useState, useRef, useEffect } from 'react';
import { IconSend } from '@tabler/icons-react';
import { motion, AnimatePresence } from 'framer-motion';

type Message = {
  id: string;
  text: string;
  sender: 'ai' | 'user';
};

const topics = ['dinero', 'amor', 'salud'] as const;

const aiReplies: Record<string, string[]> = {
  dinero: [
    "Perfecto. Tu relación con el dinero refleja tu relación contigo mismo. Empieza visualizando que ya tienes lo que deseas. ¿Cuánto quieres generar en los próximos 90 días?",
    "El dinero es energía. Para atraerlo, primero debemos eliminar creencias limitantes. ¿Qué pensamiento negativo sobre el dinero repites más?"
  ],
  amor: [
    "El amor comienza dentro de ti. Cuando te amas completamente, atraes lo que mereces. ¿Cómo te describes en una relación ideal?",
    "Para manifestar amor, describe con detalle cómo te sientes (no cómo es la persona). Las emociones son el imán más poderoso del universo."
  ],
  salud: [
    "Tu cuerpo escucha cada pensamiento. Empieza agradeciéndole por todo lo que ya hace por ti. ¿Qué aspecto de tu salud quieres transformar?",
    "La salud se manifiesta cuando alineamos mente, cuerpo y emoción. ¿Qué hábito pequeño podrías empezar hoy?"
  ],
  default: [
    "Gracias por compartir eso conmigo. Tu intención ya es el primer paso de la manifestación. Cuéntame más: ¿cómo te sentirías cuando eso ya sea una realidad?",
    "Eso que describes tiene mucho poder. La clave está en sentirlo como si ya fuera real. ¿Estás list@ para crear afirmaciones personalizadas para esto?",
    "Hermoso. El universo ya está organizando todo para que recibas eso. ¿Quieres que creemos un plan de manifestación de 30 días juntos?"
  ]
};

export default function CoachTab() {
  const [messages, setMessages] = useState<Message[]>([
    { id: '1', text: '👋 Hola! Soy tu coach de manifestación. ¿En qué área de tu vida quieres enfocarte hoy — dinero, amor, salud, o algo más?', sender: 'ai' }
  ]);
  const [inputValue, setInputValue] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages, isTyping]);

  const handleSend = () => {
    if (!inputValue.trim()) return;

    const userMsg: Message = { id: Date.now().toString(), text: inputValue.trim(), sender: 'user' };
    setMessages((prev) => [...prev, userMsg]);
    setInputValue('');
    setIsTyping(true);

    setTimeout(() => {
      const lower = userMsg.text.toLowerCase();
      let key = 'default';
      topics.forEach((t) => {
        if (lower.includes(t)) key = t;
      });

      const replies = aiReplies[key] || aiReplies.default;
      const replyText = replies[Math.floor(Math.random() * replies.length)];
      
      const aiMsg: Message = { id: (Date.now() + 1).toString(), text: replyText, sender: 'ai' };
      setMessages((prev) => [...prev, aiMsg]);
      setIsTyping(false);
    }, 1200);
  };

  return (
    <div className="flex flex-col h-full absolute inset-0 p-4 sm:p-6 pb-24">
      <div className="flex-1 overflow-y-auto pr-2 no-scrollbar flex flex-col gap-4 pb-4">
        <AnimatePresence initial={false}>
          {messages.map((msg) => (
            <motion.div
              key={msg.id}
              initial={{ opacity: 0, y: 10, scale: 0.95 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              className={`max-w-[85%] p-3.5 rounded-2xl text-[15px] leading-relaxed shadow-sm ${
                msg.sender === 'ai'
                  ? 'bg-bg-secondary border border-border-primary rounded-bl-none self-start'
                  : 'bg-primary text-white rounded-br-none self-end'
              }`}
            >
              {msg.text}
            </motion.div>
          ))}
        </AnimatePresence>
        
        {isTyping && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            className="bg-bg-secondary border border-border-primary p-3.5 rounded-2xl rounded-bl-none self-start w-16 flex justify-center items-center gap-1 h-[50px]"
          >
            <div className="w-2 h-2 bg-text-secondary/50 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
            <div className="w-2 h-2 bg-text-secondary/50 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
            <div className="w-2 h-2 bg-text-secondary/50 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
          </motion.div>
        )}
        <div ref={messagesEndRef} />
      </div>

      <div className="mt-auto shrink-0 flex gap-2">
        <input
          type="text"
          value={inputValue}
          onChange={(e) => setInputValue(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && handleSend()}
          placeholder="Escríbeme lo que sientes..."
          className="flex-1 px-4 py-3 rounded-xl border border-border-secondary bg-bg-primary outline-none focus:border-primary transition-colors text-[15px]"
        />
        <button
          onClick={handleSend}
          disabled={!inputValue.trim() || isTyping}
          className="px-5 bg-primary hover:bg-primary-dark text-white rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center shrink-0 shadow-md"
        >
          <IconSend size={20} />
        </button>
      </div>
    </div>
  );
}
