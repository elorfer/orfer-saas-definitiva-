import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

const APP_URL = "https://manifiestas.ai";

export const metadata: Metadata = {
  metadataBase: new URL(APP_URL),
  title: {
    default: "Manifiestas AI — Tu Coach de Manifestación con IA",
    template: "%s | Manifiestas AI",
  },
  description:
    "Reprograma tu mente, decreta afirmaciones personalizadas y atrae la vida que mereces con tu coach de manifestación personal disponible 24/7.",
  keywords: [
    "manifestación",
    "ley de atracción",
    "coach espiritual",
    "afirmaciones",
    "reprogramación mental",
    "inteligencia artificial",
    "coach IA",
    "abundancia",
    "meditación",
    "mentalidad positiva",
  ],
  authors: [{ name: "Manifiestas AI" }],
  creator: "Manifiestas AI",
  publisher: "Manifiestas AI",
  robots: {
    index: true,
    follow: true,
  },
  alternates: {
    canonical: APP_URL,
  },
  openGraph: {
    type: "website",
    url: APP_URL,
    siteName: "Manifiestas AI",
    title: "Manifiestas AI — Tu Coach de Manifestación con IA",
    description:
      "Reprograma tu mente, decreta afirmaciones personalizadas y atrae la vida que mereces. Tu coach espiritual personal disponible 24/7.",
    locale: "es_ES",
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: "Manifiestas AI — Coach de Manifestación con Inteligencia Artificial",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Manifiestas AI — Tu Coach de Manifestación con IA",
    description:
      "Reprograma tu mente y atrae la vida que mereces. Coach espiritual con IA disponible 24/7.",
    images: ["/og-image.png"],
    creator: "@manifiestas_ai",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="es"
      className={`${geistSans.variable} ${geistMono.variable} h-full antialiased scroll-smooth`}
      suppressHydrationWarning
    >
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              (function() {
                try {
                  var theme = localStorage.getItem('theme');
                  if (theme === 'dark' || (!theme && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
                    document.documentElement.classList.add('dark');
                  } else {
                    document.documentElement.classList.remove('dark');
                  }
                } catch (e) {}
              })();
            `,
          }}
        />
      </head>
      <body className="min-h-full">
        {children}
      </body>
    </html>
  );
}

