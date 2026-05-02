/** @type {import('next').NextConfig} */
const nextConfig = {
    reactStrictMode: true,
    images: {
        qualities: [75, 85, 90, 100],
        remotePatterns: [
            {
                protocol: 'https',
                hostname: 'pub-cd8d791a454643b3853739c84fd98a3f.r2.dev',
                port: '',
                pathname: '/**',
            },
        ],
    },
}

module.exports = nextConfig
