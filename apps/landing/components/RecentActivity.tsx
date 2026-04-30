'use client';

import { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ShoppingBag, Zap, Star } from 'lucide-react';

const activities = [
    { name: "Juan R.", city: "Ciudad de México", plan: "Elite Studio", time: "hace 45 seg" },
    { name: "Marta S.", city: "Bogotá", plan: "Pro Master", time: "hace 2 min" },
    { name: "Carlos T.", city: "Madrid", plan: "Elite Studio", time: "hace 5 min" },
    { name: "Elena G.", city: "Buenos Aires", plan: "Starter", time: "hace 8 min" },
    { name: "Ricardo M.", city: "Medellín", plan: "Pro Master", time: "hace 12 min" },
    { name: "Sofía L.", city: "Santiago", plan: "Elite Studio", time: "hace 15 min" },
    { name: "Diego P.", city: "Lima", plan: "Starter", time: "hace 20 min" },
    { name: "Andrés K.", city: "Miami", plan: "Pro Master", time: "hace 22 min" },
    { name: "Lucía V.", city: "Barcelona", plan: "Elite Studio", time: "hace 28 min" },
    { name: "Mateo B.", city: "Quito", plan: "Starter", time: "hace 35 min" },
    { name: "Valentina F.", city: "Montevideo", plan: "Pro Master", time: "hace 42 min" },
    { name: "Gabriel H.", city: "Panamá", plan: "Elite Studio", time: "hace 50 min" },
    { name: "Isabella J.", city: "San José", plan: "Pro Master", time: "hace 1 hora" },
    { name: "Felipe N.", city: "Guayaquil", plan: "Elite Studio", time: "hace 1 hora" },
    { name: "Camila D.", city: "Puebla", plan: "Starter", time: "hace 1 hora" },
    { name: "Sebastián M.", city: "Valencia", plan: "Pro Master", time: "hace 2 horas" },
    { name: "Alejandra Q.", city: "Caracas", plan: "Elite Studio", time: "hace 2 horas" },
    { name: "Hugo L.", city: "Monterrey", plan: "Pro Master", time: "hace 3 horas" },
    { name: "Paula C.", city: "Cali", plan: "Starter", time: "hace 3 horas" },
    { name: "Javier S.", city: "Antigua", plan: "Elite Studio", time: "hace 4 horas" },
];

export default function RecentActivity({ lang }: { lang: 'es' | 'en' }) {
    const [currentActivity, setCurrentActivity] = useState<typeof activities[0] | null>(null);
    const [isVisible, setIsVisible] = useState(false);

    useEffect(() => {
        const showRandomActivity = () => {
            const random = activities[Math.floor(Math.random() * activities.length)];
            setCurrentActivity(random);
            setIsVisible(true);

            // Hide after 5 seconds
            setTimeout(() => {
                setIsVisible(false);
            }, 5000);
        };

        // First one after 10 seconds
        const initialTimer = setTimeout(showRandomActivity, 10000);

        // Repeat every 25 seconds
        const interval = setInterval(showRandomActivity, 25000);

        return () => {
            clearTimeout(initialTimer);
            clearInterval(interval);
        };
    }, []);

    return (
        <AnimatePresence>
            {isVisible && currentActivity && (
                <motion.div
                    initial={{ x: -100, opacity: 0 }}
                    animate={{ x: 0, opacity: 1 }}
                    exit={{ x: -100, opacity: 0 }}
                    className="fixed bottom-24 md:bottom-8 left-4 z-[60] max-w-[280px] w-full"
                >
                    <div className="bg-black/80 backdrop-blur-xl border border-white/10 rounded-2xl p-4 shadow-2xl flex items-center gap-4">
                        <div className="relative">
                            <div className="w-10 h-10 rounded-full bg-gradient-to-br from-coffee-medium to-coffee-dark flex items-center justify-center text-white shrink-0">
                                <ShoppingBag className="w-5 h-5" />
                            </div>
                            <div className="absolute -top-1 -right-1 w-4 h-4 bg-green-500 rounded-full border-2 border-black flex items-center justify-center">
                                <div className="w-1.5 h-1.5 bg-white rounded-full animate-pulse"></div>
                            </div>
                        </div>
                        
                        <div className="flex flex-col min-w-0">
                            <div className="flex items-center gap-1">
                                <span className="text-[11px] font-black text-white truncate">
                                    {currentActivity.name} {lang === 'es' ? 'de' : 'from'} {currentActivity.city}
                                </span>
                            </div>
                            <p className="text-[10px] text-gray-400 font-medium">
                                {lang === 'es' ? 'Encargó un' : 'Ordered a'} <span className="text-coffee-light font-bold">{currentActivity.plan}</span>
                            </p>
                            <span className="text-[9px] text-gray-600 mt-1 uppercase tracking-widest font-black">
                                {currentActivity.time}
                            </span>
                        </div>

                        <button 
                            onClick={() => setIsVisible(false)}
                            className="absolute top-2 right-2 text-gray-600 hover:text-white transition-colors"
                        >
                            <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M6 18L18 6M6 6l12 12"/></svg>
                        </button>
                    </div>
                </motion.div>
            )}
        </AnimatePresence>
    );
}
