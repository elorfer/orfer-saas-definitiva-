export interface BlogPost {
    slug: string;
    title: string;
    excerpt: string;
    content: string;
    date: string;
    author: string;
    image: string;
    category: string;
}

export const BLOG_POSTS: BlogPost[] = [
    {
        slug: 'como-crear-canciones-con-ia-guia-completa',
        title: 'Cómo crear canciones con IA: Guía Completa 2024',
        excerpt: 'Descubre el paso a paso para convertir tus letras en hits mundiales utilizando la tecnología de Struky.',
        content: `
            <p>La inteligencia artificial ha revolucionado la forma en que creamos música. Ya no necesitas un estudio de miles de dólares para sonar como un profesional.</p>
            <h2>Paso 1: La idea central</h2>
            <p>Todo gran hit comienza con un sentimiento o una frase. No te preocupes por la rima perfecta todavía. En Struky, nos enfocamos en capturar la esencia de tu mensaje.</p>
            <h2>Paso 2: Elegir el género adecuado</h2>
            <p>¿Es un tema bailable como el reggaetón o algo más introspectivo como el trap? La estructura rítmica dictará cómo fluye tu letra.</p>
            <h2>Paso 3: Producción con Struky</h2>
            <p>Nuestra tecnología no solo genera sonidos; crea texturas. Nuestros productores humanos supervisan cada segundo para asegurar que la calidad sea de nivel Spotify Chart.</p>
        `,
        date: '2024-05-10',
        author: 'Equipo Struky',
        image: 'https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/blog1.webp',
        category: 'Tutoriales'
    },
    {
        slug: '5-consejos-letras-virales-2024',
        title: '5 Consejos para escribir letras que se vuelvan virales',
        excerpt: 'No basta con rimar. Aprende las técnicas de los grandes compositores para conectar con tu audiencia.',
        content: `
            <p>Escribir una canción que la gente quiera repetir una y otra vez es un arte, pero también tiene su ciencia. Aquí te dejamos 5 consejos infalibles:</p>
            <ul>
                <li><strong>Sé específico, no genérico:</strong> En lugar de decir "estoy triste", describe el café frío sobre la mesa.</li>
                <li><strong>El poder del "Hook":</strong> Tu coro debe ser simple y fácil de recordar. Si puedes tararearlo, es bueno.</li>
                <li><strong>Usa lenguaje actual:</strong> No tengas miedo de usar términos que tu audiencia usa en su día a día.</li>
                <li><strong>Cuenta una historia:</strong> Las personas conectan con experiencias, no solo con palabras bonitas.</li>
                <li><strong>Deja espacio para la música:</strong> A veces, menos es más. Deja que el beat respire.</li>
            </ul>
        `,
        date: '2024-05-12',
        author: 'Productor Struky',
        image: 'https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/blog2.webp',
        category: 'Composición'
    },
    {
        slug: 'monetiza-tu-musica-spotify-apple-music',
        title: 'Cómo monetizar tu música en Spotify y Apple Music',
        excerpt: '¿Ya tienes tu canción de Struky? Ahora descubre cómo subirla a plataformas y empezar a ganar dinero.',
        content: `
            <p>Una vez que recibes tu canción profesional de Struky, el siguiente paso es que el mundo la escuche. Y lo mejor: que te paguen por ello.</p>
            <h2>Distribución Digital</h2>
            <p>Para subir tu música a Spotify necesitas una distribuidora. Plataformas como DistroKid o TuneCore son ideales para artistas independientes.</p>
            <h2>Royalties y Derechos</h2>
            <p>Con Struky, tú eres el dueño del 100% de los derechos de autor. Esto significa que todas las ganancias que generen tus reproducciones van directamente a tu bolsillo.</p>
            <p>Asegúrate de registrar tus temas en sociedades de gestión como BMI o ASCAP para no perder ni un centavo de tus regalías de ejecución pública.</p>
        `,
        date: '2024-05-15',
        author: 'Marketing Music',
        image: 'https://pub-cd8d791a454643b3853739c84fd98a3f.r2.dev/blog1.webp',
        category: 'Negocio'
    }
];
