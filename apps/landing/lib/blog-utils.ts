import { BlogPost } from './blog-data';

/**
 * Estimate reading time from HTML content (200 words/min average)
 */
export function getReadingTime(htmlContent: string): number {
    const text = htmlContent.replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
    const wordCount = text.split(' ').length;
    return Math.max(1, Math.ceil(wordCount / 200));
}

/**
 * Get related posts by category, excluding the current post
 */
export function getRelatedPosts(
    currentSlug: string,
    category: string,
    posts: BlogPost[],
    limit = 3
): BlogPost[] {
    return posts
        .filter(p => p.slug !== currentSlug && p.category === category)
        .slice(0, limit);
}

/**
 * Get all unique categories from posts
 */
export function getCategories(posts: BlogPost[]): string[] {
    return Array.from(new Set(posts.map(p => p.category)));
}
