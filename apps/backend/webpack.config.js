const path = require('path');

module.exports = function (options, webpack) {
  const lazyImports = [
    '@nestjs/microservices/microservices-module',
    '@nestjs/websockets/socket-module',
    'music-metadata', // Excluir music-metadata del bundle
  ];

  return {
    ...options,
    resolve: {
      ...options.resolve,
      extensions: ['.ts', '.js', '.json'],
      mainFiles: ['index', 'main'],
      alias: {
        ...options.resolve?.alias,
        '@': path.resolve(__dirname, 'src'),
        '@/common': path.resolve(__dirname, 'src/common'),
        '@/modules': path.resolve(__dirname, 'src/modules'),
        '@/database': path.resolve(__dirname, 'src/database'),
      },
    },
    externals: {
      'music-metadata': 'commonjs music-metadata', // Tratar como módulo externo
    },
    plugins: [
      ...options.plugins,
      new webpack.IgnorePlugin({
        checkResource(resource) {
          if (lazyImports.includes(resource)) {
            try {
              require.resolve(resource);
            } catch (err) {
              return true;
            }
          }
          return false;
        },
      }),
    ],
  };
};

