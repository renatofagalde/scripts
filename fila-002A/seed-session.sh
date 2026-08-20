#!/usr/bin/env bash
# seed-session.sh
# Semeia uma sessão de teste no Valkey local no mesmo formato do authorizer.
# sessionKey = SESSION:<unidade_organizacional>#<id_agente>#<id_pessoa>  (hash, via HGETALL)
# Rode de itau-um3-app-wshandler/local/ (usa o valkey do compose).

set -euo pipefail

CLI=(docker compose exec -T valkey valkey-cli)

# ---- as 3 partes da chave (TÊM que ser os mesmos valores usados no hash) ----
UO="uo-teste"          # unidade_organizacional
AGENTE="agent"         # id_agente  (= chatbot)
ID_PESSOA="12345"      # id_pessoa  (= cod_cli)

# monta o sessionKey exatamente como o authorizer (linha 112 do connectControlv4.ts)
SKEY="SESSION:${UO}#${AGENTE}#${ID_PESSOA}"

# ---- outros valores do hash ----
CONN="testconn123"     # tem que bater com o connectionId do evento que você disparar
ORG="af1ea2f3-c53e-4903-805e-000000000000"
CANAL="WHATSAPP"
TTL=3600               # local: 1h (prod usa 900 = 15min)

# ---- 1) o HASH da sessão (campos coerentes com a chave) ----
"${CLI[@]}" HSET "$SKEY" \
  organizacao "$ORG" \
  unidade_organizacional "$UO" \
  chatbot "$AGENTE" \
  cod_cli "$ID_PESSOA" \
  id_contato "" \
  id_operador "" \
  canal "$CANAL" \
  channel_session_id "" \
  from "agent" \
  ConnectionId "$CONN"
"${CLI[@]}" EXPIRE "$SKEY" "$TTL"

# ---- 2) mapper connectionId -> sessionKey ----
"${CLI[@]}" SET "SESSION_MAPPER:$CONN" "$SKEY" EX "$TTL"

# ---- conferência ----
echo "sessionKey = $SKEY"
echo "--- mapper ---"; "${CLI[@]}" GET "SESSION_MAPPER:$CONN"
echo "--- hash ---";   "${CLI[@]}" HGETALL "$SKEY"
echo "--- ttl ---";    "${CLI[@]}" TTL "$SKEY"
