#!/usr/bin/env bash
# Verifies (and where possible installs) the tools needed to work on
# this project. Supports macOS with Homebrew and Debian or Ubuntu
# based Linux, including WSL2. Windows users: run this inside WSL2.
set -euo pipefail

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  [ok] %s\n' "$*"; }
miss() { printf '  [missing] %s\n' "$*"; }

install_hint() {
  case "$(uname -s)" in
    Darwin) echo "brew install $1" ;;
    Linux)  echo "sudo apt-get install -y $1" ;;
    *)      echo "install $1 manually" ;;
  esac
}

required=(go docker protoc)
optional=(k6 jq golangci-lint)

bold "Required tools"
missing_required=0
for tool in "${required[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool $(command -v "$tool")"
  else
    miss "$tool  -> $(install_hint "$tool")"
    missing_required=1
  fi
done

bold "Optional tools"
for tool in "${optional[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool"
  else
    miss "$tool  -> $(install_hint "$tool")"
  fi
done

bold "Go version"
go_version="$(go version 2>/dev/null | awk '{print $3}' || true)"
echo "  detected: ${go_version:-none} (need go1.24 or newer)"

bold "Docker daemon"
if docker info >/dev/null 2>&1; then
  ok "docker daemon is running"
else
  miss "docker daemon is not running, start Docker Desktop or the docker service"
  missing_required=1
fi

bold "Go protoc plugins"
for plugin in protoc-gen-go protoc-gen-go-grpc; do
  if command -v "$plugin" >/dev/null 2>&1 || [ -x "$(go env GOPATH)/bin/$plugin" ]; then
    ok "$plugin"
  else
    echo "  installing $plugin"
    case "$plugin" in
      protoc-gen-go)      go install google.golang.org/protobuf/cmd/protoc-gen-go@latest ;;
      protoc-gen-go-grpc) go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest ;;
    esac
    ok "$plugin installed to $(go env GOPATH)/bin"
  fi
done

if [ "$missing_required" -eq 1 ]; then
  bold "Some required tools are missing. Install them and run make setup again."
  exit 1
fi

bold "All required tools present. Run: make up"
