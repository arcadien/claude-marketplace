# Plugin Marketplace — Design Spec

**Date:** 2026-06-10  
**Status:** Approved

## Vue d'ensemble

Un marketplace personnel de plugins Claude Code : monorepo contenant les plugins, un registry JSON généré automatiquement, et un site Astro statique déployé sur GitHub Pages.

## Architecture

```
marketplace/
├── plugins/
│   └── <nom-plugin>/
│       ├── plugin.json       ← format standard Claude Code
│       └── skills/, hooks/,  ← assets du plugin
├── scripts/
│   └── build-registry.ts     ← agrège plugins/*/plugin.json → registry.json
├── registry.json             ← artefact de build (non commité, généré par CI)
├── site/                     ← application Astro
│   ├── src/
│   │   ├── pages/
│   │   │   ├── index.astro         ← liste des plugins
│   │   │   └── plugins/[name].astro ← page détail
│   │   └── layouts/
│   └── astro.config.mjs
└── .github/
    └── workflows/
        └── build.yml         ← build + deploy sur GitHub Pages
```

## Format des données

### plugin.json (par plugin)

Format standard Claude Code, au minimum :

```json
{
  "name": "nom-du-plugin",
  "version": "1.0.0",
  "description": "Ce que fait le plugin",
  "author": "Aurelien",
  "skills": [],
  "hooks": [],
  "commands": []
}
```

### registry.json (généré)

```json
{
  "version": 1,
  "generatedAt": "2026-06-10T00:00:00Z",
  "plugins": [
    {
      "name": "nom-du-plugin",
      "version": "1.0.0",
      "description": "...",
      "author": "Aurelien",
      "installPath": "plugins/nom-du-plugin"
    }
  ]
}
```

## Site Astro

### Pages

- **`/`** — liste de tous les plugins : nom, description, version, lien vers la page détail
- **`/plugins/[name]`** — page détail : description complète, skills/hooks/commandes listés, instructions d'installation

### Style

Minimaliste, pas de framework CSS externe. Astro natif.

### Instructions d'installation (affichées sur chaque page détail)

```bash
claude plugin install https://arcadien.github.io/marketplace/registry.json <nom-du-plugin>
```

URL du registry public : `https://arcadien.github.io/marketplace/registry.json`

> Note : la syntaxe exacte de la CLI Claude Code sera à confirmer lors de l'implémentation.

## Script build-registry.ts

1. Glob sur `plugins/*/plugin.json`
2. Parse chaque fichier
3. Génère `registry.json` à la racine
4. Écrit la date de génération

Exécuté via `npm run build:registry` (ou `ts-node` / `tsx`).

## CI/CD

### `.github/workflows/build.yml`

Déclenché sur push sur `main` :

1. `npm run build:registry` — génère `registry.json`
2. `npm run build` (Astro) — génère le site statique
3. Deploy sur GitHub Pages via `actions/deploy-pages`

Pas de cron nécessaire : tout changement passe par un commit.

## Workflow d'ajout d'un plugin

1. Créer `plugins/<nom>/plugin.json` + assets
2. Commit + push sur `main`
3. GitHub Action regénère `registry.json` + rebuild le site automatiquement

## Ce qui est hors scope

- Authentification
- Système de notation/commentaires
- Scraping de repos externes
- Multi-auteur
