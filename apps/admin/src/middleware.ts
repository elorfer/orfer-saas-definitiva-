import { withAuth } from 'next-auth/middleware';

export default withAuth(
  function middleware(req) {
    // Aquí puedes agregar lógica adicional si es necesario
  },
  {
    callbacks: {
      authorized: ({ token, req }) => {
        const pathname = req.nextUrl.pathname;
        
        // Permitir acceso a la página de login sin token
        if (pathname === '/login') {
          return true;
        }
        
        // Permitir acceso a las rutas de NextAuth sin token (sesión, callback, etc.)
        if (pathname.startsWith('/api/auth/')) {
          return true;
        }
        
        // Requerir token para todas las demás rutas protegidas
        return !!token;
      },
    },
  }
);

export const config = {
  // Solo proteger rutas específicas, NO todas las rutas /api
  matcher: ['/dashboard/:path*'],
};


