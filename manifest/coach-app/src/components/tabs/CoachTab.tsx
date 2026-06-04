"use client";

import React, { useState, useRef, useEffect } from 'react';
import Link from 'next/link';
import { useChat } from '@ai-sdk/react';
import { TextStreamChatTransport } from 'ai';
import { IconSend, IconLoader2, IconSparkles, IconArrowUpRight } from '@tabler/icons-react';
import { motion, AnimatePresence } from 'framer-motion';
import { createClient } from '@/utils/supabase/client';

type DBMessage = {
  id: string;
  text: string;
  sender: 'ai' | 'user';
  created_at?: string;
};

const WELCOME_MESSAGE = {
  id: 'welcome',
  role: 'assistant' as const,
  parts: [{ type: 'text' as const, text: '👋 Hola! Soy tu coach de manifestación. ¿En qué área de tu vida quieres enfocarte hoy — dinero, amor, salud, o algo más?' }]
};

const QUICK_PROMPTS = [
  { text: '💰 ¿Cómo elevo mi vibración de abundancia hoy?', label: 'Abundancia' },
  { text: '💗 ¿Cómo puedo manifestar una relación sana?', label: 'Amor' },
  { text: '🌿 Dame un decreto rápido para la confianza', label: 'Confianza' },
  { text: '🚀 ¿Cómo desbloqueo el éxito en mi carrera?', label: 'Éxito' }
];

export default function CoachTab() {
  const supabase = createClient();
  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [isPro, setIsPro] = useState(false);
  const [input, setInput] = useState('');
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  // Inicializar useChat con la API de chat y tipo UIMessage
  const { 
    messages, 
    sendMessage, 
    status,
    setMessages
  } = useChat({
    transport: new TextStreamChatTransport({
      api: '/api/chat',
    }),
  });

  const isTyping = status === 'submitted' || status === 'streaming';

  useEffect(() => {
    const fetchUserAndMessages = async () => {
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

        // Cargar mensajes de la base de datos
        const { data, error } = await supabase
          .from('chat_messages')
          .select('*')
          .order('created_at', { ascending: true });
        
        if (!error && data && data.length > 0) {
          const mapped = data.map((msg: DBMessage) => ({
            id: msg.id,
            role: msg.sender === 'user' ? 'user' as const : 'assistant' as const,
            parts: [{ type: 'text' as const, text: msg.text }]
          }));
          setMessages(mapped);
        } else {
          setMessages([WELCOME_MESSAGE]);
        }
      }
      setLoading(false);
    };

    fetchUserAndMessages();
  }, []);

  useEffect(() => {
    scrollToBottom();
  }, [messages, isTyping]);

  // Contar cuántos mensajes ha enviado el usuario
  const userMessagesCount = messages.filter(m => m.role === 'user').length;
  const isLimitReached = userMessagesCount >= 5 && !isPro;

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    const trimmedInput = input.trim();
    if (!trimmedInput || !user || isLimitReached || isTyping) return;

    try {
      await sendMessage({
        text: trimmedInput,
      });
      setInput('');
    } catch (err) {
      console.error("Error al enviar mensaje:", err);
    }
  };

  const handleQuickPrompt = async (promptText: string) => {
    if (!user || isLimitReached || isTyping) return;
    try {
      await sendMessage({
        text: promptText,
      });
    } catch (err) {
      console.error("Error al enviar sugerencia rápida:", err);
    }
  };

  const showQuickPrompts = messages.length <= 1 && !isTyping && !isLimitReached;

  if (loading) {
    return (
      <div className="h-full flex items-center justify-center">
        <IconLoader2 size={32} className="animate-spin text-primary" />
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full absolute inset-0 p-4 sm:p-6 pb-24 bg-bg-primary">
      <div className="flex-1 overflow-y-auto pr-2 no-scrollbar flex flex-col gap-4 pb-4">
        <AnimatePresence initial={false}>
          {messages.map((msg) => (
            <motion.div
              key={msg.id}
              initial={{ opacity: 0, y: 10, scale: 0.95 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              className={`max-w-[85%] p-3.5 rounded-2xl text-[15px] leading-relaxed shadow-sm ${
                msg.role === 'assistant'
                  ? 'bg-bg-secondary border border-border-primary rounded-bl-none self-start text-text-primary'
                  : 'bg-primary text-white rounded-br-none self-end'
              }`}
            >
              {msg.parts && Array.isArray(msg.parts) ? (
                msg.parts.map((part: any, idx: number) => {
                  if (part.type === 'text') {
                    return <React.Fragment key={idx}>{part.text}</React.Fragment>;
                  }
                  return null;
                })
              ) : (
                (msg as any).content
              )}
            </motion.div>
          ))}
        </AnimatePresence>
        
        {showQuickPrompts && (
          <motion.div 
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 }}
            className="flex flex-col gap-2 mt-2 w-full max-w-[85%]"
          >
            <span className="text-[10px] font-bold text-text-secondary uppercase tracking-wider pl-1 flex items-center gap-1.5">
              <IconSparkles size={12} className="text-accent-gold" /> Sugerencias de manifestación:
            </span>
            <div className="flex flex-col gap-2">
              {QUICK_PROMPTS.map((prompt, idx) => (
                <button
                  key={idx}
                  onClick={() => handleQuickPrompt(prompt.text)}
                  className="w-full text-left px-4 py-3 rounded-2xl border border-border-primary bg-bg-secondary hover:bg-primary/5 hover:border-primary/40 text-text-primary text-[13px] font-medium transition-all duration-200 active:scale-[0.98] cursor-pointer"
                >
                  {prompt.text}
                </button>
              ))}
            </div>
          </motion.div>
        )}
        
        {isTyping && messages[messages.length - 1]?.role === 'user' && (
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

      {/* Bloque de Entrada o Muro de Pago Inline */}
      {isLimitReached ? (
        <motion.div 
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-auto bg-bg-secondary border border-accent-gold/30 rounded-2xl p-4 text-center flex flex-col items-center shadow-inner relative overflow-hidden"
        >
          <div className="absolute inset-0 bg-gradient-to-br from-accent-gold/5 to-transparent pointer-events-none"></div>
          <div className="w-10 h-10 bg-accent-gold/20 text-accent-gold rounded-full flex items-center justify-center mb-3 shadow-[0_0_10px_rgba(250,204,21,0.25)] animate-pulse">
            <IconSparkles size={20} stroke={2.5} />
          </div>
          <h4 className="text-sm font-bold text-text-primary mb-1">Límite diario de coaching alcanzado</h4>
          <p className="text-[12px] text-text-secondary mb-4 max-w-[285px] leading-relaxed">
            Has enviado tus 5 mensajes diarios permitidos. ¡Actualiza a Pro para conversar de manera ilimitada con tu mentor espiritual!
          </p>
          <Link 
            href="/paywall"
            className="inline-flex items-center gap-1.5 px-6 py-2.5 rounded-xl bg-primary hover:bg-primary-dark text-white text-xs font-bold uppercase tracking-wider shadow-md shadow-primary/10 active:scale-95 transition-all"
          >
            Obtener Plan Pro <IconArrowUpRight size={14} />
          </Link>
        </motion.div>
      ) : (
        <form onSubmit={handleSend} className="mt-auto shrink-0 flex gap-2">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            disabled={isTyping}
            placeholder="Escríbeme lo que sientes..."
            className="flex-1 px-4 py-3 rounded-xl border border-border-secondary bg-bg-primary outline-none focus:border-primary transition-colors text-[15px] text-text-primary placeholder:text-text-secondary/50"
          />
          <button
            type="submit"
            disabled={!input.trim() || isTyping}
            className="px-5 bg-primary hover:bg-primary-dark text-white rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center shrink-0 shadow-md cursor-pointer"
          >
            <IconSend size={20} />
          </button>
        </form>
      )}
    </div>
  );
}
