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

export interface MarketplacePlugin {
  name: string;
  version: string;
  description: string;
  author: { name: string };
  source: string;
}

export interface Marketplace {
  name: string;
  owner: { name: string };
  plugins: MarketplacePlugin[];
}

export function buildMarketplace(rootDir: string, marketplaceName: string, ownerName: string): Marketplace {
  const manifests = globSync('plugins/*/plugin.json', { cwd: rootDir });

  const plugins: MarketplacePlugin[] = manifests.map((manifestPath) => {
    const raw = readFileSync(resolve(rootDir, manifestPath), 'utf-8');
    const plugin = JSON.parse(raw) as Record<string, string>;
    return {
      name: plugin.name,
      version: plugin.version,
      description: plugin.description ?? '',
      author: { name: plugin.author ?? '' },
      source: dirname(manifestPath).replace(/\\/g, '/'),
    };
  });

  return { name: marketplaceName, owner: { name: ownerName }, plugins };
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

  const marketplace = buildMarketplace(rootDir, 'arcadien-plugins', 'Aurelien');
  writeFileSync(resolve(rootDir, 'site/public/marketplace.json'), JSON.stringify(marketplace, null, 2));
  console.log(`Registry built: ${registry.plugins.length} plugin(s)`);
}
