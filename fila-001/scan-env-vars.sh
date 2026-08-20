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

=======



#!/usr/bin/env bash
# recon-um3.sh
# Rode a partir de ~/IdeaProjects:  bash recon-um3.sh
# (ou passe o caminho base:         bash recon-um3.sh /c/Users/user/IdeaProjects)
#
# Coleta num arquivo so tudo que falta pra fechar o ambiente local:
#   A) formato do sessionKey / sessionMappersKeys (authorizer Node)
#   B) escrita da sessao (authorizer Node) - chave + payload + ttl
#   C) leitura da sessao (wshandler Go) - qual chave ele busca
#   D) schema do DynamoDB (tabela 007) - historic
#
# Saida: ~/Downloads/recon-um3_AAAA-MM-DD_HH-MM-SS.txt

set -uo pipefail

BASE="${1:-.}"

# ---- destino: pasta Downloads do usuario, nome = data e hora --------------
DOWNLOADS="$HOME/Downloads"
mkdir -p "$DOWNLOADS"
STAMP="$(date +%Y-%m-%d_%H-%M-%S)"
OUT="$DOWNLOADS/recon-um3_${STAMP}.txt"
: > "$OUT"

AUTH="$BASE/itau-um3-app-iumessenger-lambda-authorizer-websocket"
WS="$BASE/itau-um3-app-wshandler"
HIST="$BASE/itau-um3-app-historic"
CONNCTL="$AUTH/app/src/apis/connectControlv4.ts"

EX=(--exclude-dir=vendor --exclude-dir=node_modules --exclude-dir=.git
    --exclude-dir=dist --exclude-dir=build --exclude-dir=.idea --exclude-dir=coverage -I)

section() { printf '\n############### %s ###############\n' "$1" | tee -a "$OUT"; }
sub()     { printf '\n----- %s -----\n' "$1" | tee -a "$OUT"; }
g()       { grep -rn "${EX[@]}" "$@" 2>/dev/null | sed "s#^${BASE}/##" | tee -a "$OUT" || true; }
note()    { printf '%s\n' "$*" | tee -a "$OUT"; }

note "recon-um3 - gerado em ${STAMP}"
note "base: $BASE"

# ============================================================
section "A) sessionKey / sessionMappersKeys (authorizer)"
if [ -f "$CONNCTL" ]; then
  sub "atribuicoes de sessionKey / sessionMappersKeys / sessionId"
  g -E --include=*.ts -e 'sessionKey[[:space:]]*=|sessionMappersKeys[[:space:]]*=|sessionId[[:space:]]*=|currentSession' "$CONNCTL"
  sub "primeiras 90 linhas do connectControlv4.ts (contexto da montagem)"
  sed -n '1,90p' "$CONNCTL" | sed 's/^/    /' | tee -a "$OUT" || true
else
  note "NAO achei $CONNCTL - ajuste o caminho se o arquivo mudou de lugar."
  sub "procurando sessionKey em todo o authorizer"
  g -E --include=*.ts -e 'sessionKey[[:space:]]*=|sessionMappersKeys[[:space:]]*=' "$AUTH"
fi

# ============================================================
section "B) escrita da sessao (authorizer) - set/hset + contexto"
g -B8 -A4 -E --include=*.ts --include=*.js -e '\.(set|setex|psetex|hset|hmset)\(' "$AUTH"

sub "ttl / expiracao no authorizer"
g -iE --include=*.ts --include=*.js -e 'expire\(|setex\(|60[[:space:]]*\*[[:space:]]*15|ttl' "$AUTH"

# ============================================================
section "C) leitura da sessao (wshandler Go) - a chave PRECISA bater com B"
g -B3 -A6 -E --include=*.go -e 'SESSION_MAPPER|\.HGetAll\(|\.HGet\(|\.Get\(|\.Exists\(' "$WS"

sub "montagem de chave no wshandler (Sprintf/prefixo/connectionId)"
g -B1 -A2 -E --include=*.go -e 'Sprintf\(|connectionId|connection_id|ConnectionID|SESSION' "$WS"

sub "uso de USE_LOCAL_CACHE / TEST_REDIS_URL (o switch de redis local)"
g -B2 -A6 -E --include=*.go -e 'USE_LOCAL_CACHE|TEST_REDIS_URL' "$WS"

# ============================================================
section "D) schema do DynamoDB (tabela 007 - historic)"
sub "tags dynamodbav (shape do item)"
g -E --include=*.go -e 'dynamodbav:"[^"]+"' "$HIST"

sub "chave de busca (GetItem/PutItem/Key/TableName)"
g -B2 -A10 -E --include=*.go -e 'GetItem|PutItem|UpdateItem|Key:[[:space:]]*map|TableName' "$HIST"

sub "criacao de tabela em teste (KeySchema/AttributeDefinitions reais)"
g -B2 -A15 -E --include=*.go -e 'CreateTable|KeySchema|AttributeDefinitions|KeyType' "$HIST"

# ============================================================
printf '\n\n=================================================\n' | tee -a "$OUT"
note "===> Salvo em: $OUT"
note "===> Cola o conteudo desse arquivo no chat."
note "===> Prioridade: bloco A (formato do sessionKey) + bloco C (leitura no wshandler)."

# mensagem final no terminal (fora do arquivo)
printf '\nArquivo gerado: %s\n' "$OUT"
