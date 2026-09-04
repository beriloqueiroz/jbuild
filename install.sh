#!/usr/bin/env bash
# Instala o jbuild: binários, completion do zsh e o esqueleto do ~/.jbuildrc.
set -euo pipefail
cd "$(dirname "$0")"

command -v python3 >/dev/null || {
  echo "erro: python3 não encontrado." >&2
  echo "no macOS: xcode-select --install  (ou brew install python)" >&2
  exit 1
}

for dir in /opt/homebrew/bin /usr/local/bin; do
  [[ -w $dir ]] && BIN_DIR=$dir && break
done
if [[ -z ${BIN_DIR:-} ]]; then
  BIN_DIR="$HOME/.local/bin"
  mkdir -p "$BIN_DIR"
fi

install -m 755 bin/jbuild bin/jenkins-jobs-update "$BIN_DIR/"
install -m 644 bin/jenkins_api.py "$BIN_DIR/"
echo "binários em $BIN_DIR (jbuild, jenkins-jobs-update)"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "atenção: $BIN_DIR não está no PATH — acrescente ao seu shell rc:"
     echo "  export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

if command -v zsh >/dev/null; then
  COMP_DIR=""
  for dir in /opt/homebrew/share/zsh/site-functions /usr/local/share/zsh/site-functions; do
    [[ -w $dir ]] && COMP_DIR=$dir && break
  done
  if [[ -z $COMP_DIR ]]; then
    COMP_DIR="$HOME/.zsh/completions"
    grep -q 'fpath=(.*\.zsh/completions' "$HOME/.zshrc" 2>/dev/null ||
      echo 'fpath=($HOME/.zsh/completions $fpath)' >> "$HOME/.zshrc"
  fi
  mkdir -p "$COMP_DIR"
  install -m 644 completions/_jbuild "$COMP_DIR/"
  rm -f "$HOME"/.zcompdump* 2>/dev/null || true
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
