import type { Metadata } from "next";
import { Inter, Montserrat } from "next/font/google";
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

export const metadata: Metadata = {
    title: "Struky | Producción Musical Profesional con IA",
    description: "Tus letras, convertidas en música profesional con IA. Producción musical experta supervisada por humanos.",
    keywords: "producción musical, IA, inteligencia artificial, música, letras, canciones, reggaetón, trap, pop",
    metadataBase: new URL('https://www.struky.com'),
    alternates: {
        canonical: 'https://www.struky.com',
    },
    openGraph: {
        title: "Struky | Producción Musical Profesional con IA",
        description: "Tus letras, convertidas en música profesional con IA",
        url: 'https://www.struky.com',
        siteName: 'Struky Music',
        images: [
            {
                url: 'https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/social-card.png',
                width: 1200,
                height: 630,
                type: 'image/png',
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
        images: ['https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/social-card.png'],
    },
    icons: {
        icon: [
            { url: 'https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/logoblanco%20web%20p25).webp', sizes: 'any', type: 'image/webp' },
            { url: 'https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/logoblanco%20web%20p25).webp', sizes: '32x32', type: 'image/webp' },
        ],
        shortcut: 'https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/logoblanco%20web%20p25).webp',
        apple: [
            { url: 'https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/logoblanco%20web%20p25).webp', sizes: '180x180', type: 'image/webp' },
        ],
    },
    verification: {
        google: 'XSu4rNOuOJtvmlXmWn0wYLb6fJ8jZCPgIuIDOZJ6TRU',
    },
};

import { headers, cookies } from "next/headers";
import { sendMetaEvent } from "@/lib/meta-capi";

export default async function RootLayout({
    children,
}: Readonly<{
    children: React.ReactNode;
}>) {
    const headersList = await headers();
    const cookieStore = await cookies();
    
    const userAgent = headersList.get('user-agent') || '';
    const ip = headersList.get('x-forwarded-for')?.split(',')[0] || headersList.get('x-real-ip') || '';
    const fbp = cookieStore.get('_fbp')?.value;
    const fbc = cookieStore.get('_fbc')?.value;
    
    // Generate unique Event ID for PageView deduplication
    const eventID = `pv_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;

    // Fire CAPI PageView (don't await to avoid blocking render)
    sendMetaEvent({
        eventName: 'PageView',
        eventID,
        userData: {
            clientIpAddress: ip,
            clientUserAgent: userAgent,
            fbp,
            fbc
        },
        sourceUrl: 'https://www.struky.com/'
    }).catch(err => console.error('Error in PageView CAPI:', err));

    return (
        <html lang="es" className={`${inter.variable} ${montserrat.variable}`} suppressHydrationWarning>
            <head>
                {/* === CRITICAL: Raw OG tags for WhatsApp (its crawler does NOT execute JS) === */}
                <meta property="og:image" content="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/social-card.png" />
                <meta property="og:image:width" content="1200" />
                <meta property="og:image:height" content="630" />
                <meta property="og:image:type" content="image/png" />
                <meta name="twitter:image" content="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/social-card.png" />

                {/* Preconnect to external domains for faster handshakes */}
                <link rel="preconnect" href="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev" />
                <link rel="preconnect" href="https://player.vimeo.com" />
                <link rel="preconnect" href="https://connect.facebook.net" />
                <link rel="dns-prefetch" href="https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev" />
                
                {/* Preload critical hero assets */}
                <link rel="preload" as="image" href="/hero-bg.jpg" />
            </head>
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
                        fbq('set', 'autoConfig', false, '${process.env.NEXT_PUBLIC_META_PIXEL_ID || "1681899642811715"}');
                        fbq('init', '${process.env.NEXT_PUBLIC_META_PIXEL_ID || "1681899642811715"}');
                        fbq('track', 'PageView', {}, { eventID: '${eventID}' });

                        // Capture fbclid for CAPI (fbc parameter) — persist to cookie + localStorage
                        // IMPORTANT: Only create fbc ONCE when user first lands with fbclid.
                        // Never re-construct with a new timestamp — Meta flags this as "modified fbclid".
                        const urlParams = new URLSearchParams(window.location.search);
                        const fbclid = urlParams.get('fbclid');
                        if (fbclid) {
                            // Check if we already have an fbc cookie (don't overwrite with new timestamp)
                            const existingFbc = document.cookie.split('; ').find(c => c.startsWith('_fbc='));
                            if (!existingFbc) {
                                const now = Date.now();
                                const fbc = 'fb.1.' + now + '.' + fbclid;
                                document.cookie = '_fbc=' + fbc + '; path=/; max-age=' + (60 * 60 * 24 * 90) + '; SameSite=Lax';
                                try { localStorage.setItem('_struky_fbc', fbc); localStorage.setItem('_struky_fbclid', fbclid); } catch(e) {}
                            }
                        }
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


                {children}
                <WhatsAppButton />
            </body>
        </html>
    );
}
