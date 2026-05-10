import { BLOG_POSTS } from '@/lib/blog-data';
import Link from 'next/link';
import Image from 'next/image';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import { Calendar, User, ChevronRight } from 'lucide-react';

export const metadata = {
    title: 'Blog de Struky | Producción Musical e IA',
    description: 'Aprende sobre producción musical, inteligencia artificial y cómo lanzar tu carrera musical con Struky.',
};

export default function BlogPage() {
    return (
        <main className="min-h-screen bg-dark-bg text-white font-sans">
            <Header lang="es" setLang={() => {}} />
            
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

                    <div className="grid md:grid-cols-2 lg:grid-cols-2 gap-10">
                        {BLOG_POSTS.map((post) => (
                            <Link key={post.slug} href={`/blog/${post.slug}`} className="group">
                                <article className="bg-[#111] border border-white/5 rounded-[2.5rem] overflow-hidden hover:border-coffee-medium/30 transition-all duration-500 hover:shadow-[0_20px_50px_rgba(202,160,82,0.1)] h-full flex flex-col">
                                    <div className="relative h-64 md:h-80 overflow-hidden">
                                        <Image 
                                            src={post.image} 
                                            alt={post.title}
                                            fill
                                            className="object-cover transition-transform duration-700 group-hover:scale-110"
                                        />
                                        <div className="absolute top-6 left-6 bg-coffee-medium text-black text-[10px] font-black uppercase tracking-widest px-4 py-1.5 rounded-full">
                                            {post.category}
                                        </div>
                                    </div>
                                    
                                    <div className="p-8 md:p-12 flex-1 flex flex-col">
                                        <div className="flex items-center gap-6 mb-6 text-gray-500 text-[10px] font-black uppercase tracking-widest">
                                            <div className="flex items-center gap-2">
                                                <Calendar className="w-3 h-3 text-coffee-medium" />
                                                {post.date}
                                            </div>
                                            <div className="flex items-center gap-2">
                                                <User className="w-3 h-3 text-coffee-medium" />
                                                {post.author}
                                            </div>
                                        </div>

                                        <h2 className="text-2xl md:text-3xl font-black mb-4 leading-tight group-hover:text-coffee-light transition-colors">
                                            {post.title}
                                        </h2>
                                        
                                        <p className="text-gray-400 text-sm md:text-base leading-relaxed mb-8 flex-1">
                                            {post.excerpt}
                                        </p>

                                        <div className="flex items-center gap-2 text-coffee-medium font-black uppercase tracking-widest text-xs group-hover:gap-4 transition-all">
                                            Leer más <ChevronRight className="w-4 h-4" />
                                        </div>
                                    </div>
                                </article>
                            </Link>
                        ))}
                    </div>
                </div>
            </section>

            <Footer lang="es" />
        </main>
    );
}
