# qnsc-infra-template

Starting skeleton for a **new QNSC product infrastructure repo**. Clone this,
run the init script, and you get the correct `live/{_shared,develop,prod}`
structure, state backend wiring, OIDC roles, and CI — consistent with every
other product.

> This template exists so 10 new projects don't hand-copy structure and drift.

---

## The QNSC platform model (read this first)

"Shared infra" does **not** mean every product runs the same infrastructure. It
means three distinct things:

| Layer | Repo | What it is | Can it differ per product? |
| :---- | :--- | :--------- | :------------------------- |
| **Singletons** | `qnsc-infra` | The one-per-account resources: GitHub OIDC provider, KMS CMK, Tofu state bucket + lock table, artifacts bucket. | **No** — physically one per AWS account. Every product references them. |
| **Building blocks** | `qnsc-tf-modules` | Versioned, reusable Terraform modules (network, rds, ecs-cluster, cdn, …). A **menu**, not a mandate. | **Yes** — pick what fits. An EKS product ignores `ecs-cluster`. A Lambda product uses almost none. |
| **Composition** | *this template* → `<product>-infra` | Each product's `live/` wires the modules it needs with its own values. | **Yes** — this is where products differ. |

So an **ECS product** and an **EKS product** both "use the shared platform":
they share OIDC/KMS/state/conventions, but compose different modules. Different
infra is expected and supported.

### When do I add a new shared module?

**Rule of two.** Build infra **local** to your product first (in `./modules/`).
The moment a **second** product needs the same thing, promote it to
`qnsc-tf-modules` (versioned, tagged) and have both reference it. Used by one
product → keep it local. This avoids premature abstraction *and* copy-paste drift.

- Need EKS and no shared `eks` module exists? Build it locally. When product #2
  needs EKS, promote it.
- Need something only this product will ever use? Keep it local forever. Fine.

---

## Using this template

```bash
# 1. Create the repo from this template (GitHub "Use this template", or clone)
git clone git@github.com:QNSC-VN/qnsc-infra-template.git myproduct-infra
cd myproduct-infra

# 2. Replace the __PRODUCT__ placeholder everywhere
./scripts/init.sh myproduct

# 3. Review and fill in (see init.sh output for the checklist)
```

After init you have:

```
live/
  _shared/   ECR repos + GitHub OIDC deploy roles (api/worker + web). Run once.
  develop/   Develop environment stack (starter: network module wired).
  prod/      Production stack (HA NAT, prod-sized).
.github/workflows/
  plan.yml   tofu plan on PRs (per changed env), posts comment.
  apply.yml  tofu apply on merge: _shared → develop → prod (prod gated).
```

Then **compose the modules this product needs** in `live/develop` and
`live/prod`. See `rally-infra` / `opshub-infra` for full worked examples.

---

## Prerequisites for a new product

1. **`qnsc-infra` bootstrap applied** — the platform singletons must exist first.
2. **GitHub secrets** on the new repo: `AWS_ACCOUNT_ID`,
   `ACM_CERT_ARN_DEVELOP`, `WEB_ACM_CERT_ARN_DEVELOP`, `ACM_CERT_ARN_PROD`,
   `WEB_ACM_CERT_ARN_PROD`.
3. **GitHub Environments** `shared`, `develop`, `production` (add required
   reviewers on `production` for the apply gate).
4. **Infra OIDC role** `<product>-github-infra-apply` — created once (broad
   `AdministratorAccess` initially, then tighten). It can't bootstrap itself
   because the apply pipeline assumes it.

---

## Conventions baked in

- State key: `<product>/<env>/terraform.tfstate` in `qnsc-tofu-state`.
- OIDC-only auth (no static AWS keys) via `qnsc-gitops/actions/setup-tofu-aws@v1`.
- Modules referenced by pinned tag: `?ref=<module>-vX.Y.Z`.
- Apply order `_shared → develop → prod`; prod requires manual approval.

## License

Proprietary and confidential. © QNSC — Quy Nhon Semiconductor. See [`LICENSE`](./LICENSE).
