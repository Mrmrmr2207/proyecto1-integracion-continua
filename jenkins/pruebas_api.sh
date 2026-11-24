#!/usr/bin/env bash
# Pruebas de humo de la API (Entrega 2 - Jenkins).
# Ejecuta verificaciones HTTP contra la API levantada con Docker Compose
# y genera un reporte JUnit (reports/junit-api.xml) que Jenkins publica.
set -u
API_URL="${API_URL:-http://localhost:5000}"
BUILD="${BUILD_NUMBER:-local}"
mkdir -p reports
CASES=""; FAILS=0; TOTAL=0

registrar() { # nombre, ok(0/1), detalle, segundos
  TOTAL=$((TOTAL+1))
  local det; det=$(printf '%s' "$3" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
  if [ "$2" -eq 0 ]; then
    CASES="$CASES<testcase classname=\"pruebas.api_tareas\" name=\"$1\" time=\"$4\"><system-out>$det</system-out></testcase>"
    echo "[OK]    $1"
  else
    FAILS=$((FAILS+1))
    CASES="$CASES<testcase classname=\"pruebas.api_tareas\" name=\"$1\" time=\"$4\"><failure message=\"fallo\">$det</failure></testcase>"
    echo "[FALLO] $1 -> $3"
  fi
}

# 1. Esperar /health (status ok y database up)
t0=$(date +%s); ok=1; body=""
for intento in $(seq 1 30); do
  if body=$(curl -fsS "$API_URL/health"); then
    echo "API disponible en el intento $intento"; ok=0; break
  fi
  echo "Esperando la API... intento $intento"; sleep 2
done
echo "$body" > health.json; echo "GET /health -> $body"
if [ $ok -eq 0 ] && echo "$body" | grep -q '"status":"ok"' && echo "$body" | grep -q '"database":"up"'; then r=0; else r=1; fi
registrar "GET /health responde status ok y database up" $r "$body" $(( $(date +%s)-t0 ))

# 2. GET /tareas devuelve lista JSON
t0=$(date +%s)
body=$(curl -fsS "$API_URL/tareas"); rc=$?
echo "$body" > tareas.json; echo "GET /tareas -> $body"
if [ $rc -eq 0 ] && echo "$body" | grep -q '"tareas"'; then r=0; else r=1; fi
registrar "GET /tareas devuelve la lista de tareas" $r "$body" $(( $(date +%s)-t0 ))

# 3. POST /tareas crea una tarea
t0=$(date +%s); titulo="Prueba Jenkins build $BUILD"
body=$(curl -fsS -X POST "$API_URL/tareas" -H "Content-Type: application/json" -d "{\"titulo\":\"$titulo\"}"); rc=$?
echo "$body" > tarea_creada.json; echo "POST /tareas -> $body"
if [ $rc -eq 0 ] && echo "$body" | grep -q "$titulo"; then r=0; else r=1; fi
registrar "POST /tareas crea una tarea nueva" $r "$body" $(( $(date +%s)-t0 ))

# 4. POST /tareas sin titulo responde 400 (validacion)
t0=$(date +%s)
code=$(curl -s -o /tmp/resp400.json -w '%{http_code}' -X POST "$API_URL/tareas" -H "Content-Type: application/json" -d '{}')
echo "POST /tareas sin titulo -> HTTP $code $(cat /tmp/resp400.json)"
if [ "$code" = "400" ]; then r=0; else r=1; fi
registrar "POST /tareas sin titulo responde 400" $r "HTTP $code $(cat /tmp/resp400.json)" $(( $(date +%s)-t0 ))

echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><testsuite name=\"Pruebas API tareas (Jenkins)\" tests=\"$TOTAL\" failures=\"$FAILS\" errors=\"0\">$CASES</testsuite>" > reports/junit-api.xml
echo "Resultado: $((TOTAL-FAILS))/$TOTAL pruebas superadas"
[ $FAILS -eq 0 ]
