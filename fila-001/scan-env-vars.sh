#!/usr/bin/env bash
# scan-env-vars.sh
# Rode a partir de ~/IdeaProjects:  bash scan-env-vars.sh
# Descobre QUAIS variáveis de ambiente cada app itau-um3-* lê, pra você
# preencher o bloco `environment:` de cada serviço no docker-compose.

set -uo pipefail

BASE="${1:-.}"
OUT="env-vars-scan.txt"
: > "$OUT"

EXCLUDES=(--exclude-dir=vendor --exclude-dir=node_modules --exclude-dir=.git
          --exclude-dir=dist --exclude-dir=build --exclude-dir=.idea
          --exclude-dir=coverage)
INCLUDES=(--include=*.go --include=*.ts --include=*.js
          --include=*.yml --include=*.yaml --include=*.tf --include=*.env
          --include=*.properties --include=*.json)

log()     { printf '%s\n' "$*" | tee -a "$OUT"; }
section() { printf '\n===================== %s =====================\n' "$1" | tee -a "$OUT"; }
sub()     { printf '\n----- %s -----\n' "$1" | tee -a "$OUT"; }

scan() {  # scan <rótulo> <regex-ERE>
  local label="$1" re="$2"
  sub "$label"
  grep -rhoiE "${EXCLUDES[@]}" "${INCLUDES[@]}" -e "$re" "$repo" 2>/dev/null \
    | sort -u | tee -a "$OUT" || true
}

shopt -s nullglob
for repo in "$BASE"/itau-um3-*; do
  [ -d "$repo" ] || continue
  section "$(basename "$repo")"
  [ -f "$repo/app/go.mod" ]       && log "tipo: Go"
  [ -f "$repo/app/package.json" ] && log "tipo: Node/TS"

  # nomes de env crus (Go os.Getenv e Node process.env)
  scan "os.Getenv / process.env" \
    'os\.Getenv\("[^"]+"\)|process\.env\.[A-Za-z_][A-Za-z0-9_]*'

  # chaves lidas via Viper / quickgo config
  scan "viper / config keys" \
    'viper\.(Get[A-Za-z]*|BindEnv|SetDefault)\("[^"]+"|GetString\("[^"]+"|GetInt\("[^"]+"|GetBool\("[^"]+"'

  # tags de struct de config (env / mapstructure)
  scan "struct tags de config" \
    '(env|mapstructure|envconfig):"[^"]+"'

  # bloco environment da IaC de PROD (fonte da verdade dos nomes reais)
  scan "environment na infra (terraform/serverless)" \
    'environment|env_variables|[A-Z][A-Z0-9_]{3,}[[:space:]]*[:=]'
done
shopt -u nullglob

printf '\n\n===> Salvo em: %s\n' "$OUT"
printf '===> O bloco "environment na infra" costuma ter a lista REAL de\n'
printf '     variaveis que o app recebe em prod — use como gabarito.\n'


--

#!/usr/bin/env bash
# scan-getenv.sh
# Rode a partir de ~/IdeaProjects:  bash scan-getenv.sh
# (ou passe o caminho base:         bash scan-getenv.sh /c/Users/user/IdeaProjects)
#
# Lista APENAS os os.Getenv("...") de cada repo itau-um3-* (sem mapstructure,
# viper, infra ou qualquer outro ruído de config).

set -uo pipefail

BASE="${1:-.}"
OUT="getenv-scan.txt"
: > "$OUT"

shopt -s nullglob
found=0
for repo in "$BASE"/itau-um3-*; do
  [ -d "$repo" ] || continue
  found=1

  printf '\n===== %s =====\n' "$(basename "$repo")" | tee -a "$OUT"

  # lista deduplicada dos nomes lidos via os.Getenv
  grep -rhoE --include=*.go --exclude-dir=vendor \
    'os\.Getenv\("[^"]+"\)' "$repo" 2>/dev/null \
    | sort -u | tee -a "$OUT" || true
done
shopt -u nullglob

if [ "$found" -eq 0 ]; then
  printf "Nenhum diretorio itau-um3-* encontrado em '%s'.\n" "$BASE" | tee -a "$OUT"
  printf "Rode a partir de ~/IdeaProjects ou passe o caminho base como argumento.\n"
  exit 1
fi

printf '\n===> Salvo em: %s\n' "$OUT"
printf '===> Para ver ARQUIVO:LINHA em vez da lista, troque -rhoE por -rnE.\n'