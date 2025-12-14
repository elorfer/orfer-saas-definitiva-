#!/bin/bash

# 🧪 Script de Prueba Rápida para el Nuevo Endpoint de Batching
# Uso: ./TEST_BATCH_ENDPOINT.sh [SONG_ID]

# Colores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
BACKEND_URL="http://localhost:3001"
ENDPOINT="/public/songs/playlist/generate"

# Obtener SONG_ID del argumento o usar uno por defecto
SONG_ID=${1:-"1f4a62b3-e5d9-402e-81d8-a281db16db73"}  # ID de ejemplo

echo -e "${YELLOW}🧪 Probando Endpoint de Batching${NC}"
echo -e "URL: ${BACKEND_URL}${ENDPOINT}"
echo -e "Semilla: ${SONG_ID}"
echo ""

# Test 1: Básico
echo -e "${GREEN}Test 1: Solicitud básica (4 recomendaciones)${NC}"
curl -s "${BACKEND_URL}${ENDPOINT}?seed=${SONG_ID}&count=4" | jq '.'
echo ""
echo ""

# Test 2: Con count diferente
echo -e "${GREEN}Test 2: Solicitud con count=8${NC}"
curl -s "${BACKEND_URL}${ENDPOINT}?seed=${SONG_ID}&count=8" | jq '.count, .requested, (.songs | length)'
echo ""
echo ""

# Test 3: Con excludeIds
echo -e "${GREEN}Test 3: Solicitud con excludeIds${NC}"
EXCLUDE_IDS="1f4a62b3-e5d9-402e-81d8-a281db16db73,063edf5b-05ea-42f6-bdc3-dfc225fc78e8"
curl -s "${BACKEND_URL}${ENDPOINT}?seed=${SONG_ID}&count=4&excludeIds=${EXCLUDE_IDS}" | jq '.count, .requested, (.songs | length)'
echo ""
echo ""

# Test 4: Medir tiempo de respuesta
echo -e "${GREEN}Test 4: Medición de tiempo${NC}"
START_TIME=$(date +%s%N)
curl -s "${BACKEND_URL}${ENDPOINT}?seed=${SONG_ID}&count=4" > /dev/null
END_TIME=$(date +%s%N)
DURATION=$((($END_TIME - $START_TIME) / 1000000))
echo -e "${YELLOW}Tiempo de respuesta: ${DURATION}ms${NC}"
echo ""

# Test 5: Verificar estructura de respuesta
echo -e "${GREEN}Test 5: Verificar estructura de respuesta${NC}"
RESPONSE=$(curl -s "${BACKEND_URL}${ENDPOINT}?seed=${SONG_ID}&count=4")
if echo "$RESPONSE" | jq -e '.songs' > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Campo 'songs' presente${NC}"
else
    echo -e "${RED}❌ Campo 'songs' faltante${NC}"
fi

if echo "$RESPONSE" | jq -e '.count' > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Campo 'count' presente${NC}"
else
    echo -e "${RED}❌ Campo 'count' faltante${NC}"
fi

if echo "$RESPONSE" | jq -e '.algorithm' > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Campo 'algorithm' presente${NC}"
else
    echo -e "${RED}❌ Campo 'algorithm' faltante${NC}"
fi

echo ""
echo -e "${YELLOW}✅ Pruebas completadas${NC}"













