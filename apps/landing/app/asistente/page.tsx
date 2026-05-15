'use client';

import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Send, Copy, RotateCcw, Check, Sparkles, User, Bot, Layout, MessageSquare, ShieldCheck, Zap } from 'lucide-react';
import RechargeParticles from '@/components/RechargeParticles';

export default function AsistenteVentas() {
  const [stats, setStats] = useState({ total: 0, count: 0 });

  useEffect(() => {
    fetch('/api/stats')
      .then(res => res.json())
      .then(data => setStats(data))
      .catch(err => console.error(err));
  }, []);

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
    "¿Cuánto cuesta?",
    "Hola, info",
    "¿Cómo funciona?",
    "¿Mis derechos?",
    "Está muy caro",
    "¿Cuánto tardan?",
    "¿IA o humano?",
    "¿Spotify?",
    "Tengo mi letra",
    "Déjame pensarlo",
    "¿Garantía?",
    "¿Qué formato?",
    "Ver sitio web"
  ];

  const RESPUESTAS: any = {
    precio: {
      label: "💰 Pregunta por precios",
      msg: `Tenemos 4 planes según lo que necesites 🎚️\n\n⭐ *Pro Master — $50 USD* _(el más elegido)_\n24-48h · 3 revisiones · Derechos 100% tuyos · Calidad WAV · Mezcla vocal avanzada\n🎁 Video letra HD de regalo\n\n🟢 *Starter — $37 USD*\n24-48h · 1 revisión · Licencia para redes sociales\n\n🔥 *Premium — $97 USD*\nPrioritario 24h · 5 revisiones · Mezcla nivel industria\n🎁 Video letra HD + Portada profesional\n\n👑 *Elite Studio — $147 USD*\nExpress <24h · Revisiones ilimitadas · Stems para shows · Asesoría de lanzamiento\n🎁 Video 4K + Reels/TikTok\n\nTodo eso por lo que en un estudio tradicional te cobrarían $2,000+ USD 💪\n\n¿Cuál se adapta mejor a lo que buscas? 😊`
    },
    caro: {
      label: "💰 Objeción de precio",
      msg: `Entiendo perfectamente tu punto. Sin embargo, piénsalo de esta manera: un estudio tradicional suele ser muy costoso y la espera es de semanas. En Struky tienes calidad de estándar internacional desde *$37 USD* y en solo 48 horas ⚡\n\nY lo más importante: *si el resultado no es lo que esperabas, lo revisamos hasta que estés conforme*. Queremos que tu música suene gigante. ¿Te gustaría iniciar con el plan Starter?`
    },
    hola: {
      label: "👋 Saludo Profesional",
      msg: `¡Hola! Qué gusto que nos escribas 🎵 Bienvenido a la familia *Struky*. Es un placer saludarte.\n\nAquí estamos el equipo de producción e ingenieros listos para que tus letras dejen de estar guardadas y se conviertan en un lanzamiento real en Spotify. El 100% de los derechos son tuyos, nosotros ponemos el estudio y toda la experiencia profesional 🚀\n\nCuéntame un poco... ¿Ya tienes la letra lista o estás aterrizando la idea para tu próxima canción?`
    },
    proceso: {
      label: "🔄 Explicar el proceso",
      msg: `Mira, el proceso es muy sencillo y eficiente, diseñado para que no pierdas tiempo:\n\n1. Nos envías tu letra y el estilo que buscas ✍️\n2. Los productores entran al estudio combinando tecnología avanzada con ingenieros reales 🎛️\n3. En menos de 48h recibes tu hit masterizado en tu correo, listo para publicar ✅\n\n¿Qué género musical tienes en mente para este proyecto?`
    },
    derechos: {
      label: "📜 Derechos de autor",
      msg: `*100% tuyos, garantizado por contrato* 📜\n\nAquí todo es transparente. Firmamos un documento legal donde se certifica que tú eres el único dueño de la obra. Todas las regalías de Spotify y YouTube te pertenecen íntegramente. Nosotros actuamos como tu equipo de producción de confianza.\n\n¿Te gustaría que comencemos con el registro de tu pedido?`
    },
    tiempo: {
      label: "⏱️ Pregunta por tiempo de entrega",
      msg: `¡Somos de los más rápidos de la industria! ⚡\n\n🟢 *Starter y Pro Master:* entrega en *24 a 48 horas*\n🔥 *Premium:* entrega prioritaria en *24 horas*\n👑 *Elite Studio:* entrega express en *menos de 24 horas*\n\nMientras un estudio tradicional tarda de 3 a 6 semanas, con Struky tu canción llega masterizada y lista para publicar en cuestión de horas 🚀\n\n¿Con cuál plan quieres arrancar?`
    },
    spotify: {
      label: "🌎 Pregunta por plataformas",
      msg: `¡Sí, y es exactamente para eso que producimos! 🎯\n\nTu canción queda lista para *Spotify, Apple Music, YouTube Music, Deezer y Tidal* — masterizada a los estándares de cada plataforma.\n\nY como los derechos son *100% tuyos*, todas las regalías que generes en streaming te las pagan directamente a ti 💰\n\nCon el plan *Elite Studio ($147 USD)* además incluimos *asesoría de lanzamiento directa* para que tu canción llegue al público correcto desde el primer día 🚀\n\n¿Te animas?`
    },
    ia: {
      label: "🤖 Sobre la tecnología",
      msg: `¡Es una excelente pregunta! Mira, nuestro enfoque es híbrido. La tecnología nos ayuda a estructurar la base, pero el acabado final, la mezcla y la masterización la realizan nuestros ingenieros expertos. Esto asegura que la canción tenga alma y calidad de radio, no un sonido artificial.\n\nPor eso el resultado suena a hit profesional 📻🔥 ¿Te gustaría escuchar algún ejemplo?`
    },
    letra: {
      label: "✍️ Tiene letra lista",
      msg: `¡Perfecto, ya podemos arrancar! 🎶\n\nEnvíame tu letra por aquí. También dime:\n🎵 ¿Qué género quieres? (reggaetón, pop, vallenato, trap, salsa, ranchera…)\n🎤 ¿Prefieres voz masculina, femenina o sin preferencia?\n🎯 ¿Tienes alguna canción de referencia con el estilo que buscas?\n\nCon eso nuestros productores empiezan a construir tu hit 🔥\n\nEntregamos en *menos de 48h* con el *100% de los derechos tuyos* ✅`
    },
    pensar: {
      label: "🕐 Cliente indeciso",
      msg: `¡Claro, sin ninguna presión! 😊\n\nSolo te cuento que manejamos *50 cupos por semana* — cuando estés listo, escríbeme y verifico si hay disponibilidad.\n\nSi surge alguna duda mientras lo piensas, aquí estoy para lo que necesites 🎵`
    },
    garantia: {
      label: "🛡️ Pregunta por garantía",
      msg: `Tenemos una garantía *100% anti-riesgo* 🛡️\n\nSi al recibir tu canción sientes que no tiene calidad de industria, la *rehacemos contigo hasta que te encante* — o te devolvemos tu dinero. Sin letras pequeñas, sin excusas.\n\nLlevamos más de *10.000 canciones entregadas* y esa es nuestra promesa con cada artista 💪\n\n¿Empezamos? 🚀`
    },
    formato: {
      label: "📁 Pregunta por formato de entrega",
      msg: `Depende del plan que elijas 👇\n\n🟢 *Starter:* Audio optimizado para redes sociales\n⭐ *Pro Master:* Archivo *WAV profesional* + Video letra HD\n🔥 *Premium:* WAV · Mezcla nivel industria · Video letra HD + Portada profesional\n👑 *Elite:* Todo lo anterior + *Stems/pistas separadas* para shows + Video 4K + contenido para Reels y TikTok\n\nTodo te llega directo a tu email, listo para usar 📩🎧\n\n¿Cuál plan te interesa?`
    },
    general: {
      label: "💬 Consulta general",
      msg: `¡Hola! Gracias por escribirle a *Struky Studios* 🎵\n\nSomos el estudio liderado por Miguel Fernández que convierte tus letras en canciones profesionales con IA + ingenieros reales en menos de 48 horas, desde *$37 USD*, con el *100% de los derechos tuyos por contrato*.\n\nCuéntame un poco más sobre lo que buscas y con gusto te oriento 😊`
    },
    web: {
      label: "🌐 Invitar a la Web",
      msg: `¡Claro que sí! 🚀 Te invito a que visites nuestra web oficial donde podrás escuchar ejemplos reales, ver testimonios de otros artistas y conocer a fondo todo lo que Struky puede hacer por tu música:\n\n👉 *https://www.struky.com*\n\nAhí puedes ver todos los planes y ejemplos a detalle. ¿Te gustaría que te oriente sobre cuál plan le vendría mejor a tu estilo? 😊`
    },
    bienvenida: {
      label: "✨ Bienvenida e Info",
      msg: `¡Hola! 👋 Bienvenido a *Struky*.\n\nTodo el proceso de producción se inicia desde nuestra plataforma oficial para garantizar calidad de estudio.\n\n*¿Cómo funciona?*\n1️⃣ Entras a 👉 *https://www.struky.com* y eliges tu plan.\n2️⃣ Completas el formulario de pedido. **Dato clave:** Si no tienes la letra lista, selecciona la opción *"Enviar letra después"* en el formulario.\n3️⃣ Al terminar, el sistema te dará un **Número de Ticket** único.\n4️⃣ Si elegiste enviar la letra después, solo me pasas ese Ticket por aquí (WhatsApp) junto con tu letra o idea, ¡y nuestros productores se ponen manos a la obra! 🎧🔥\n\nEn 24-48h tendrás tu hit listo para sonar en todos lados.\n\n¿Te ayudo a elegir el plan ideal para tu estilo? ⚡`
    },
    nequi: {
      label: "💰 Pago por Nequi",
      msg: `¡Excelente! Para agilizar, puedes pagar directo por *Nequi* al número: *3009012217* a nombre de Miguel Ortiz.\n\nUna vez realices la transferencia, me envías el comprobante por aquí y empezamos de inmediato con la producción de tu hit 🚀`
    },
    urgencia: {
      label: "⏱️ Últimos Cupos",
      msg: `¡Hola! Solo te escribía para confirmarte que hoy nos quedan los *últimos 3 cupos* para entrega en 24 horas. \n\nSi quieres asegurar el tuyo para que empecemos hoy mismo con tu canción, avísame y te reservo el espacio 🎙️🔥`
    },
    confirmacion: {
      label: "✅ Pago Recibido",
      msg: `¡Perfecto! Ya recibimos tu pago ✅. Nuestros productores ya están en el estudio dándole vida a tu letra.\n\nEn un máximo de 24-48h tendrás tu canción masterizada aquí mismo en tu WhatsApp. ¡Prepárate para sonar gigante! 🎧🔥`
    },
    pasos: {
      label: "👣 Pasos a seguir",
      msg: `¡Es muy fácil! Estos son los pasos para tener tu canción lista aquí por WhatsApp:\n\n1️⃣ Me envías tu letra o la idea de lo que quieres decir ✍️\n2️⃣ Eliges el género musical y tipo de voz (Hombre o Mujer) 🎤\n3️⃣ Realizas el pago por Nequi o transferencia ✅\n4️⃣ ¡Y listo! En 24-48h recibes tu hit masterizado directamente en este chat 🎧🔥\n\n¿Te gustaría que comencemos con el paso 1? 😊`
    }
  };

  const detectKey = (msg: string) => {
    const m = msg.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
    if (/precio|cuesta|cuanto|costo|plan|pagar|vale|valor|cobran/.test(m)) return 'precio';
    if (/caro|expensivo|barato|descuento|presupuesto|poco dinero|no tengo tanto|muy caro/.test(m)) return 'caro';
    if (/derecho|dueno|mio|mia|royalt|regal|copyright|propied|autor/.test(m)) return 'derechos';
    if (/tiempo|demoran|rapido|rapida|48|horas|entrega|cuando|tarda|demora/.test(m)) return 'tiempo';
    if (/spotify|apple music|plataforma|distribu|stream|deezer|tidal|youtube music/.test(m)) return 'spotify';
    if (/ia|robot|artificial|humano|real|productor|algoritmo|maquina/.test(m)) return 'ia';
    if (/funciona|proceso|como|paso|trabaj|metodo/.test(m)) return 'proceso';
    if (/formato|archivo|wav|mp3|stems|pistas|separad/.test(m)) return 'formato';
    if (/garantia|devuelv|reembolso|riesgo|segur|devolucion/.test(m)) return 'garantia';
    if (/letra|cancion|idea|escribi|tengo lista|ya tengo/.test(m)) return 'letra';
    if (/pens|duda|despues|luego|manana|espera|no se|insegur|pensarlo/.test(m)) return 'pensar';
    if (/web|pagina|sitio|link|url|donde miro|enlace/.test(m)) return 'web';
    if (/hola|info|informacion|saber|contacto|buenas|buen dia|hey|buenos/.test(m)) return 'hola';
    return 'general';
  };

  const handleQuickResponse = () => {
    if (!input.trim()) return;
    const key = detectKey(input);
    const data = RESPUESTAS[key];
    setResponse(data.msg);
  };

  return (
    <div className="min-h-screen bg-[#F8FAFC] text-slate-900 font-sans antialiased selection:bg-indigo-100 selection:text-indigo-900">
      
      {/* Top Navbar */}
      <nav className="sticky top-0 z-50 bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center text-white shadow-sm">
            <Layout className="w-4 h-4" />
          </div>
          <span className="font-bold text-slate-800 tracking-tight">Struky Sales Hub</span>
        </div>
        <div className="flex items-center gap-2">
            <span className="hidden sm:inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-emerald-100 text-emerald-800">
                GPT-4o
            </span>
        </div>
      </nav>

      <main className="max-w-4xl mx-auto px-6 py-10">
        
        {/* Intro */}
        <div className="mb-10 flex flex-col md:flex-row md:items-end justify-between gap-6">
            <div>
                <h1 className="text-3xl font-extrabold text-slate-900 mb-2">Asistente de Ventas</h1>
                <p className="text-slate-500 max-w-xl">Pega el mensaje de tu cliente y genera una respuesta optimizada para cerrar la venta en segundos.</p>
            </div>
            
            <div className="bg-emerald-50 border border-emerald-100 rounded-2xl p-5 flex items-center gap-4 shadow-sm relative overflow-hidden">
                <RechargeParticles />
                <div className="w-12 h-12 rounded-full bg-emerald-500/10 flex items-center justify-center relative z-10">
                    <Zap className="w-6 h-6 text-emerald-600" />
                </div>
                <div className="relative z-10">
                    <p className="text-[10px] font-black text-emerald-600 uppercase tracking-widest mb-1">Total Facturado</p>
                    <p className="text-2xl font-black text-slate-900">${stats.total.toLocaleString()} <span className="text-sm font-medium text-slate-400">USD</span></p>
                    <p className="text-[10px] text-emerald-600/60 font-bold uppercase">{stats.count} producciones exitosas</p>
                </div>
            </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-5 gap-8">
            
            {/* Left: Input */}
            <div className="lg:col-span-3 space-y-6">
                <div className="bg-white border border-slate-200 rounded-2xl shadow-sm overflow-hidden">
                    <div className="px-4 py-3 border-b border-slate-100 bg-slate-50 flex items-center gap-2">
                        <User className="w-3.5 h-3.5 text-slate-400" />
                        <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">Entrada del Cliente</span>
                    </div>
                    <div className="p-4">
                        <textarea 
                            value={input}
                            onChange={(e) => setInput(e.target.value)}
                            placeholder="Ej: Hola, quiero saber los precios y si la canción la hace una persona real..."
                            className="w-full min-h-[220px] text-slate-700 text-sm focus:outline-none resize-none placeholder:text-slate-300 leading-relaxed"
                        />
                    </div>
                    <div className="p-4 bg-slate-50 border-t border-slate-100 flex flex-wrap gap-2">
                        {quickExamples.map((ex, i) => (
                            <button 
                                key={i}
                                onClick={() => setInput(ex)}
                                className="text-[11px] px-3 py-1.5 rounded-md border border-slate-200 bg-white hover:bg-slate-50 hover:border-slate-300 transition-all text-slate-500 font-medium"
                            >
                                {ex}
                            </button>
                        ))}
                    </div>
                </div>

                <div className="bg-white border border-slate-200 rounded-2xl p-4 shadow-sm mb-6">
                    <p className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-4 flex items-center gap-2">
                        <Zap className="w-3 h-3 text-amber-500" />
                        Categorías de Respuesta Rápida
                    </p>
                    <div className="flex flex-wrap gap-2">
                        {Object.entries(RESPUESTAS)
                            .filter(([key]) => !['nequi', 'urgencia', 'confirmacion', 'pasos'].includes(key))
                            .map(([key, data]: [string, any]) => (
                                <button
                                    key={key}
                                    onClick={() => setResponse(data.msg)}
                                    className="px-3 py-2 rounded-xl border border-slate-100 bg-slate-50 hover:bg-indigo-50 hover:border-indigo-200 hover:text-indigo-600 transition-all text-xs font-bold text-slate-600 flex items-center gap-2"
                                >
                                    {data.label}
                                </button>
                            ))}
                    </div>
                </div>

                {/* ASISTENCIA POR WHATSAPP - ACCIONES RÁPIDAS */}
                <div className="bg-emerald-950 border border-emerald-500/30 rounded-2xl p-6 shadow-lg overflow-hidden relative mb-6">
                    <div className="absolute top-0 right-0 p-4 opacity-5">
                        <MessageSquare className="w-16 h-16 text-white" />
                    </div>
                    <div className="relative z-10">
                        <p className="text-[10px] font-black text-emerald-400 uppercase tracking-widest mb-4 flex items-center gap-2">
                            <MessageSquare className="w-3 h-3 text-emerald-400" />
                            Cierre de Ventas por WhatsApp
                        </p>
                        <div className="grid grid-cols-2 gap-3">
                            <button 
                                onClick={() => setResponse(RESPUESTAS.nequi.msg)}
                                className="bg-white/5 border border-white/10 hover:bg-emerald-500/20 hover:border-emerald-500/50 p-3 rounded-xl transition-all text-left group"
                            >
                                <p className="text-[10px] font-black text-emerald-400 uppercase tracking-wider mb-1 group-hover:text-emerald-300">💰 Datos Nequi</p>
                                <p className="text-[9px] text-slate-400 font-medium leading-tight">Cargar datos para pago directo.</p>
                            </button>

                            <button 
                                onClick={() => setResponse(`¡Perfecto! Para empezar, solo dime:\n\n1. ¿De qué trata tu letra o qué idea quieres transmitir?\n2. ¿Qué género musical prefieres? (Reggaetón, Pop, Vallenato, Salsa, etc.)\n3. ¿Voz masculina o femenina?\n\nCon eso mis productores ya pueden ir aterrizando tu hit 🎙️🔥`)}
                                className="bg-white/5 border border-white/10 hover:bg-indigo-500/20 hover:border-indigo-500/50 p-3 rounded-xl transition-all text-left group"
                            >
                                <p className="text-[10px] font-black text-indigo-400 uppercase tracking-wider mb-1 group-hover:text-indigo-300">🎤 Iniciar Pedido</p>
                                <p className="text-[9px] text-slate-400 font-medium leading-tight">Pedir datos de la canción.</p>
                            </button>

                            <button 
                                onClick={() => setResponse(RESPUESTAS.urgencia.msg)}
                                className="bg-white/5 border border-white/10 hover:bg-amber-500/20 hover:border-amber-500/50 p-3 rounded-xl transition-all text-left group"
                            >
                                <p className="text-[10px] font-black text-amber-400 uppercase tracking-wider mb-1 group-hover:text-amber-300">⏱️ Urgencia</p>
                                <p className="text-[9px] text-slate-400 font-medium leading-tight">Cargar mensaje de últimos cupos.</p>
                            </button>

                            <button 
                                onClick={() => setResponse(RESPUESTAS.confirmacion.msg)}
                                className="bg-white/5 border border-white/10 hover:bg-blue-500/20 hover:border-blue-500/50 p-3 rounded-xl transition-all text-left group"
                            >
                                <p className="text-[10px] font-black text-blue-400 uppercase tracking-wider mb-1 group-hover:text-blue-300">✅ Pago OK</p>
                                <p className="text-[9px] text-slate-400 font-medium leading-tight">Confirmación de éxito.</p>
                            </button>

                            <button 
                                onClick={() => setResponse(RESPUESTAS.pasos.msg)}
                                className="bg-white/5 border border-white/10 hover:bg-purple-500/20 hover:border-purple-500/50 p-3 rounded-xl transition-all text-left group"
                            >
                                <p className="text-[10px] font-black text-purple-400 uppercase tracking-wider mb-1 group-hover:text-purple-300">👣 Pasos</p>
                                <p className="text-[9px] text-slate-400 font-medium leading-tight">Guía rápida de compra.</p>
                            </button>
                        </div>
                    </div>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <button 
                        onClick={handleGenerate}
                        disabled={loading || !input.trim()}
                        className="bg-slate-900 hover:bg-slate-800 text-white font-bold py-4 rounded-xl flex items-center justify-center gap-2.5 transition-all active:scale-[0.98] disabled:opacity-30 disabled:pointer-events-none shadow-lg shadow-slate-200"
                    >
                        {loading ? (
                            <div className="w-5 h-5 border-2 border-white/20 border-t-white rounded-full animate-spin" />
                        ) : (
                            <>
                                <Sparkles className="w-4 h-4 text-indigo-400" />
                                Generar con IA
                            </>
                        )}
                    </button>
                    <button 
                        onClick={handleQuickResponse}
                        disabled={loading || !input.trim()}
                        className="bg-white border border-slate-200 hover:bg-slate-50 text-slate-700 font-bold py-4 rounded-xl flex items-center justify-center gap-2.5 transition-all active:scale-[0.98] disabled:opacity-30 disabled:pointer-events-none shadow-sm"
                    >
                        <Zap className="w-4 h-4 text-amber-500" />
                        Detectar y Responder
                    </button>
                </div>
            </div>

            {/* Right: Output */}
            <div className="lg:col-span-2">
                <AnimatePresence mode="wait">
                    {!response && !loading ? (
                        <motion.div 
                            key="empty"
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            exit={{ opacity: 0 }}
                            className="h-full min-h-[300px] border-2 border-dashed border-slate-200 rounded-2xl flex flex-col items-center justify-center p-8 text-center"
                        >
                            <div className="w-12 h-12 bg-slate-100 rounded-full flex items-center justify-center mb-4">
                                <MessageSquare className="w-6 h-6 text-slate-300" />
                            </div>
                            <p className="text-sm font-medium text-slate-400">La respuesta aparecerá aquí</p>
                        </motion.div>
                    ) : (
                        <motion.div 
                            key="result"
                            initial={{ opacity: 0, x: 20 }}
                            animate={{ opacity: 1, x: 0 }}
                            className="bg-white border border-indigo-100 rounded-2xl shadow-xl shadow-indigo-100/20 overflow-hidden flex flex-col h-full"
                        >
                            <div className="px-4 py-3 border-b border-indigo-50 bg-indigo-50/50 flex items-center justify-between">
                                <div className="flex items-center gap-2">
                                    <Bot className="w-3.5 h-3.5 text-indigo-600" />
                                    <span className="text-xs font-bold text-indigo-600 uppercase tracking-wider">Respuesta de IA</span>
                                </div>
                                <button 
                                    onClick={clear}
                                    className="p-1.5 hover:bg-indigo-100 rounded-lg text-indigo-300 hover:text-indigo-600 transition-all"
                                    title="Limpiar"
                                >
                                    <RotateCcw className="w-3.5 h-3.5" />
                                </button>
                            </div>
                            <div className="p-5 flex-1 max-h-[400px] overflow-y-auto">
                                <p className="text-sm text-slate-600 leading-relaxed whitespace-pre-wrap">
                                    {response}
                                </p>
                            </div>
                            <div className="p-4 border-t border-slate-100 bg-white">
                                <button 
                                    onClick={copyToClipboard}
                                    className={`w-full flex items-center justify-center gap-2 py-3 rounded-xl text-sm font-bold transition-all ${copied ? 'bg-emerald-500 text-white shadow-lg shadow-emerald-200' : 'bg-indigo-600 text-white hover:bg-indigo-700 shadow-lg shadow-indigo-200'}`}
                                >
                                    {copied ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
                                    {copied ? '¡Copiado!' : 'Copiar para WhatsApp'}
                                </button>
                            </div>
                        </motion.div>
                    )}
                </AnimatePresence>

                {/* Info Cards */}
                <div className="mt-8 space-y-3">
                    <InfoRow icon={<ShieldCheck className="w-4 h-4" />} text="100% Derechos del autor" />
                    <InfoRow icon={<Zap className="w-4 h-4" />} text="Entrega en menos de 48h" />
                </div>
            </div>
        </div>

        {/* Price Table Reference */}
        <div className="mt-16 bg-white border border-slate-200 rounded-2xl p-6 shadow-sm">
            <h2 className="text-sm font-black text-slate-800 uppercase tracking-[0.2em] mb-6">Guía rápida de precios</h2>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
                <MiniPlan name="Starter" price="37" desc="Redes sociales" />
                <MiniPlan name="Pro Master" price="50" desc="WAV + Video" color="text-indigo-600" />
                <MiniPlan name="Premium" price="97" desc="Industria" />
                <MiniPlan name="Elite" price="147" desc="VIP Ilimitado" />
            </div>
        </div>


      </main>
    </div>
  );
}

function InfoRow({ icon, text }: { icon: any, text: string }) {
    return (
        <div className="flex items-center gap-3 px-4 py-3 bg-white border border-slate-100 rounded-xl">
            <div className="text-indigo-500">{icon}</div>
            <span className="text-xs font-semibold text-slate-500 uppercase tracking-wide">{text}</span>
        </div>
    );
}

function MiniPlan({ name, price, desc, color = "text-slate-900" }: { name: string, price: string, desc: string, color?: string }) {
    return (
        <div>
            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-1">{name}</p>
            <p className={`text-xl font-black ${color}`}>${price} USD</p>
            <p className="text-[10px] text-slate-400 font-medium">{desc}</p>
        </div>
    );
}
