import { Zap, Star, Gem, Crown, Video } from 'lucide-react';

export const PLAN_IDS = {
    STARTER: 'starter',
    PRO: 'pro',
    PREMIUM: 'premium',
    ELITE: 'elite',
    YOUTUBE: 'youtube'
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
        price: 37,
        icon: Zap,
        highlight: false
    },
    {
        id: PLAN_IDS.PRO,
        price: 50,
        icon: Star,
        highlight: true
    },
    {
        id: PLAN_IDS.PREMIUM,
        price: 97,
        icon: Gem,
        highlight: false
    },
    {
        id: PLAN_IDS.ELITE,
        price: 147,
        icon: Crown,
        highlight: false
    },
    {
        id: PLAN_IDS.YOUTUBE,
        price: 250,
        icon: Video,
        highlight: false
    }
];

export const getPlanData = (id: string) => PLANS.find(p => p.id === id) || PLANS[0];
