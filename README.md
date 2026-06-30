# Claude Plugin Marketplace

Personal collection of Claude Code plugins by Aurelien Labrosse, with a self-hosted registry and Astro site deployed to GitHub Pages.

```bash
# Add this marketplace to Claude Code
/plugin marketplace add https://arcadien.github.io/claude-marketplace/marketplace.json
```

---

## Plugins

### rbd — Requirement-Based Development

Guided workflow that enforces traceability between requirements, tests, and code. Every committed behavior originates from a validated, written requirement. Supports a full TDD cycle (red → green), architecture tracking, pre-push audit, and MR review — all from a single `/rbd` skill.

**Skills:** `/rbd` · `/rbd-audit` · `/rbd-review` · `/rbd-arch-analyze` · `/rbd-metrics`

| | |
|---|---|
| Version | `0.13.1` |
| Documentation | [plugins/rbd/README.md](plugins/rbd/README.md) |
| Architecture | [plugins/rbd/docs/architecture.md](plugins/rbd/docs/architecture.md) |
| Changelog | [plugins/rbd/CHANGELOG.md](plugins/rbd/CHANGELOG.md) |

```bash
/plugin install rbd@arcadien-plugins
```

---

### magi-8 — MAGI Deliberation System

Three-voice deliberation system for technical and strategic decisions. Submit a question; Melchior (technician), Balthazar (pragmatist), and Casper (sage) each argue their position and cast a vote. Returns a verdict with full argumentation.

**Skills:** `/magi`

| | |
|---|---|
| Version | `2.0.0` |
| Documentation | [plugins/magi/README.md](plugins/magi/README.md) |

```bash
/plugin install magi-8@arcadien-plugins
```

---

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for the plugin development workflow, versioning rules, and release process.
