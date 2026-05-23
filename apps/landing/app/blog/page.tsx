import { BLOG_POSTS } from '@/lib/blog-data';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import BlogGrid from '@/components/BlogGrid';

export const metadata = {
    title: 'Blog de Struky | Producción Musical e IA',
    description: 'Aprende sobre producción musical, inteligencia artificial y cómo lanzar tu carrera musical con Struky.',
    alternates: {
        canonical: 'https://www.struky.com/blog',
    },
};

export default function BlogPage() {
    return (
        <main className="min-h-screen bg-dark-bg text-white font-sans">
            <Header lang="es" />

            <section className="pt-32 pb-20 px-6">
                <div className="max-w-7xl mx-auto">
                    <div className="text-center mb-16">
                        <h1 className="text-4xl md:text-7xl font-black mb-6 tracking-tighter uppercase">
                            BLOG <span className="text-gradient">STRUKY</span>
                        </h1>
                        <p className="text-gray-400 text-lg md:text-xl max-w-2xl mx-auto font-medium">
                            Noticias, tutoriales y tendencias sobre el futuro de la música y la inteligencia artificial.
                        </p>
                    </div>

                    <BlogGrid posts={BLOG_POSTS} />
                </div>
            </section>

            <Footer lang="es" />
        </main>
    );
}
