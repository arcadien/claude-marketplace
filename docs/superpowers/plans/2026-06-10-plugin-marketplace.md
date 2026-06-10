# Plugin Marketplace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal Claude Code plugin marketplace — monorepo with plugins, a JSON registry generator, and an Astro static site deployed to GitHub Pages at `arcadien.github.io/marketplace`.

**Architecture:** Plugins live in `plugins/<name>/plugin.json`. A TypeScript script (`build-registry.ts`) aggregates them into `registry.json`. An Astro site reads that data at build time to generate a plugin listing and detail pages. GitHub Actions orchestrates build + deploy on every push to `main`.

**Tech Stack:** Node.js 20, TypeScript, tsx, glob v11, vitest, Astro 4, GitHub Actions, GitHub Pages

---

## File Map

| File | Rôle |
|------|------|
| `package.json` | Scripts racine : `build:registry`, `test`, `build` |
| `tsconfig.json` | TypeScript config pour `scripts/` |
| `vitest.config.ts` | Config du test runner |
| `.gitignore` | Exclut node_modules, dist, registry générés |
| `scripts/build-registry.ts` | Lit `plugins/*/plugin.json` → écrit `site/src/data/registry.json` et `site/public/registry.json` |
| `scripts/build-registry.test.ts` | Tests unitaires de `buildRegistry()` |
| `plugins/example-plugin/plugin.json` | Plugin d'exemple |
| `site/package.json` | Dépendances Astro |
| `site/tsconfig.json` | TypeScript config Astro |
| `site/astro.config.mjs` | Config Astro : site, base path |
| `site/src/data/.gitkeep` | Garantit que le répertoire existe dans git |
| `site/src/layouts/Layout.astro` | Shell HTML de base |
| `site/src/components/PluginCard.astro` | Carte d'un plugin dans la liste |
| `site/src/pages/index.astro` | Page liste des plugins |
| `site/src/pages/plugins/[name].astro` | Page détail d'un plugin |
| `.github/workflows/build.yml` | CI : génère registry → build Astro → deploy GitHub Pages |

---

### Task 1 : Bootstrap du projet

**Files:**
- Create: `package.json`
- Create: `tsconfig.json`
- Create: `vitest.config.ts`
- Create: `.gitignore`

- [ ] **Step 1 : Créer `package.json`**

```json
{
  "name": "claude-plugin-marketplace",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build:registry": "tsx scripts/build-registry.ts",
    "build": "npm run build:registry && cd site && npm run build",
    "test": "vitest run"
  },
  "devDependencies": {
    "glob": "^11.0.0",
    "tsx": "^4.19.0",
    "typescript": "^5.6.0",
    "vitest": "^2.1.0"
  }
}
```

- [ ] **Step 2 : Créer `tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "node",
    "strict": true,
    "esModuleInterop": true
  },
  "include": ["scripts/**/*", "vitest.config.ts"]
}
```

- [ ] **Step 3 : Créer `vitest.config.ts`**

```typescript
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
  },
});
```

- [ ] **Step 4 : Créer `.gitignore`**

```
node_modules/
site/node_modules/
site/dist/
site/.astro/
site/src/data/registry.json
site/public/registry.json
```

- [ ] **Step 5 : Installer les dépendances**

```bash
npm install
```

Expected : `node_modules/` créé, `package-lock.json` généré.

- [ ] **Step 6 : Commit**

```bash
git init
git add package.json tsconfig.json vitest.config.ts .gitignore
git commit -m "chore: bootstrap project"
```

---

### Task 2 : Tests pour build-registry.ts (TDD red)

**Files:**
- Create: `scripts/build-registry.test.ts`

- [ ] **Step 1 : Créer `scripts/build-registry.test.ts`**

```typescript
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { buildRegistry } from './build-registry';
import { mkdirSync, writeFileSync, rmSync } from 'fs';
import { resolve } from 'path';
import { tmpdir } from 'os';

describe('buildRegistry', () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = resolve(tmpdir(), `marketplace-test-${Date.now()}`);
    mkdirSync(resolve(tmpDir, 'plugins/my-plugin'), { recursive: true });
    writeFileSync(
      resolve(tmpDir, 'plugins/my-plugin/plugin.json'),
      JSON.stringify({
        name: 'my-plugin',
        version: '1.2.0',
        description: 'A test plugin',
        author: 'Tester',
      })
    );
  });

  afterEach(() => {
    rmSync(tmpDir, { recursive: true, force: true });
  });

  it('finds one plugin', () => {
    const registry = buildRegistry(tmpDir);
    expect(registry.plugins).toHaveLength(1);
  });

  it('maps plugin fields correctly', () => {
    const { plugins } = buildRegistry(tmpDir);
    expect(plugins[0].name).toBe('my-plugin');
    expect(plugins[0].version).toBe('1.2.0');
    expect(plugins[0].description).toBe('A test plugin');
    expect(plugins[0].author).toBe('Tester');
    expect(plugins[0].installPath).toBe('plugins/my-plugin');
  });

  it('sets registry version to 1', () => {
    expect(buildRegistry(tmpDir).version).toBe(1);
  });

  it('returns empty plugins when directory is empty', () => {
    rmSync(resolve(tmpDir, 'plugins'), { recursive: true });
    mkdirSync(resolve(tmpDir, 'plugins'), { recursive: true });
    expect(buildRegistry(tmpDir).plugins).toHaveLength(0);
  });

  it('handles multiple plugins', () => {
    mkdirSync(resolve(tmpDir, 'plugins/second-plugin'), { recursive: true });
    writeFileSync(
      resolve(tmpDir, 'plugins/second-plugin/plugin.json'),
      JSON.stringify({ name: 'second-plugin', version: '0.1.0', description: '', author: '' })
    );
    expect(buildRegistry(tmpDir).plugins).toHaveLength(2);
  });
});
```

- [ ] **Step 2 : Vérifier que les tests échouent**

```bash
npm test
```

Expected : FAIL — `Cannot find module './build-registry'`

- [ ] **Step 3 : Commit**

```bash
git add scripts/build-registry.test.ts
git commit -m "test: add build-registry tests (red)"
```

---

### Task 3 : Implémenter build-registry.ts (TDD green)

**Files:**
- Create: `scripts/build-registry.ts`

- [ ] **Step 1 : Créer `scripts/build-registry.ts`**

```typescript
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
```

- [ ] **Step 2 : Lancer les tests**

```bash
npm test
```

Expected : 5 tests PASS

- [ ] **Step 3 : Commit**

```bash
git add scripts/build-registry.ts
git commit -m "feat: implement build-registry script"
```

---

### Task 4 : Plugin exemple

**Files:**
- Create: `plugins/example-plugin/plugin.json`

- [ ] **Step 1 : Créer `plugins/example-plugin/plugin.json`**

```json
{
  "name": "example-plugin",
  "version": "1.0.0",
  "description": "Un plugin d'exemple pour le marketplace",
  "author": "Aurelien",
  "skills": [],
  "hooks": [],
  "commands": []
}
```

- [ ] **Step 2 : Vérifier la génération du registry**

```bash
npm run build:registry
```

Expected output :
```
Registry built: 1 plugin(s)
```

```bash
cat site/src/data/registry.json
```

Expected : JSON avec `plugins` contenant `example-plugin`.

- [ ] **Step 3 : Commit**

```bash
git add plugins/example-plugin/plugin.json
git commit -m "feat: add example plugin"
```

---

### Task 5 : Initialiser Astro

**Files:**
- Create: `site/package.json`
- Create: `site/tsconfig.json`
- Create: `site/astro.config.mjs`
- Create: `site/src/data/.gitkeep`

- [ ] **Step 1 : Créer `site/package.json`**

```json
{
  "name": "marketplace-site",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "astro dev",
    "build": "astro build",
    "preview": "astro preview"
  },
  "dependencies": {
    "astro": "^4.16.0"
  }
}
```

- [ ] **Step 2 : Créer `site/tsconfig.json`**

```json
{
  "extends": "astro/tsconfigs/strict"
}
```

- [ ] **Step 3 : Créer `site/astro.config.mjs`**

```js
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://arcadien.github.io',
  base: '/marketplace',
  output: 'static',
});
```

> Si le repo GitHub ne s'appelle pas `marketplace`, ajuster `base` en conséquence.

- [ ] **Step 4 : Créer `site/src/data/.gitkeep`**

```bash
mkdir -p site/src/data && touch site/src/data/.gitkeep
```

- [ ] **Step 5 : Installer les dépendances Astro**

```bash
cd site && npm install
```

Expected : `site/node_modules/` créé.

- [ ] **Step 6 : Commit**

```bash
git add site/
git commit -m "chore: init Astro site"
```

---

### Task 6 : Layout et composant PluginCard

**Files:**
- Create: `site/src/layouts/Layout.astro`
- Create: `site/src/components/PluginCard.astro`

- [ ] **Step 1 : Créer `site/src/layouts/Layout.astro`**

```astro
---
interface Props {
  title: string;
}
const { title } = Astro.props;
const base = import.meta.env.BASE_URL;
---
<!doctype html>
<html lang="fr">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{title} — Claude Plugin Marketplace</title>
    <style>
      *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
      body { font-family: system-ui, sans-serif; max-width: 800px; margin: 2rem auto; padding: 0 1rem; color: #1a1a1a; line-height: 1.6; }
      a { color: #5b21b6; text-decoration: none; }
      a:hover { text-decoration: underline; }
      header { margin-bottom: 2rem; border-bottom: 1px solid #e5e7eb; padding-bottom: 1rem; }
      h1 { font-size: 1.5rem; margin-bottom: 1rem; }
    </style>
  </head>
  <body>
    <header>
      <a href={base}>Claude Plugin Marketplace</a>
    </header>
    <main>
      <slot />
    </main>
  </body>
</html>
```

- [ ] **Step 2 : Créer `site/src/components/PluginCard.astro`**

```astro
---
interface Props {
  name: string;
  version: string;
  description: string;
}
const { name, version, description } = Astro.props;
const base = import.meta.env.BASE_URL;
---
<article style="border: 1px solid #e5e7eb; border-radius: 8px; padding: 1rem; margin-bottom: 1rem;">
  <h2 style="font-size: 1.1rem;">
    <a href={`${base}plugins/${name}`}>{name}</a>
    <span style="font-size: 0.85rem; color: #6b7280; font-weight: normal; margin-left: 0.5rem;">v{version}</span>
  </h2>
  <p style="color: #4b5563; margin-top: 0.25rem;">{description}</p>
</article>
```

- [ ] **Step 3 : Commit**

```bash
git add site/src/layouts/ site/src/components/
git commit -m "feat: add Layout and PluginCard components"
```

---

### Task 7 : Page d'accueil (`/`)

**Files:**
- Create: `site/src/pages/index.astro`

Prérequis : `site/src/data/registry.json` doit exister — lancer `npm run build:registry` si nécessaire.

- [ ] **Step 1 : Créer `site/src/pages/index.astro`**

```astro
---
import Layout from '../layouts/Layout.astro';
import PluginCard from '../components/PluginCard.astro';
import registry from '../data/registry.json';
---
<Layout title="Plugins">
  <h1>Plugins disponibles ({registry.plugins.length})</h1>
  {registry.plugins.length === 0 && <p>Aucun plugin pour l'instant.</p>}
  {registry.plugins.map((plugin) => (
    <PluginCard
      name={plugin.name}
      version={plugin.version}
      description={plugin.description}
    />
  ))}
</Layout>
```

- [ ] **Step 2 : Vérifier le build**

```bash
npm run build:registry && cd site && npm run build
```

Expected : `site/dist/` généré sans erreur.

- [ ] **Step 3 : Tester en local**

```bash
cd site && npm run preview
```

Ouvrir `http://localhost:4321/marketplace/` — la liste doit afficher `example-plugin`.

- [ ] **Step 4 : Commit**

```bash
git add site/src/pages/index.astro
git commit -m "feat: add plugin listing page"
```

---

### Task 8 : Page détail (`/plugins/[name]`)

**Files:**
- Create: `site/src/pages/plugins/[name].astro`

- [ ] **Step 1 : Créer `site/src/pages/plugins/[name].astro`**

```astro
---
import Layout from '../../layouts/Layout.astro';
import registry from '../../data/registry.json';
import type { GetStaticPaths } from 'astro';

export const getStaticPaths: GetStaticPaths = () => {
  return registry.plugins.map((plugin) => ({
    params: { name: plugin.name },
    props: { plugin },
  }));
};

interface Props {
  plugin: (typeof registry.plugins)[number];
}
const { plugin } = Astro.props;
---
<Layout title={plugin.name}>
  <h1>
    {plugin.name}
    <small style="font-size: 0.75em; color: #6b7280;"> v{plugin.version}</small>
  </h1>
  <p style="color: #4b5563; margin: 0.5rem 0 1.5rem;">{plugin.description}</p>
  <p style="margin-bottom: 1.5rem;">Auteur : <strong>{plugin.author}</strong></p>

  <h2 style="font-size: 1.1rem; margin-bottom: 0.5rem;">Installation</h2>
  <pre style="background: #f3f4f6; padding: 1rem; border-radius: 6px; overflow-x: auto;"><code>claude plugin install https://arcadien.github.io/marketplace/registry.json {plugin.name}</code></pre>
</Layout>
```

- [ ] **Step 2 : Vérifier le build complet**

```bash
npm run build:registry && cd site && npm run build
```

Expected : `site/dist/plugins/example-plugin/index.html` doit exister.

```bash
ls site/dist/plugins/
```

- [ ] **Step 3 : Commit**

```bash
git add site/src/pages/plugins/
git commit -m "feat: add plugin detail page"
```

---

### Task 9 : GitHub Actions — Build & Deploy

**Files:**
- Create: `.github/workflows/build.yml`

- [ ] **Step 1 : Créer le répertoire**

```bash
mkdir -p .github/workflows
```

- [ ] **Step 2 : Créer `.github/workflows/build.yml`**

```yaml
name: Build & Deploy

on:
  push:
    branches: [main]

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - name: Install root dependencies
        run: npm ci

      - name: Generate registry
        run: npm run build:registry

      - name: Install Astro dependencies
        run: cd site && npm ci

      - name: Build Astro site
        run: cd site && npm run build

      - uses: actions/upload-pages-artifact@v3
        with:
          path: site/dist

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Step 3 : Activer GitHub Pages dans les settings du repo**

GitHub → Settings → Pages → Source → **GitHub Actions**

- [ ] **Step 4 : Commit et push**

```bash
git add .github/
git commit -m "ci: add GitHub Actions build and deploy workflow"
git push origin main
```

- [ ] **Step 5 : Vérifier le déploiement**

GitHub → Actions → vérifier que `Build & Deploy` passe au vert.

URL finale : `https://arcadien.github.io/marketplace/`  
Registry machine-readable : `https://arcadien.github.io/marketplace/registry.json`
