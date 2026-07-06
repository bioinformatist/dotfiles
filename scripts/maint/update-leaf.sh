#!/usr/bin/env bash
set -euo pipefail

leaf="${1:?leaf name is required}"
inputs="${2:-}"
hook="${3:-}"

update_release_pin() {
  local repo_slug="$1"
  local tag_prefix="$2"
  local asset="$3"
  local file="$4"
  local version_name="$5"
  local hash_name="$6"

  local tag version digest hash digest_hex
  tag="$(gh api "repos/${repo_slug}/releases/latest" --jq '.tag_name')"
  version="${tag#"$tag_prefix"}"
  digest="$(gh api "repos/${repo_slug}/releases/latest" --jq ".assets[] | select(.name == \"${asset}\") | .digest // empty")"

  if [[ -z "$digest" || "$digest" != sha256:* ]]; then
    echo "Could not find sha256 digest for ${asset} in ${repo_slug} ${tag}" >&2
    exit 1
  fi

  digest_hex="${digest#sha256:}"
  hash="$(nix hash convert --hash-algo sha256 --from base16 --to sri "$digest_hex")"

  sed -i -E "s|${version_name} = \"[^\"]+\";|${version_name} = \"${version}\";|" "$file"
  sed -i -E "s|${hash_name} = \"sha256-[^\"]+\";|${hash_name} = \"${hash}\";|" "$file"
  echo "Updated ${leaf} to ${version}"
}

if [[ -n "$inputs" ]]; then
  read -r -a input_args <<<"$inputs"
  echo "Updating flake inputs for ${leaf}: ${inputs}"
  nix flake update "${input_args[@]}"
fi

case "$hook" in
  "")
    ;;
  codex-release)
    update_release_pin \
      "openai/codex" \
      "rust-v" \
      "codex-x86_64-unknown-linux-musl.tar.gz" \
      "home/programs/codex/default.nix" \
      "codexVersion" \
      "codexHash"
    ;;
  zeroclaw-release)
    update_release_pin \
      "zeroclaw-labs/zeroclaw" \
      "v" \
      "zeroclaw-x86_64-unknown-linux-gnu.tar.gz" \
      "home/programs/zeroclaw/default.nix" \
      "zeroclawVersion" \
      "zeroclawHash"
    ;;
  *)
    echo "Unknown maintenance hook for ${leaf}: ${hook}" >&2
    exit 1
    ;;
esac
