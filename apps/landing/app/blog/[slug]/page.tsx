import { BLOG_POSTS } from '@/lib/blog-data';
import { notFound } from 'next/navigation';
import Image from 'next/image';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import { Calendar, User, ChevronLeft, Share2, Clock, ChevronRight } from 'lucide-react';
import Link from 'next/link';
import { getReadingTime, getRelatedPosts } from '@/lib/blog-utils';
import ImageZoom from '@/components/ImageZoom';

export async function generateStaticParams() {
    return BLOG_POSTS.map(post => ({ slug: post.slug }));
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
    const { slug } = await params;
    const post = BLOG_POSTS.find(p => p.slug === slug);
    if (!post) return {};
    return {
        title: `${post.title} | Blog Struky`,
        description: post.excerpt,
        openGraph: { images: [post.image] },
        alternates: {
            canonical: `https://www.struky.com/blog/${post.slug}`,
        },
    };
}

export default async function BlogPostPage({ params }: { params: Promise<{ slug: string }> }) {
    const { slug } = await params;
    const post = BLOG_POSTS.find(p => p.slug === slug);
    if (!post) notFound();

    const readingTime = getReadingTime(post.content);
    const relatedPosts = getRelatedPosts(post.slug, post.category, BLOG_POSTS);

    const jsonLd = {
        '@context': 'https://schema.org',
        '@type': 'BlogPosting',
        headline: post.title,
        description: post.excerpt,
        image: post.image,
        datePublished: post.date,
        author: { '@type': 'Organization', name: post.author },
        publisher: {
            '@type': 'Organization',
            name: 'Struky',
            logo: { '@type': 'ImageObject', url: 'https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/logoblanco%20web%20p25).webp' },
        },
        mainEntityOfPage: { '@type': 'WebPage', '@id': `https://www.struky.com/blog/${post.slug}` },
        wordCount: post.content.replace(/<[^>]*>/g, '').split(/\s+/).length,
        articleSection: post.category,
    };

    return (
        <main className="min-h-screen bg-dark-bg text-white font-sans">
            <Header lang="es" />

            {/* JSON-LD Structured Data for SEO */}
            <script
                type="application/ld+json"
                dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
            />

            <article className="pt-32 pb-20">
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
                        <div className="flex items-center gap-2">
                            <Clock className="w-4 h-4 text-coffee-medium" />
                            {readingTime} min de lectura
                        </div>
                        <button className="flex items-center gap-2 hover:text-white transition-colors ml-auto">
                            <Share2 className="w-4 h-4" /> Compartir
                        </button>
                    </div>
                </header>

                <div className="max-w-5xl mx-auto px-6 mb-16">
                    <div className="relative h-[300px] md:h-[500px] rounded-[3rem] overflow-hidden border border-white/10 shadow-2xl">
                        <ImageZoom 
                            src={post.image} 
                            alt={post.title}
                        />
                    </div>
                </div>

                <div
                    className="max-w-3xl mx-auto px-6 prose prose-invert prose-p:text-gray-400 prose-headings:text-white prose-headings:font-black prose-headings:uppercase prose-headings:tracking-tighter prose-h2:text-3xl prose-h2:mt-12 prose-p:leading-relaxed prose-p:text-lg"
                    dangerouslySetInnerHTML={{ __html: post.content }}
                />

                {/* Post CTA */}
                <footer className="max-w-3xl mx-auto px-6 mt-20 pt-10 border-t border-white/5 text-center">
                    <h3 className="text-xl font-black uppercase mb-6">¿Quieres sonar así?</h3>
                    <p className="text-gray-400 mb-8">
                        Convierte tus propias letras en una producción musical de clase mundial hoy mismo.
                    </p>
                    <Link href="/#order-form" className="btn-primary inline-flex">
                        EMPEZAR MI CANCIÓN
                    </Link>
                </footer>

                {/* Related Posts */}
                {relatedPosts.length > 0 && (
                    <section className="max-w-5xl mx-auto px-6 mt-24">
                        <h3 className="text-2xl md:text-3xl font-black mb-10 tracking-tighter uppercase text-center">
                            Artículos <span className="text-gradient">Relacionados</span>
                        </h3>
                        <div className="grid md:grid-cols-3 gap-8">
                            {relatedPosts.map(related => (
                                <Link key={related.slug} href={`/blog/${related.slug}`} className="group">
                                    <article className="bg-[#111] border border-white/5 rounded-2xl overflow-hidden hover:border-coffee-medium/30 transition-all duration-500 h-full flex flex-col">
                                        <div className="relative h-48 overflow-hidden">
                                            <Image src={related.image} alt={related.title} fill className="object-cover transition-transform duration-700 group-hover:scale-110" />
                                        </div>
                                        <div className="p-6 flex-1 flex flex-col">
                                            <h4 className="text-base font-black mb-3 leading-tight group-hover:text-coffee-light transition-colors">{related.title}</h4>
                                            <p className="text-gray-500 text-xs leading-relaxed flex-1 mb-4 line-clamp-2">{related.excerpt}</p>
                                            <div className="flex items-center gap-2 text-coffee-medium font-black uppercase tracking-widest text-[10px] group-hover:gap-3 transition-all">
                                                Leer <ChevronRight className="w-3 h-3" />
                                            </div>
                                        </div>
                                    </article>
                                </Link>
                            ))}
                        </div>
                    </section>
                )}
            </article>

            <Footer lang="es" />
        </main>
    );
}
