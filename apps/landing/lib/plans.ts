import { Zap, Star, Crown } from 'lucide-react';

export const PLAN_IDS = {
    STARTER: 'starter',
    PRO: 'pro',
    ELITE: 'elite'
} as const;

export type PlanId = typeof PLAN_IDS[keyof typeof PLAN_IDS];

export interface Plan {
    id: PlanId;
    price: number;
    icon: any;
    highlight: boolean;
    stripePriceId?: string; // Optional, for future use
}

export const PLANS: Plan[] = [
    {
        id: PLAN_IDS.STARTER,
        price: 50,
        icon: Zap,
        highlight: false
    },
    {
        id: PLAN_IDS.PRO,
        price: 97,
        icon: Star,
        highlight: true
    },
    {
        id: PLAN_IDS.ELITE,
        price: 147,
        icon: Crown,
        highlight: false
    }
];

export const getPlanData = (id: string) => PLANS.find(p => p.id === id) || PLANS[0];
