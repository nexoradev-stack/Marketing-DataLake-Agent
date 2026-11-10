#!/usr/bin/env bash
# Marketing DataLake Agent — fails if the repository contains a key, a secret, a real project ID
# or a real email address. Runs in CI on every push and pull request.
#   Run locally: bash scripts/check-secrets.sh
set -uo pipefail

# Files to skip: binary images and lock files
mapfile -t FILES < <(git ls-files | grep -v -E '\.(png|jpe?g|gif|ico|webp)$|package-lock\.json$')

fail=0
report() { echo "  $1"; fail=1; }

# 1) Keys, tokens and private keys
SECRET_RE='rnd_[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|sk-(ant-)?[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[baprs]-[A-Za-z0-9-]{10,}|"private_key_id"'
hits=$(grep -n -I -E "$SECRET_RE" -- "${FILES[@]}" 2>/dev/null | grep -v '^scripts/check-secrets.sh:')
[ -n "$hits" ] && { echo "Possible keys or tokens:"; while IFS= read -r l; do report "${l%%:*}:$(echo "$l" | cut -d: -f2)"; done <<< "$hits"; }

# 2) Real deployment details (project numbers, live URLs, secrets with real values)
DEPLOY_RE='[0-9]{10,13}-compute@developer\.gserviceaccount\.com|script\.google\.com/macros/s/[A-Za-z0-9_-]{20,}|https://[a-z0-9-]+-[a-z0-9]{8,}-[a-z]{2}\.a\.run\.app|SHARED_SECRET *= *'"'"'[0-9a-f]{16,}'"'"
hits=$(grep -n -I -E "$DEPLOY_RE" -- "${FILES[@]}" 2>/dev/null | grep -v '^scripts/check-secrets.sh:')
[ -n "$hits" ] && { echo "Possible real deployment details:"; while IFS= read -r l; do report "${l%%:*}:$(echo "$l" | cut -d: -f2)"; done <<< "$hits"; }

# 3) Email addresses: only made-up ones are allowed
#    Allowed: @example.com/.org/.net, *.example domains, Google service-account placeholders
EMAIL_RE='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
ALLOWED_RE='@(example\.(com|org|net)|[A-Za-z0-9.-]+\.example)$|@developer\.gserviceaccount\.com$|@users\.noreply\.github\.com$|@anthropic\.com$'
while IFS= read -r line; do
  file=${line%%:*}; rest=${line#*:}; num=${rest%%:*}; email=${rest#*:}
  [ "$file" = "scripts/check-secrets.sh" ] && continue
  if ! [[ "$email" =~ $ALLOWED_RE ]]; then report "$file:$num  real-looking email address (use a made-up one, e.g. someone@example.com)"; fi
done < <(grep -n -o -I -E "$EMAIL_RE" -- "${FILES[@]}" 2>/dev/null)

if [ "$fail" -ne 0 ]; then
  echo "❌ Secrets check failed. Replace the values above with placeholders or made-up examples."
  exit 1
fi
echo "✅ No keys, secrets, real project details or real email addresses found in ${#FILES[@]} files."
