#!/usr/bin/env bash
set -euo pipefail

leaf="${1:?leaf name is required}"

replace_nix_string() {
  local file="$1"
  local name="$2"
  local value="$3"
  local pattern="${name} = \"[^\"]+\";"
  local replacement="${name} = \"${value}\";"

  if ! grep -Eq "$pattern" "$file"; then
    echo "Could not find ${name} assignment in ${file}" >&2
    exit 1
  fi

  sed -i -E "s|${pattern}|${replacement}|" "$file"

  if ! grep -Fqx "  ${replacement}" "$file" && ! grep -Fqx "${replacement}" "$file"; then
    echo "Failed to update ${name} in ${file}" >&2
    exit 1
  fi
}

update_release_pin() {
  local repo_slug="$1"
  local tag_prefix="$2"
  local asset="$3"
  local file="$4"
  local version_name="$5"
  local hash_name="$6"
  local extra_asset="${7:-}"
  local extra_hash_name="${8:-}"

  local tag version digest hash digest_hex extra_digest extra_hash extra_digest_hex
  tag="$(gh api "repos/${repo_slug}/releases/latest" --jq '.tag_name')"
  version="${tag#"$tag_prefix"}"
  digest="$(gh api "repos/${repo_slug}/releases/latest" --jq ".assets[] | select(.name == \"${asset}\") | .digest // empty")"

  if [[ -z "$digest" || "$digest" != sha256:* ]]; then
    echo "Could not find sha256 digest for ${asset} in ${repo_slug} ${tag}" >&2
    exit 1
  fi

  digest_hex="${digest#sha256:}"
  hash="$(nix hash convert --hash-algo sha256 --from base16 --to sri "$digest_hex")"

  if [[ -n "$extra_asset" && -n "$extra_hash_name" ]]; then
    extra_digest="$(gh api "repos/${repo_slug}/releases/latest" --jq ".assets[] | select(.name == \"${extra_asset}\") | .digest // empty")"
    if [[ -z "$extra_digest" || "$extra_digest" != sha256:* ]]; then
      echo "Could not find sha256 digest for ${extra_asset} in ${repo_slug} ${tag}" >&2
      exit 1
    fi

    extra_digest_hex="${extra_digest#sha256:}"
    extra_hash="$(nix hash convert --hash-algo sha256 --from base16 --to sri "$extra_digest_hex")"
  fi

  replace_nix_string "$file" "$version_name" "$version"
  replace_nix_string "$file" "$hash_name" "$hash"
  if [[ -n "$extra_asset" && -n "$extra_hash_name" ]]; then
    replace_nix_string "$file" "$extra_hash_name" "$extra_hash"
  fi

  echo "Updated ${leaf} to ${version}"
}

case "$leaf" in
  orca)
    update_release_pin \
      "stablyai/orca" \
      "v" \
      "orca-linux.AppImage" \
      "pkgs/orca-ide.nix" \
      "orcaVersion" \
      "orcaHash"
    ;;
  zeroclaw)
    update_release_pin \
      "zeroclaw-labs/zeroclaw" \
      "v" \
      "zeroclaw-x86_64-unknown-linux-gnu.tar.gz" \
      "home/programs/zeroclaw/default.nix" \
      "zeroclawVersion" \
      "zeroclawHash"
    ;;
  *)
    echo "Unknown release-pin leaf: ${leaf}" >&2
    exit 1
    ;;
esac
