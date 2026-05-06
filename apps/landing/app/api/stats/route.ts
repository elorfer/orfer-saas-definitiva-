import { NextResponse } from 'next/server';
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || '', {
    apiVersion: '2026-03-25.dahlia',
});

export async function GET() {
    try {
        if (!process.env.STRIPE_SECRET_KEY) {
            return NextResponse.json({ total: 0, count: 0 });
        }

        let allSessions: Stripe.Checkout.Session[] = [];
        let hasMore = true;
        let startingAfter: string | undefined = undefined;

        while (hasMore) {
            const sessions: Stripe.ApiList<Stripe.Checkout.Session> = await stripe.checkout.sessions.list({
                limit: 100,
                status: 'complete',
                starting_after: startingAfter,
            });

            allSessions = [...allSessions, ...sessions.data];
            hasMore = sessions.has_more;
            if (hasMore) {
                startingAfter = sessions.data[sessions.data.length - 1].id;
            }
        }

        const totalCents = allSessions.reduce((acc, session) => acc + (session.amount_total || 0), 0);
        const total = totalCents / 100;

        return NextResponse.json({ 
            total, 
            count: allSessions.length 
        });
    } catch (error) {
        console.error('Error fetching stats:', error);
        return NextResponse.json({ total: 0, count: 0 }, { status: 500 });
    }
}
