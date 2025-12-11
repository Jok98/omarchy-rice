#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$(cd "${script_dir}/.." && pwd)/.config"
dest="$HOME/.config"

if [ ! -d "$src" ]; then
  echo "Source config dir not found: ${src}" >&2
  exit 1
fi

mkdir -p "$dest"
cp -a "$src"/. "$dest"/
