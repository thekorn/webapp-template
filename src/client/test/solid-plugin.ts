import { plugin } from 'bun';
import { transformSync } from '@babel/core';
import { resolve } from 'node:path';

const solidWebClient = resolve(import.meta.dir, '../../../node_modules/solid-js/web/dist/web.js');
const solidClient = resolve(import.meta.dir, '../../../node_modules/solid-js/dist/solid.js');

await plugin({
  name: 'solid-jsx',
  async setup(build) {
    build.onResolve({ filter: /^solid-js\/web$/ }, () => {
      return { path: solidWebClient };
    });

    build.onResolve({ filter: /^solid-js$/ }, () => {
      return { path: solidClient };
    });

    build.onLoad({ filter: /\.tsx$/ }, async (args) => {
      const file = Bun.file(args.path);
      const code = await file.text();

      const result = transformSync(code, {
        filename: args.path,
        presets: [
          ['@babel/preset-typescript', { isTSX: true, allExtensions: true }],
          ['babel-preset-solid'],
        ],
      });

      return {
        contents: result?.code ?? '',
        loader: 'js',
      };
    });
  },
});
