import type { Metadata } from "next";
import { Inter, Montserrat } from "next/font/google";
import "./globals.css";
import Script from "next/script";

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
    openGraph: {
        title: "Struky | Producción Musical Profesional con IA",
        description: "Tus letras, convertidas en música profesional con IA",
        type: "website",
    },
};

export default function RootLayout({
    children,
}: Readonly<{
    children: React.ReactNode;
}>) {
    return (
        <html lang="es" className={`${inter.variable} ${montserrat.variable}`} suppressHydrationWarning>
            <body className={inter.className} suppressHydrationWarning>
                <Script
                    src="https://app.lemonsqueezy.com/js/lemon.js"
                    strategy="afterInteractive"
                />
                {children}
            </body>
        </html>
    );
}
