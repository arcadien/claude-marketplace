import { globSync } from 'glob';
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

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

export interface GitSubdirSource {
  source: 'git-subdir';
  url: string;
  path: string;
  ref: string;
  sha: string;
}

export interface MarketplacePlugin {
  name: string;
  version: string;
  description: string;
  author: { name: string };
  source: string | GitSubdirSource;
}

export interface Marketplace {
  name: string;
  description: string;
  owner: { name: string };
  plugins: MarketplacePlugin[];
}

function readAuthorName(author: unknown): string {
  if (typeof author === 'string') return author;
  if (author && typeof author === 'object' && 'name' in author) return (author as { name: string }).name;
  return '';
}

export function buildMarketplace(
  rootDir: string,
  marketplaceName: string,
  ownerName: string,
  repoUrl?: string,
): Marketplace {
  const manifests = globSync('plugins/*/plugin.json', { cwd: rootDir });

  let sha = '';
  let ref = 'main';
  if (repoUrl) {
    try {
      sha = execSync('git rev-parse HEAD', { cwd: rootDir }).toString().trim();
      ref = execSync('git rev-parse --abbrev-ref HEAD', { cwd: rootDir }).toString().trim();
      // Always pin to main for the published source (HEAD may be a feature branch)
      if (ref !== 'main' && ref !== 'master') ref = 'main';
    } catch {
      // fall through — sha stays empty, will use string source
    }
  }

  const plugins: MarketplacePlugin[] = manifests.map((manifestPath) => {
    const raw = readFileSync(resolve(rootDir, manifestPath), 'utf-8');
    const plugin = JSON.parse(raw) as Record<string, unknown>;
    const pluginPath = dirname(manifestPath).replace(/\\/g, '/');

    const source: string | GitSubdirSource = repoUrl && sha
      ? { source: 'git-subdir', url: repoUrl, path: pluginPath, ref, sha }
      : './' + pluginPath;

    return {
      name: plugin.name as string,
      version: plugin.version as string,
      description: (plugin.description as string) ?? '',
      author: { name: readAuthorName(plugin.author) },
      source,
    };
  });

  return {
    name: marketplaceName,
    description: `Personal Claude Code plugin marketplace by ${ownerName}`,
    owner: { name: ownerName },
    plugins,
  };
}

export function buildRegistry(rootDir: string): Registry {
  const manifests = globSync('plugins/*/plugin.json', { cwd: rootDir });

  const plugins: PluginEntry[] = manifests.map((manifestPath) => {
    const raw = readFileSync(resolve(rootDir, manifestPath), 'utf-8');
    const plugin = JSON.parse(raw) as Record<string, unknown>;
    return {
      name: plugin.name as string,
      version: plugin.version as string,
      description: (plugin.description as string) ?? '',
      author: readAuthorName(plugin.author),
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

  const repoUrl = 'https://github.com/arcadien/claude-marketplace.git';
  const marketplace = buildMarketplace(rootDir, 'arcadien-plugins', 'Aurelien', repoUrl);
  const marketplaceJson = JSON.stringify(marketplace, null, 2);
  writeFileSync(resolve(rootDir, 'marketplace.json'), marketplaceJson);
  writeFileSync(resolve(rootDir, 'site/public/marketplace.json'), marketplaceJson);
  mkdirSync(resolve(rootDir, '.claude-plugin'), { recursive: true });
  writeFileSync(resolve(rootDir, '.claude-plugin/marketplace.json'), marketplaceJson);
  console.log(`Registry built: ${registry.plugins.length} plugin(s)`);
}
