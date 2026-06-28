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

# Replace placeholder in every tracked text file (skip .git and this script).
grep -rl '__PRODUCT__' "$ROOT" \
  --exclude-dir=.git \
  --exclude="init.sh" \
  | while read -r f; do
      sed -i.bak "s/__PRODUCT__/${PRODUCT}/g" "$f" && rm -f "$f.bak"
      echo "  updated $f"
    done

echo
echo "✓ Initialized infra for product '${PRODUCT}'."
echo
echo "Next steps:"
echo "  1. Review live/_shared/main.tf — adjust ECR repo names, drop web-deploy block if no SPA."
echo "  2. Fill in live/develop and live/prod with the modules this product needs."
echo "  3. Set GitHub secrets: AWS_ACCOUNT_ID, ACM_CERT_ARN_DEVELOP, ACM_CERT_ARN_PROD, etc."
echo "  4. Create the '${PRODUCT}-github-infra-apply' IAM role (see README)."
echo "  5. Delete this script and scripts/ once done."
