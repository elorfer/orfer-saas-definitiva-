import { useState } from 'react';
// import { Button } from '@/components/ui/button'; // No existe, usamos button nativo
import { useMarkAsPremium } from '@/hooks/useUsers';
import { Calendar, Zap } from 'lucide-react';

interface PremiumPlansProps {
    userId: string;
    onSuccess?: () => void;
}

export function PremiumPlans({ userId, onSuccess }: PremiumPlansProps) {
    const [isLoading, setIsLoading] = useState(false);
    const [amount, setAmount] = useState<string>('');
    const markAsPremiumMutation = useMarkAsPremium();

    const handleActivatePlan = async (plan: 'quincenal' | 'mensual' | 'anual') => {
        try {
            setIsLoading(true);
            await markAsPremiumMutation.mutateAsync({
                id: userId,
                plan,
                amount: parseFloat(amount) || 0
            });
            onSuccess?.();
        } catch (error) {
            console.error('Error activando plan:', error);
        } finally {
            setIsLoading(false);
        }
    };

    const plans = [
        {
            id: 'quincenal',
            name: 'Quincenal',
            duration: '15 días',
            icon: Zap,
            color: 'bg-blue-500 hover:bg-blue-600',
        },
        {
            id: 'mensual',
            name: 'Mensual',
            duration: '30 días',
            icon: Calendar,
            color: 'bg-green-500 hover:bg-green-600',
        },
        {
            id: 'anual',
            name: 'Anual',
            duration: '365 días',
            icon: Calendar,
            color: 'bg-purple-500 hover:bg-purple-600',
        },
    ];

    return (
        <div className="space-y-4">
            <div>
                <label className="block text-xs font-medium text-gray-700 mb-1">Monto Cobrado (Opcional)</label>
                <div className="relative rounded-md shadow-sm">
                    <div className="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                        <span className="text-gray-500 sm:text-sm">$</span>
                    </div>
                    <input
                        type="number"
                        min="0"
                        step="0.01"
                        className="block w-full rounded-md border border-gray-300 pl-7 pr-12 focus:border-brown-500 focus:ring-brown-500 sm:text-sm py-2"
                        placeholder="0.00"
                        value={amount}
                        onChange={(e) => setAmount(e.target.value)}
                    />
                    <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center pr-3">
                        <span className="text-gray-500 sm:text-sm">USD</span>
                    </div>
                </div>
                <p className="text-[10px] text-gray-500 mt-1">Este monto se registrará en las estadísticas de ingresos.</p>
            </div>

            <div>
                <p className="text-sm text-gray-600 mb-2 font-medium">
                    Seleccionar Duración
                </p>
                <div className="grid grid-cols-3 gap-2">
                    {plans.map((plan) => {
                        const Icon = plan.icon;
                        return (
                            <button
                                key={plan.id}
                                onClick={() => handleActivatePlan(plan.id as any)}
                                disabled={isLoading}
                                className={`${plan.color} text-white flex flex-col items-center py-3 h-auto rounded-lg shadow-md transition-all hover:scale-105 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed`}
                            >
                                <Icon className="w-5 h-5 mb-1" />
                                <span className="font-semibold">{plan.name}</span>
                                <span className="text-xs opacity-90">{plan.duration}</span>
                            </button>
                        );
                    })}
                </div>
            </div>
        </div>
    );
}
