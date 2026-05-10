import { BLOG_POSTS } from '@/lib/blog-data';
import { notFound } from 'next/navigation';
import Image from 'next/image';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import { Calendar, User, ChevronLeft, Share2 } from 'lucide-react';
import Link from 'next/link';

export async function generateMetadata({ params }: { params: { slug: string } }) {
    const post = BLOG_POSTS.find(p => p.slug === params.slug);
    if (!post) return {};

    return {
        title: `${post.title} | Blog Struky`,
        description: post.excerpt,
        openGraph: {
            images: [post.image],
        },
    };
}

export default function BlogPostPage({ params }: { params: { slug: string } }) {
    const post = BLOG_POSTS.find(p => p.slug === params.slug);

    if (!post) {
        notFound();
    }

    return (
        <main className="min-h-screen bg-dark-bg text-white font-sans">
            <Header lang="es" setLang={() => {}} />

            <article className="pt-32 pb-20">
                {/* Hero del Post */}
                <header className="max-w-4xl mx-auto px-6 mb-12">
                    <Link href="/blog" className="inline-flex items-center gap-2 text-gray-500 hover:text-coffee-medium transition-colors mb-8 text-[10px] font-black uppercase tracking-widest">
                        <ChevronLeft className="w-4 h-4" /> Volver al blog
                    </Link>
                    
                    <div className="bg-coffee-medium text-black text-[10px] font-black uppercase tracking-widest px-4 py-1.5 rounded-full inline-block mb-6">
                        {post.category}
                    </div>
                    
                    <h1 className="text-4xl md:text-6xl font-black mb-8 leading-[1.1] tracking-tighter uppercase">
                        {post.title}
                    </h1>

                    <div className="flex flex-wrap items-center gap-8 text-gray-500 text-[10px] font-black uppercase tracking-widest border-y border-white/5 py-6">
                        <div className="flex items-center gap-2">
                            <Calendar className="w-4 h-4 text-coffee-medium" />
                            {post.date}
                        </div>
                        <div className="flex items-center gap-2">
                            <User className="w-4 h-4 text-coffee-medium" />
                            {post.author}
                        </div>
                        <button className="flex items-center gap-2 hover:text-white transition-colors ml-auto">
                            <Share2 className="w-4 h-4" /> Compartir
                        </button>
                    </div>
                </header>

                <div className="max-w-5xl mx-auto px-6 mb-16">
                    <div className="relative h-[300px] md:h-[500px] rounded-[3rem] overflow-hidden border border-white/10">
                        <Image 
                            src={post.image} 
                            alt={post.title}
                            fill
                            className="object-cover"
                            priority
                        />
                    </div>
                </div>

                {/* Contenido del Post */}
                <div 
                    className="max-w-3xl mx-auto px-6 prose prose-invert prose-p:text-gray-400 prose-headings:text-white prose-headings:font-black prose-headings:uppercase prose-headings:tracking-tighter prose-h2:text-3xl prose-h2:mt-12 prose-p:leading-relaxed prose-p:text-lg"
                    dangerouslySetInnerHTML={{ __html: post.content }}
                />

                {/* Footer del Post */}
                <footer className="max-w-3xl mx-auto px-6 mt-20 pt-10 border-t border-white/5 text-center">
                    <h3 className="text-xl font-black uppercase mb-6">¿Quieres sonar así?</h3>
                    <p className="text-gray-400 mb-8">
                        Convierte tus propias letras en una producción musical de clase mundial hoy mismo.
                    </p>
                    <Link href="/#order-form" className="btn-primary inline-flex">
                        EMPEZAR MI CANCIÓN
                    </Link>
                </footer>
            </article>

            <Footer lang="es" />
        </main>
    );
}
