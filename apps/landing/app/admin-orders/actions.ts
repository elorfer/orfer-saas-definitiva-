'use server';

import Stripe from 'stripe';
import { revalidatePath } from 'next/cache';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_dummy', {
    apiVersion: '2026-03-25.dahlia',
});

export async function updateOrderStatus(sessionId: string, newStatus: string) {
    try {
        // En Stripe, para actualizar una sesión de checkout que ya ha sido completada,
        // lo más correcto es actualizar el PaymentIntent asociado o la sesión misma si permite metadatos.
        // Las sesiones de Stripe guardan metadatos que son mutables.
        
        await stripe.checkout.sessions.update(sessionId, {
            metadata: {
                status: newStatus
            }
        });

        // Revalidamos la ruta del panel para que los cambios se vean reflejados
        revalidatePath('/admin-orders');
        
        return { success: true };
    } catch (error) {
        console.error('Error updating status in Stripe:', error);
        return { success: false, error: 'No se pudo actualizar el estado en Stripe.' };
    }
}

export async function updateOrderNotes(sessionId: string, newNotes: string) {
    try {
        await stripe.checkout.sessions.update(sessionId, {
            metadata: {
                producer_notes: newNotes
            }
        });
        revalidatePath('/admin-orders');
        return { success: true };
    } catch (error) {
        console.error('Error updating notes in Stripe:', error);
        return { success: false, error: 'No se pudo guardar la nota.' };
    }
}
