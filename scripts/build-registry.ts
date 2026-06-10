import { globSync } from 'glob';
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

export interface PluginEntry {
  name: string;
  version: string;
  description: string;
  author: string;
  installPath: string;
}

export interface Registry {
  version: number;
  generatedAt: string;
  plugins: PluginEntry[];
}

export function buildRegistry(rootDir: string): Registry {
  const manifests = globSync('plugins/*/plugin.json', { cwd: rootDir });

  const plugins: PluginEntry[] = manifests.map((manifestPath) => {
    const raw = readFileSync(resolve(rootDir, manifestPath), 'utf-8');
    const plugin = JSON.parse(raw) as Record<string, string>;
    return {
      name: plugin.name,
      version: plugin.version,
      description: plugin.description ?? '',
      author: plugin.author ?? '',
      installPath: dirname(manifestPath).replace(/\\/g, '/'),
    };
  });

  return { version: 1, generatedAt: new Date().toISOString(), plugins };
}

const isMain = process.argv[1] === fileURLToPath(import.meta.url);
if (isMain) {
  const rootDir = resolve(process.cwd());
  const registry = buildRegistry(rootDir);
  const json = JSON.stringify(registry, null, 2);

  mkdirSync(resolve(rootDir, 'site/src/data'), { recursive: true });
  mkdirSync(resolve(rootDir, 'site/public'), { recursive: true });
  writeFileSync(resolve(rootDir, 'site/src/data/registry.json'), json);
  writeFileSync(resolve(rootDir, 'site/public/registry.json'), json);
  console.log(`Registry built: ${registry.plugins.length} plugin(s)`);
}
