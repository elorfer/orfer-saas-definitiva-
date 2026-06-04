"use client";

import React, { useState, useRef, useEffect } from 'react';
import { IconSend, IconLoader2 } from '@tabler/icons-react';
import { motion, AnimatePresence } from 'framer-motion';
import { createClient } from '@/utils/supabase/client';

type Message = {
  id: string;
  text: string;
  sender: 'ai' | 'user';
  created_at?: string;
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

const WELCOME_MESSAGE: Message = {
  id: 'welcome',
  text: '👋 Hola! Soy tu coach de manifestación. ¿En qué área de tu vida quieres enfocarte hoy — dinero, amor, salud, o algo más?',
  sender: 'ai'
};

export default function CoachTab() {
  const supabase = createClient();
  const [user, setUser] = useState<any>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputValue, setInputValue] = useState('');
  const [loading, setLoading] = useState(true);
  const [isTyping, setIsTyping] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages, isTyping]);

  useEffect(() => {
    const fetchUserAndMessages = async () => {
      const { data: { user } } = await supabase.auth.getUser();
      if (user) {
        setUser(user);
        const { data, error } = await supabase
          .from('chat_messages')
          .select('*')
          .order('created_at', { ascending: true });
        
        if (!error && data) {
          setMessages(data.length > 0 ? data : [WELCOME_MESSAGE]);
        } else {
          setMessages([WELCOME_MESSAGE]);
        }
      }
      setLoading(false);
    };

    fetchUserAndMessages();
  }, []);

  const handleSend = async () => {
    const trimmedInput = inputValue.trim();
    if (!trimmedInput || !user) return;

    // Optimista local update
    const tempUserMsg: Message = { id: Date.now().toString(), text: trimmedInput, sender: 'user' };
    setMessages((prev) => [...prev, tempUserMsg]);
    setInputValue('');
    setIsTyping(true);

    try {
      // 1. Guardar mensaje del usuario en base de datos
      const { data: userMsgData, error: userError } = await supabase
        .from('chat_messages')
        .insert([
          {
            text: trimmedInput,
            sender: 'user',
            user_id: user.id
          }
        ])
        .select();

      if (userError) throw userError;

      // Actualizar el mensaje local con su ID real de base de datos
      if (userMsgData && userMsgData.length > 0) {
        setMessages(prev => prev.map(m => m.id === tempUserMsg.id ? userMsgData[0] : m));
      }

      // 2. Simular respuesta del AI
      setTimeout(async () => {
        const lower = trimmedInput.toLowerCase();
        let key = 'default';
        topics.forEach((t) => {
          if (lower.includes(t)) key = t;
        });

        const replies = aiReplies[key] || aiReplies.default;
        const replyText = replies[Math.floor(Math.random() * replies.length)];

        // Guardar mensaje de la IA en la base de datos
        const { data: aiMsgData, error: aiError } = await supabase
          .from('chat_messages')
          .insert([
            {
              text: replyText,
              sender: 'ai',
              user_id: user.id
            }
          ])
          .select();

        if (!aiError && aiMsgData && aiMsgData.length > 0) {
          setMessages((prev) => [...prev, aiMsgData[0]]);
        } else {
          // Fallback local en caso de error de guardado de IA
          setMessages((prev) => [...prev, { id: (Date.now() + 1).toString(), text: replyText, sender: 'ai' }]);
        }
        setIsTyping(false);
      }, 1200);

    } catch (err) {
      console.error("Error al enviar mensaje:", err);
      setIsTyping(false);
    }
  };

  return (
    <div className="flex flex-col h-full absolute inset-0 p-4 sm:p-6 pb-24 bg-bg-primary">
      {loading ? (
        <div className="h-full flex items-center justify-center">
          <IconLoader2 size={32} className="animate-spin text-primary" />
        </div>
      ) : (
        <>
          <div className="flex-1 overflow-y-auto pr-2 no-scrollbar flex flex-col gap-4 pb-4">
            <AnimatePresence initial={false}>
              {messages.map((msg) => (
                <motion.div
                  key={msg.id}
                  initial={{ opacity: 0, y: 10, scale: 0.95 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  className={`max-w-[85%] p-3.5 rounded-2xl text-[15px] leading-relaxed shadow-sm ${
                    msg.sender === 'ai'
                      ? 'bg-bg-secondary border border-border-primary rounded-bl-none self-start text-text-primary'
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
              className="flex-1 px-4 py-3 rounded-xl border border-border-secondary bg-bg-primary outline-none focus:border-primary transition-colors text-[15px] text-text-primary placeholder:text-text-secondary/50"
            />
            <button
              onClick={handleSend}
              disabled={!inputValue.trim() || isTyping}
              className="px-5 bg-primary hover:bg-primary-dark text-white rounded-xl transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center shrink-0 shadow-md"
            >
              <IconSend size={20} />
            </button>
          </div>
        </>
      )}
    </div>
  );
}
