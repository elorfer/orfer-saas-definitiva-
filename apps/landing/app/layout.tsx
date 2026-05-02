import type { Metadata } from "next";
import { Inter, Montserrat, Outfit } from "next/font/google";
import "./globals.css";
import Script from "next/script";
import WhatsAppButton from "../components/WhatsAppButton";

const inter = Inter({
    subsets: ["latin"],
    variable: '--font-inter',
    display: 'swap',
});

const montserrat = Montserrat({
    subsets: ["latin"],
    weight: ['700', '800', '900'],
    variable: '--font-montserrat',
    display: 'swap',
});

const outfit = Outfit({
    subsets: ["latin"],
    weight: ['400', '500', '600', '700', '800', '900'],
    variable: '--font-outfit',
    display: 'swap',
});

export const metadata: Metadata = {
    title: "Struky | Producción Musical Profesional con IA",
    description: "Tus letras, convertidas en música profesional con IA. Producción musical experta supervisada por humanos.",
    keywords: "producción musical, IA, inteligencia artificial, música, letras, canciones, reggaetón, trap, pop",
    metadataBase: new URL('https://www.struky.com'),
    icons: {
        icon: [
            { url: '/examples/logoblanco web p25).webp', sizes: 'any', type: 'image/webp' },
            { url: '/examples/logoblanco web p25).webp', sizes: '32x32', type: 'image/webp' },
        ],
        shortcut: '/examples/logoblanco web p25).webp',
        apple: [
            { url: '/examples/logoblanco web p25).webp', sizes: '180x180', type: 'image/webp' },
        ],
    },
    openGraph: {
        title: "Struky | Producción Musical Profesional con IA",
        description: "Tus letras, convertidas en música profesional con IA",
        url: 'https://www.struky.com',
        siteName: 'Struky Music',
        images: [
            {
                url: '/examples/wat.webp',
                width: 1200,
                height: 630,
                alt: 'Struky Music AI Social Card',
            },
        ],
        locale: 'es_ES',
        type: 'website',
    },
    twitter: {
        card: 'summary_large_image',
        title: "Struky | Producción Musical Profesional con IA",
        description: "Tus letras, convertidas en música profesional con IA",
        images: ['/examples/wat.webp'],
    },
};

export default function RootLayout({
    children,
}: Readonly<{
    children: React.ReactNode;
}>) {
    return (
        <html lang="es" className={`${inter.variable} ${montserrat.variable} ${outfit.variable}`} suppressHydrationWarning>
            <head>
                {/* Preconnect to external domains for faster handshakes */}
                <link rel="preconnect" href="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev" />
                <link rel="preconnect" href="https://player.vimeo.com" />
                <link rel="preconnect" href="https://connect.facebook.net" />
                <link rel="dns-prefetch" href="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev" />
                
                {/* Preload critical hero assets */}
                <link rel="preload" as="image" href="/hero-bg.png" />
            </head>
            <body className={inter.className} suppressHydrationWarning>
                {/* Meta Pixel Script */}
                <Script id="fb-pixel" strategy="lazyOnload">
                    {`
                        !function(f,b,e,v,n,t,s)
                        {if(f.fbq)return;n=f.fbq=function(){n.callMethod?
                        n.callMethod.apply(n,arguments):n.queue.push(arguments)};
                        if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
                        n.queue=[];t=b.createElement(e);t.async=!0;
                        t.src=v;s=b.getElementsByTagName(e)[0];
                        s.parentNode.insertBefore(t,s)}(window, document,'script',
                        'https://connect.facebook.net/en_US/fbevents.js');
                        fbq('set', 'autoConfig', false, '${process.env.NEXT_PUBLIC_META_PIXEL_ID || "1681899642811715"}');
                        fbq('init', '${process.env.NEXT_PUBLIC_META_PIXEL_ID || "1681899642811715"}');
                        fbq('track', 'PageView');
                    `}
                </Script>
                <noscript>
                    <img 
                        height="1" 
                        width="1" 
                        style={{ display: "none" }}
                        src={`https://www.facebook.com/tr?id=${process.env.NEXT_PUBLIC_META_PIXEL_ID || "1681899642811715"}&ev=PageView&noscript=1`}
                        alt=""
                    />
                </noscript>

                <Script
                    src="https://app.lemonsqueezy.com/js/lemon.js"
                    strategy="lazyOnload"
                />
                {children}
                <WhatsAppButton />
            </body>
        </html>
    );
}
