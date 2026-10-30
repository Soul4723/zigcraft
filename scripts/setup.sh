#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Pinned tools for the supported Linux x86_64 development environment.
if [[ $(uname -s) != Linux || $(uname -m) != x86_64 ]]; then
    echo 'Install Zig 0.16.0 and Gitleaks 8.30.1 for this platform, then configure core.hooksPath=.githooks.' >&2
    exit 1
fi
mkdir -p .local/bin
setup_tmp=$(mktemp -d)
trap 'rm -rf "$setup_tmp"' EXIT
if [[ ! -x .local/zig-x86_64-linux-0.16.0/zig ]]; then
    curl --fail --silent --show-error --location \
        https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz \
        --output "$setup_tmp/zig.tar.xz"
    echo "70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00  $setup_tmp/zig.tar.xz" | sha256sum --check
    tar -xJf "$setup_tmp/zig.tar.xz" -C .local
fi
ln -sfn ../zig-x86_64-linux-0.16.0/zig .local/bin/zig
curl --fail --silent --show-error --location \
    https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz \
    --output "$setup_tmp/gitleaks.tar.gz"
echo "551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb  $setup_tmp/gitleaks.tar.gz" | sha256sum --check
tar -xzf "$setup_tmp/gitleaks.tar.gz" -C .local/bin gitleaks
git config --local core.hooksPath .githooks

# Anonymous project identity avoids inheriting a machine's personal Git identity.
git config --local user.name 'Zigcraft contributors'
git config --local user.email 'zigcraft@users.noreply.github.com'
echo 'Pinned Zig, secret scanner, Git hooks and public commit identity configured.'
echo 'For interactive commands: export PATH="$PWD/.local/bin:$PATH"'
