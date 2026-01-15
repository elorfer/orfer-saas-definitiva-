'use client';

import { useEffect, useState, useRef } from 'react';
import { useSession } from 'next-auth/react';
import { useRouter } from 'next/navigation';

export default function Home() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const [isRedirecting, setIsRedirecting] = useState(false);
  const hasRedirected = useRef(false);

  useEffect(() => {
    // Prevenir múltiples redirects
    if (hasRedirected.current || isRedirecting) return;

    if (status === 'loading') {
      // Timeout de 3 segundos para prevenir infinite loader
      const timeout = setTimeout(() => {
        if (status === 'loading' && !session) {
          hasRedirected.current = true;
          setIsRedirecting(true);
          router.replace('/login');
        }
      }, 3000);

      return () => clearTimeout(timeout);
    }

    if (status === 'authenticated' && session) {
      hasRedirected.current = true;
      setIsRedirecting(true);
      router.replace('/dashboard');
    } else if (status === 'unauthenticated') {
      hasRedirected.current = true;
      setIsRedirecting(true);
      router.replace('/login');
    }
  }, [session, status, router, isRedirecting]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-brown-50 to-amber-50">
      <div className="text-center">
        <div className="animate-spin rounded-full h-16 w-16 border-4 border-brown-700 border-t-transparent mx-auto mb-4"></div>
        <p className="text-gray-600 font-medium">
          {isRedirecting ? 'Redirigiendo...' : 'Cargando...'}
        </p>
      </div>
    </div>
  );
}
