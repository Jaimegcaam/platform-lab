# AI agent instructions

Platform Engineering homelab: **WSL2 + k3d (single node) + Argo CD + GitOps**. Technical portfolio — documentation must always reflect the actual project state.

## Main rule

Every functional change must include a **`README.md` update** in the same session, unless the user says otherwise.

| Change | Review in README |
|--------|------------------|
| Addon / app in `gitops/` | Layout, architecture, roadmap |
| Bootstrap / k3d | Quick start, ports, resources |
| Roadmap item completed | Checklist |

## Context

```
bootstrap/                    → k3d cluster + Argo CD (Helm)
gitops/
  clusters/platform-lab/      → App of Apps (root, infra, addons, apps)
  infrastructure/             → Namespaces, quotas, policies
  addons/                     → application.yaml + values + manifests per addon
  apps/                       → Workloads
```

| Parameter | Value |
|-----------|-------|
| Cluster | `platform-lab` — 1 server, 0 agents |
| Ingress | NGINX on host `:8080` |
| UIs | `argocd.local`, `grafana.local` (hosts file) |
| Repo | `https://github.com/Jaimegcaam/platform-lab.git` |

## Conventions

- Keep changes minimal and focused.
- No commit/push unless explicitly requested.
- Do not add extra docs; **`README.md` is the public source of truth**.
- **Lightweight homelab:** prioritize low resource requests in values and bootstrap.
- **Language:** all user-facing documentation in **English**.
