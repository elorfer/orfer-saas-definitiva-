import { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
    return {
        rules: [
            {
                userAgent: '*',
                allow: '/',
                disallow: ['/api/', '/admin-orders/', '/success/'],
            },
        ],
        sitemap: 'https://www.struky.com/sitemap.xml',
    };
}
