"use client";

import React, { useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import Header from "@/components/layout/Header";
import Navigation, { TabType } from "@/components/layout/Navigation";
import CoachTab from "@/components/tabs/CoachTab";
import AffirmationsTab from "@/components/tabs/AffirmationsTab";
import GoalsTab from "@/components/tabs/GoalsTab";
import GratitudeTab from "@/components/tabs/GratitudeTab";
import VisualizeTab from "@/components/tabs/VisualizeTab";

export default function AppHome() {
  const [activeTab, setActiveTab] = useState<TabType>("coach");

  React.useEffect(() => {
    const handleTabChange = (event: Event) => {
      const customEvent = event as CustomEvent<TabType>;
      if (customEvent.detail) {
        setActiveTab(customEvent.detail);
      }
    };
    window.addEventListener("change-tab", handleTabChange);
    return () => window.removeEventListener("change-tab", handleTabChange);
  }, []);

  const renderTab = () => {
    switch (activeTab) {
      case "coach":
        return <CoachTab />;
      case "afirmaciones":
        return <AffirmationsTab />;
      case "metas":
        return <GoalsTab />;
      case "gratitud":
        return <GratitudeTab />;
      case "visualizar":
        return <VisualizeTab />;
      default:
        return <CoachTab />;
    }
  };

  return (
    <div className="min-h-screen bg-background transition-colors duration-300 flex flex-col items-center justify-center sm:py-8 sm:px-4">
      <div className="w-full max-w-[680px] h-screen sm:h-[780px] bg-bg-primary sm:border border-border-secondary sm:rounded-3xl sm:shadow-2xl overflow-hidden flex flex-col relative border-border-primary/80 transition-colors duration-300">
        <Header />
        
        {/* Contenedor principal del contenido que se anima */}
        <main className="flex-1 relative overflow-hidden bg-bg-primary">
          <AnimatePresence mode="wait">
            <motion.div
              key={activeTab}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              transition={{ duration: 0.2, ease: "easeOut" }}
              className="absolute inset-0"
            >
              {renderTab()}
            </motion.div>
          </AnimatePresence>
        </main>

        <Navigation activeTab={activeTab} onChangeTab={setActiveTab} />
      </div>
    </div>
  );
}
