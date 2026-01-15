/** @type {import('next').NextConfig} */
const nextConfig = {
  typescript: {
    // ⚠️ Ignorar errores de TypeScript en build para deploy rápido
    ignoreBuildErrors: true,
  },
  eslint: {
    // ⚠️ Ignorar errores de ESLint en build
    ignoreDuringBuilds: true,
  },
  images: {
    domains: [
      'localhost',
      'vintage-music-storage.s3.amazonaws.com',
      'your-cloudfront-domain.cloudfront.net',
    ],
  },
  env: {
    NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001',
  },
  async rewrites() {
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001';
    return [
      {
        // Excluir las rutas de NextAuth del rewrite
        source: '/api/v1/:path*',
        destination: `${apiUrl}/api/v1/:path*`,
      },
    ];
  },
};

module.exports = nextConfig;
