#!/usr/bin/env bash
# Initialize a new product infra repo from this template.
# Replaces the __PRODUCT__ placeholder with the real product name everywhere.
#
# Usage:  ./scripts/init.sh <product-name>
#   e.g.  ./scripts/init.sh fleet
set -euo pipefail

PRODUCT="${1:-}"
if [[ -z "$PRODUCT" ]]; then
  echo "Usage: $0 <product-name>   (lowercase, e.g. 'fleet')" >&2
  exit 1
fi
if [[ ! "$PRODUCT" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "Product name must be lowercase letters/digits/hyphens, starting with a letter." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── Reserve a VPC /16 (second octet) ─────────────────────────────────────────
# The registry lives in the qnsc-infra repo (allocations.json). Pass the octet
# explicitly: NET=<n> ./scripts/init.sh <product>. Without it we stop rather
# than guess a colliding CIDR.
NET="${NET:-}"
if [[ -z "$NET" ]]; then
  echo "!! No VPC octet reserved. Pick the lowest free 'net' in 10-89 from" >&2
  echo "   qnsc-infra/allocations.json, add <product>-develop + <product>-prod" >&2
  echo "   entries there, then re-run:  NET=<n> $0 ${PRODUCT}" >&2
  exit 1
fi
if [[ ! "$NET" =~ ^[0-9]+$ ]] || (( NET < 10 || NET > 89 )); then
  echo "NET must be an integer in 10-89 (see allocations.json reserved_bands)." >&2
  exit 1
fi

# Replace placeholders in every tracked text file (skip .git and this script).
grep -rlE '__PRODUCT__|__NET__' "$ROOT" \
  --exclude-dir=.git \
  --exclude="init.sh" \
  | while read -r f; do
      sed -i.bak -e "s/__PRODUCT__/${PRODUCT}/g" -e "s/__NET__/${NET}/g" "$f" && rm -f "$f.bak"
      echo "  updated $f"
    done

echo
echo "✓ Initialized infra for product '${PRODUCT}' (VPC 10.${NET}.0.0/16)."
echo
echo "Next steps:"
echo "  1. Review live/_shared/main.tf — adjust ECR repo names, drop web-deploy block if no SPA."
echo "  2. Fill in live/develop and live/prod with the modules this product needs."
echo "  3. Set GitHub secrets: AWS_ACCOUNT_ID, ACM_CERT_ARN_DEVELOP, ACM_CERT_ARN_PROD, etc."
echo "  4. Create the '${PRODUCT}-github-infra-apply' IAM role (see README)."
echo "  5. Delete this script and scripts/ once done."
