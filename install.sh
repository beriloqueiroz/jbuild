#!/usr/bin/env bash
# Instala o jbuild: binários, completion do zsh e o esqueleto do ~/.jbuildrc.
set -euo pipefail
cd "$(dirname "$0")"

if [[ -w /usr/local/bin ]]; then
  BIN_DIR=/usr/local/bin
else
  BIN_DIR="$HOME/.local/bin"
  mkdir -p "$BIN_DIR"
fi

install -m 755 bin/jbuild bin/jenkins-jobs-update "$BIN_DIR/"
install -m 644 bin/jenkins_api.py "$BIN_DIR/"
echo "binários em $BIN_DIR (jbuild, jenkins-jobs-update)"

if command -v zsh >/dev/null; then
  if [[ -w /usr/local/share/zsh/site-functions || -w /usr/local/share ]]; then
    COMP_DIR=/usr/local/share/zsh/site-functions
  else
    COMP_DIR="$HOME/.zsh/completions"
    grep -q 'fpath=(.*\.zsh/completions' "$HOME/.zshrc" 2>/dev/null ||
      echo 'fpath=($HOME/.zsh/completions $fpath)' >> "$HOME/.zshrc"
  fi
  mkdir -p "$COMP_DIR"
  install -m 644 completions/_jbuild "$COMP_DIR/"
  rm -f "$HOME"/.zcompdump 2>/dev/null || true
  echo "completion do zsh em $COMP_DIR (abra um shell novo)"
fi

if [[ ! -f "$HOME/.jbuildrc" ]]; then
  cat > "$HOME/.jbuildrc" <<'RC'
# Config do jbuild
JENKINS_URL="https://jenkins.exemplo.com"
# JBUILD_DEFAULT_BRANCH="sandbox"
# JBUILD_STRIP_PREFIXES="prefixo1-,prefixo2-"
# JBUILD_LOG_LINES=60
RC
  echo "criado ~/.jbuildrc — edite o JENKINS_URL"
fi

cat <<'MSG'

Falta só a credencial: gere um API token no Jenkins (seu usuário → Security →
API Token) e adicione ao ~/.netrc (chmod 600):

  machine <host-do-jenkins>
    login <seu-user-id>
    password <token>

Depois: jenkins-jobs-update  &&  jbuild <TAB>
MSG
