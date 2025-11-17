import { NextAuthOptions } from 'next-auth';
import CredentialsProvider from 'next-auth/providers/credentials';
import { api } from './api';
import { config } from '@/config/env';

// Asegurar que el secret tenga al menos 32 caracteres (requisito de NextAuth)
const nextAuthSecret = config.nextAuth.secret || process.env.NEXTAUTH_SECRET || 'vintage-music-admin-secret-key-2024-development';
if (nextAuthSecret.length < 32) {
  console.warn('NEXTAUTH_SECRET es muy corto. Debe tener al menos 32 caracteres.');
}

export const authOptions: NextAuthOptions = {
  providers: [
    CredentialsProvider({
      name: 'credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        console.log('[NextAuth] authorize llamado con:', { email: credentials?.email });
        
        if (!credentials?.email || !credentials?.password) {
          console.log('[NextAuth] authorize: credenciales faltantes');
          return null;
        }

        try {
          // Credenciales de desarrollo (opcional, controlado por variable de entorno)
          const enableDevAuth = process.env.NEXT_PUBLIC_ENABLE_DEV_AUTH === 'true';
          if (enableDevAuth) {
            if (credentials.email === 'admin@vintagemusic.com' && credentials.password === 'admin123') {
              console.log('[NextAuth] authorize: dev auth habilitado y credenciales válidas');
              const user = {
                id: 'dev-admin-001',
                email: credentials.email,
                name: 'Admin Vintage',
                role: 'admin',
                // Nota: este token no sirve contra el backend; usar solo en modo mock
                accessToken: 'dev-token-123',
              };
              console.log('[NextAuth] authorize: retornando usuario (dev):', user);
              return user;
            }
          }

          // Autenticación real con backend
          try {
            const response = await api.post('/auth/login', {
              email: credentials.email,
              password: credentials.password,
            });

            const { access_token, user } = response.data;

            if (user.role !== 'admin') {
              return null;
            }

            return {
              id: user.id,
              email: user.email,
              name: `${user.firstName} ${user.lastName}`,
              role: user.role,
              accessToken: access_token,
            };
          } catch (apiError) {
            // Si el backend no está disponible, retornar null
            console.error('Error al conectar con el backend:', apiError);
            return null;
          }
        } catch (error) {
          console.error('Error en autenticación:', error);
          return null;
        }
      },
    }),
  ],
  callbacks: {
    async jwt({ token, user }) {
      // Primera vez que se crea el JWT (cuando el usuario hace login)
      if (user) {
        console.log('[NextAuth] jwt callback: usuario recibido', { id: user.id, email: user.email });
        token.id = user.id;
        token.email = user.email;
        token.name = user.name;
        token.accessToken = (user as any).accessToken;
        token.role = (user as any).role;
      } else {
        console.log('[NextAuth] jwt callback: sin usuario, usando token existente', { id: token.id, email: token.email });
      }
      return token;
    },
    async session({ session, token }) {
      // Pasar la información del token a la sesión
      console.log('[NextAuth] session callback: token recibido', { id: token.id, email: token.email });
      if (token && session.user) {
        session.user.id = token.id as string;
        session.user.email = token.email as string;
        session.user.name = token.name as string;
        session.user.role = token.role as string;
        (session as any).accessToken = token.accessToken as string;
        console.log('[NextAuth] session callback: sesión creada', { id: session.user.id, email: session.user.email });
      }
      return session;
    },
    async redirect({ url, baseUrl }) {
      // Si hay un error, redirigir al login
      if (url.includes('/api/auth/error')) {
        return `${baseUrl}/login`;
      }
      // Si es login exitoso, redirigir al dashboard
      if (url === `${baseUrl}/api/auth/signin` || url === `${baseUrl}/login`) {
        return `${baseUrl}/dashboard`;
      }
      // Redirigir al dashboard después del login
      if (url.startsWith('/')) return `${baseUrl}${url}`;
      if (new URL(url).origin === baseUrl) return url;
      return `${baseUrl}/dashboard`;
    },
  },
  pages: {
    signIn: '/login',
    error: '/login', // Usar la página de login para errores también
  },
  session: {
    strategy: 'jwt',
    maxAge: 7 * 24 * 60 * 60, // 7 días
  },
  secret: nextAuthSecret,
  debug: process.env.NODE_ENV === 'development', // Habilitar debug en desarrollo
};


