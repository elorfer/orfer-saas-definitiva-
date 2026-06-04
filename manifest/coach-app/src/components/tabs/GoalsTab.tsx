"use client";

import React from 'react';
import { IconArrowUpRight } from '@tabler/icons-react';
import { motion } from 'framer-motion';

export default function GoalsTab() {
  const goals = [
    {
      id: 1,
      badge: '🎯 90 días',
      badgeColor: 'bg-primary/10 text-primary',
      title: 'Libertad financiera',
      desc: 'Generar $3,000 mes con mi negocio',
      progress: 35,
      footer: '35% completado · 58 días restantes'
    },
    {
      id: 2,
      badge: '💗 En curso',
      badgeColor: 'bg-pink-100 text-pink-700 dark:bg-pink-900/30 dark:text-pink-400',
      title: 'Relación saludable',
      desc: 'Atraer una pareja alineada conmigo',
      progress: 60,
      footer: '60% · trabajando en autoestima'
    }
  ];

  return (
    <div className="absolute inset-0 p-4 sm:p-6 overflow-y-auto no-scrollbar pb-24">
      <div className="flex flex-col gap-4 mb-6">
        {goals.map((goal, index) => (
          <motion.div 
            key={goal.id}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: index * 0.1 }}
            className="bg-bg-secondary rounded-2xl p-5 border border-border-primary shadow-sm"
          >
            <div className={`inline-block text-[11px] font-medium px-2.5 py-1 rounded-full mb-3 ${goal.badgeColor}`}>
              {goal.badge}
            </div>
            <h3 className="text-[15px] font-medium mb-1 text-text-primary">{goal.title}</h3>
            <p className="text-[13px] text-text-secondary mb-4">{goal.desc}</p>
            
            <div className="h-1.5 bg-border-primary rounded-full overflow-hidden mb-2">
              <motion.div 
                initial={{ width: 0 }}
                animate={{ width: `${goal.progress}%` }}
                transition={{ duration: 1, delay: 0.2 + (index * 0.1) }}
                className="h-full bg-primary rounded-full"
              />
            </div>
            <span className="text-[12px] text-text-secondary block">
              {goal.footer}
            </span>
          </motion.div>
        ))}
      </div>

      <button className="w-full py-3.5 rounded-xl border-none text-[15px] font-medium cursor-pointer transition-all bg-primary hover:bg-primary-dark text-white flex justify-center items-center gap-2 shadow-md hover:shadow-lg active:scale-[0.98]">
        + Nueva meta <IconArrowUpRight size={18} />
      </button>
    </div>
  );
}
