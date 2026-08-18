#!/usr/bin/env bash
# scan-redis-session.sh
# Rode a partir de ~/IdeaProjects:   bash scan-redis-session.sh
# (ou passe o caminho base:          bash scan-redis-session.sh /c/Users/rfalgad/IdeaProjects)
#
# Varre os repos itau-um3-* pra revelar COMO a sessão em Redis/Valkey é
# criada, lida e expirada — quais chaves, que formato e que valores — pra
# você reproduzir o mesmo estado no Valkey local antes de chamar o handler.

set -uo pipefail

BASE="${1:-.}"
OUT="redis-session-scan.txt"
: > "$OUT"

# pastas de ruído que não interessam
EXCLUDES=(--exclude-dir=vendor --exclude-dir=node_modules --exclude-dir=.git
          --exclude-dir=dist --exclude-dir=build --exclude-dir=.idea
          --exclude-dir=coverage)
# só arquivos que importam (inclui specs de propósito!)
INCLUDES=(--include=*.go --include=*.ts --include=*.js --include=*.json
          --include=*.yml --include=*.yaml --include=*.env --include=*.tf
          --include=*.properties)

log()     { printf '%s\n' "$*" | tee -a "$OUT"; }
section() { printf '\n========================= %s =========================\n' "$1" | tee -a "$OUT"; }
sub()     { printf '\n----- %s -----\n' "$1" | tee -a "$OUT"; }

scan() {  # scan <rótulo> <regex-ERE>
  local label="$1" re="$2"
  sub "$label"
  grep -rniE "${EXCLUDES[@]}" "${INCLUDES[@]}" -e "$re" "$repo" 2>/dev/null \
    | sed "s#^${BASE}/##" | tee -a "$OUT" || true
}

shopt -s nullglob
found=0
for repo in "$BASE"/itau-um3-*; do
  [ -d "$repo" ] || continue
  found=1
  section "$(basename "$repo")"

  [ -f "$repo/app/go.mod" ]       && log "tipo: Go"
  [ -f "$repo/app/package.json" ] && log "tipo: Node/TS"

  # 1) onde e como o cliente redis/valkey é criado
  scan "cliente / conexão" \
    'ioredis|new Redis|createClient|redis\.NewClient|NewClusterClient|go-redis|redis/v[89]|valkey|getRedisConnection|RedisConnection'

  # 2) tudo que menciona sessão (o coração da busca)
  scan "menções a sessão" \
    'session'

  # 3) montagem da CHAVE (prefixos, templates, connectionId)
  scan "formato de chave" \
    'Sprintf\(|connectionId|connection_id|ConnectionID|connectionID|"[a-z0-9_.:-]+:%s"|:\$\{'

  # 4) ESCRITA da sessão (o que grava, com que shape)
  scan "escrita (set/hset/setex/sadd/zadd)" \
    '\.setex\(|\.set\(|\.hset\(|\.hmset\(|\.SetEX\(|\.Set\(|\.HSet\(|\.SAdd\(|\.ZAdd\('

  # 5) LEITURA / verificação (o que o handler checa)
  scan "leitura / verificação (get/exists/hgetall)" \
    '\.get\(|\.exists\(|\.hgetall\(|\.Get\(|\.Exists\(|\.HGetAll\(|\.HGet\('

  # 6) EXPIRAÇÃO / TTL (por quanto tempo a sessão vive)
  scan "expiração / ttl" \
    '\.expire\(|\.setex\(|\.Expire\(|SETEX|EXPIRE|WithExpiration|\bttl\b|SESSION_TTL|_TTL|time\.(Minute|Hour|Second)'
done
shopt -u nullglob

if [ "$found" -eq 0 ]; then
  log "Nenhum diretório itau-um3-* encontrado em '$BASE'."
  log "Rode a partir de ~/IdeaProjects ou passe o caminho base como argumento."
  exit 1
fi

printf '\n\n===> Relatório completo salvo em: %s\n' "$OUT"
printf '===> Comece olhando os blocos "escrita" (quem CRIA a sessao) e\n'
printf '     "leitura / verificacao" do wshandler (quem CHECA a sessao).\n'
