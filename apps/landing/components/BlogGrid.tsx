'use client';

import { useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { Calendar, User, ChevronRight, Clock } from 'lucide-react';
import { BlogPost } from '@/lib/blog-data';
import { getReadingTime } from '@/lib/blog-utils';
import { motion, AnimatePresence } from 'framer-motion';

export default function BlogGrid({ posts }: { posts: BlogPost[] }) {
    const [activeCategory, setActiveCategory] = useState('all');
    const categories = ['all', ...Array.from(new Set(posts.map(p => p.category)))];
    const filtered = activeCategory === 'all' ? posts : posts.filter(p => p.category === activeCategory);

    return (
        <>
            <div className="flex flex-wrap items-center justify-center gap-3 mb-16">
                {categories.map(cat => (
                    <button
                        key={cat}
                        onClick={() => setActiveCategory(cat)}
                        className={`px-5 py-2.5 rounded-full text-[10px] font-black uppercase tracking-widest transition-all duration-300 ${activeCategory === cat ? 'bg-coffee-medium text-black shadow-[0_0_20px_rgba(202,160,82,0.3)]' : 'bg-white/5 text-gray-400 border border-white/10 hover:bg-white/10'}`}
                    >
                        {cat === 'all' ? 'Todos' : cat}
                        {cat !== 'all' && <span className="ml-2 opacity-50">{posts.filter(p => p.category === cat).length}</span>}
                    </button>
                ))}
            </div>

            <p className="text-center text-gray-600 text-xs font-bold uppercase tracking-widest mb-10">
                {filtered.length} {filtered.length === 1 ? 'artículo' : 'artículos'}
            </p>

            <div className="grid md:grid-cols-2 gap-10">
                <AnimatePresence mode="popLayout">
                    {filtered.map((post, i) => (
                        <motion.div key={post.slug} layout initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, scale: 0.95 }} transition={{ duration: 0.3, delay: i * 0.05 }}>
                            <Link href={`/blog/${post.slug}`} className="group block h-full">
                                <article className="bg-[#111] border border-white/5 rounded-[2.5rem] overflow-hidden hover:border-coffee-medium/30 transition-all duration-500 hover:shadow-[0_20px_50px_rgba(202,160,82,0.1)] h-full flex flex-col">
                                    <div className="relative h-64 md:h-80 overflow-hidden">
                                        <Image src={post.image} alt={post.title} fill className="object-cover transition-transform duration-700 group-hover:scale-110" />
                                        <div className="absolute top-6 left-6 bg-coffee-medium text-black text-[10px] font-black uppercase tracking-widest px-4 py-1.5 rounded-full">{post.category}</div>
                                        <div className="absolute top-6 right-6 bg-black/60 backdrop-blur-md text-white text-[10px] font-black uppercase tracking-widest px-3 py-1.5 rounded-full flex items-center gap-1.5 border border-white/10">
                                            <Clock className="w-3 h-3 text-coffee-medium" />{getReadingTime(post.content)} min
                                        </div>
                                    </div>
                                    <div className="p-8 md:p-12 flex-1 flex flex-col">
                                        <div className="flex items-center gap-6 mb-6 text-gray-500 text-[10px] font-black uppercase tracking-widest">
                                            <div className="flex items-center gap-2"><Calendar className="w-3 h-3 text-coffee-medium" />{post.date}</div>
                                            <div className="flex items-center gap-2"><User className="w-3 h-3 text-coffee-medium" />{post.author}</div>
                                        </div>
                                        <h2 className="text-2xl md:text-3xl font-black mb-4 leading-tight group-hover:text-coffee-light transition-colors">{post.title}</h2>
                                        <p className="text-gray-400 text-sm md:text-base leading-relaxed mb-8 flex-1">{post.excerpt}</p>
                                        <div className="flex items-center gap-2 text-coffee-medium font-black uppercase tracking-widest text-xs group-hover:gap-4 transition-all">Leer más <ChevronRight className="w-4 h-4" /></div>
                                    </div>
                                </article>
                            </Link>
                        </motion.div>
                    ))}
                </AnimatePresence>
            </div>
        </>
    );
}
