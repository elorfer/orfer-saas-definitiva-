#!/bin/bash

# Script para verificar costos de AWS
# Requiere: AWS CLI configurado

echo "💰 Verificando costos de AWS..."
echo ""

# Obtener fecha actual y primer día del mes
CURRENT_DATE=$(date +%Y-%m-%d)
MONTH_START=$(date +%Y-%m-01)

echo "📅 Período: $MONTH_START hasta $CURRENT_DATE"
echo ""

# Verificar si AWS CLI está instalado
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI no está instalado"
    echo "Instala con: https://aws.amazon.com/cli/"
    exit 1
fi

# Verificar credenciales
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS CLI no está configurado"
    echo "Configura con: aws configure"
    exit 1
fi

echo "✅ AWS CLI configurado correctamente"
echo ""

# Obtener costos del mes actual
echo "📊 Costos del mes actual:"
aws ce get-cost-and-usage \
  --time-period Start=$MONTH_START,End=$CURRENT_DATE \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE \
  --query 'ResultsByTime[0].Groups[*].[Keys[0],Metrics.BlendedCost.Amount]' \
  --output table

echo ""
echo "💡 Para más detalles, ve a: https://console.aws.amazon.com/cost-management/home"

