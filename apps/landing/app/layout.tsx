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
    metadataBase: new URL('https://struky.com'), // Reemplazar por el dominio real cuando esté listo
    openGraph: {
        title: "Struky | Producción Musical Profesional con IA",
        description: "Tus letras, convertidas en música profesional con IA",
        url: 'https://struky.com',
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
