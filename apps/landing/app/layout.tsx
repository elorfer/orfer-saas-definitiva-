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
            { url: '/logo.svg', sizes: 'any', type: 'image/svg+xml' },
            { url: '/logo.svg', sizes: '32x32', type: 'image/svg+xml' },
        ],
        shortcut: '/logo.svg',
        apple: [
            { url: '/logo.svg', sizes: '180x180', type: 'image/svg+xml' },
        ],
    },
    openGraph: {
        title: "Struky | Producción Musical Profesional con IA",
        description: "Tus letras, convertidas en música profesional con IA",
        url: 'https://www.struky.com',
        siteName: 'Struky Music',
        images: [
            {
                url: '/og-image.png',
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
        images: ['/og-image.png'],
    },
};

export default function RootLayout({
    children,
}: Readonly<{
    children: React.ReactNode;
}>) {
    return (
        <html lang="es" className={`${inter.variable} ${montserrat.variable} ${outfit.variable}`} suppressHydrationWarning>
            <body className={inter.className} suppressHydrationWarning>
                {/* Meta Pixel Script */}
                <Script id="fb-pixel" strategy="afterInteractive">
                    {`
                        !function(f,b,e,v,n,t,s)
                        {if(f.fbq)return;n=f.fbq=function(){n.callMethod?
                        n.callMethod.apply(n,arguments):n.queue.push(arguments)};
                        if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
                        n.queue=[];t=b.createElement(e);t.async=!0;
                        t.src=v;s=b.getElementsByTagName(e)[0];
                        s.parentNode.insertBefore(t,s)}(window, document,'script',
                        'https://connect.facebook.net/en_US/fbevents.js');
                        fbq('init', '${process.env.NEXT_PUBLIC_META_PIXEL_ID || "1445433937281922"}');
                        fbq('track', 'PageView');
                    `}
                </Script>
                <noscript>
                    <img 
                        height="1" 
                        width="1" 
                        style={{ display: "none" }}
                        src={`https://www.facebook.com/tr?id=${process.env.NEXT_PUBLIC_META_PIXEL_ID || "1445433937281922"}&ev=PageView&noscript=1`}
                        alt=""
                    />
                </noscript>

                <Script
                    src="https://app.lemonsqueezy.com/js/lemon.js"
                    strategy="afterInteractive"
                />
                {children}
                <WhatsAppButton />
            </body>
        </html>
    );
}
