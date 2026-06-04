import React from 'react';
import { 
  IconRobot, 
  IconSparkles, 
  IconTarget, 
  IconHeart, 
  IconEye 
} from '@tabler/icons-react';
import { clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export type TabType = 'coach' | 'afirmaciones' | 'metas' | 'gratitud' | 'visualizar';

interface NavigationProps {
  activeTab: TabType;
  onChangeTab: (tab: TabType) => void;
}

export default function Navigation({ activeTab, onChangeTab }: NavigationProps) {
  const tabs = [
    { id: 'coach', label: 'Coach', icon: IconRobot },
    { id: 'afirmaciones', label: 'Afirmar', icon: IconSparkles },
    { id: 'metas', label: 'Metas', icon: IconTarget },
    { id: 'gratitud', label: 'Gratitud', icon: IconHeart },
    { id: 'visualizar', label: 'Visualizar', icon: IconEye },
  ] as const;

  return (
    <nav className="flex border-b border-border-primary bg-bg-secondary shrink-0 overflow-x-auto no-scrollbar">
      {tabs.map((tab) => {
        const Icon = tab.icon;
        const isActive = activeTab === tab.id;
        
        return (
          <button
            key={tab.id}
            onClick={() => onChangeTab(tab.id as TabType)}
            className={twMerge(
              "flex-1 min-w-[70px] py-3 px-1 text-xs flex flex-col items-center gap-1.5 transition-all border-b-2",
              isActive 
                ? "border-primary text-primary" 
                : "border-transparent text-text-secondary hover:text-text-primary hover:bg-black/5 dark:hover:bg-white/5"
            )}
            role="tab"
            aria-selected={isActive}
            aria-label={tab.label}
          >
            <Icon size={20} stroke={isActive ? 2 : 1.5} />
            <span className="font-medium">{tab.label}</span>
          </button>
        );
      })}
    </nav>
  );
}
