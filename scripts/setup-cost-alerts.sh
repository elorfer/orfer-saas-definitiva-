#!/bin/bash

# Script para configurar alertas de costos en AWS
# Requiere: AWS CLI configurado con permisos de CloudWatch y SNS

echo "💰 Configurando alertas de costos en AWS..."
echo ""

# Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI no está instalado"
    exit 1
fi

# Verificar credenciales
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS CLI no está configurado"
    exit 1
fi

# Obtener cuenta ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"

echo "✅ Cuenta AWS: $ACCOUNT_ID"
echo "✅ Región: $REGION"
echo ""

# Crear tema SNS para alertas (si no existe)
TOPIC_NAME="aws-cost-alerts"
TOPIC_ARN=$(aws sns list-topics --query "Topics[?contains(TopicArn, '$TOPIC_NAME')].TopicArn" --output text 2>/dev/null)

if [ -z "$TOPIC_ARN" ]; then
    echo "📧 Creando tema SNS para alertas..."
    TOPIC_ARN=$(aws sns create-topic --name $TOPIC_NAME --query 'TopicArn' --output text)
    echo "✅ Tema creado: $TOPIC_ARN"
    
    # Suscribirse al tema (necesitarás confirmar el email)
    echo ""
    echo "⚠️  IMPORTANTE: Necesitas suscribirte al tema SNS con tu email"
    echo "   Ve a: https://console.aws.amazon.com/sns/v3/home?region=$REGION#/topics"
    echo "   Selecciona el tema: $TOPIC_NAME"
    echo "   Click en 'Create subscription' y agrega tu email"
else
    echo "✅ Tema SNS ya existe: $TOPIC_ARN"
fi

echo ""

# Crear alarmas de costos
echo "🔔 Configurando alarmas de costos..."

# Alerta 1: $10 USD
aws cloudwatch put-metric-alarm \
    --alarm-name "aws-cost-alert-10usd" \
    --alarm-description "Alerta cuando los costos superan $10 USD" \
    --metric-name EstimatedCharges \
    --namespace AWS/Billing \
    --statistic Maximum \
    --period 86400 \
    --evaluation-periods 1 \
    --threshold 10 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=Currency,Value=USD \
    --alarm-actions $TOPIC_ARN \
    --region us-east-1 2>/dev/null && echo "✅ Alerta de $10 USD configurada" || echo "⚠️  Alerta de $10 USD ya existe o hubo un error"

# Alerta 2: $25 USD
aws cloudwatch put-metric-alarm \
    --alarm-name "aws-cost-alert-25usd" \
    --alarm-description "Alerta cuando los costos superan $25 USD" \
    --metric-name EstimatedCharges \
    --namespace AWS/Billing \
    --statistic Maximum \
    --period 86400 \
    --evaluation-periods 1 \
    --threshold 25 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=Currency,Value=USD \
    --alarm-actions $TOPIC_ARN \
    --region us-east-1 2>/dev/null && echo "✅ Alerta de $25 USD configurada" || echo "⚠️  Alerta de $25 USD ya existe o hubo un error"

# Alerta 3: $50 USD
aws cloudwatch put-metric-alarm \
    --alarm-name "aws-cost-alert-50usd" \
    --alarm-description "Alerta cuando los costos superan $50 USD" \
    --metric-name EstimatedCharges \
    --namespace AWS/Billing \
    --statistic Maximum \
    --period 86400 \
    --evaluation-periods 1 \
    --threshold 50 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=Currency,Value=USD \
    --alarm-actions $TOPIC_ARN \
    --region us-east-1 2>/dev/null && echo "✅ Alerta de $50 USD configurada" || echo "⚠️  Alerta de $50 USD ya existe o hubo un error"

echo ""
echo "✅ Alertas de costos configuradas"
echo ""
echo "📧 IMPORTANTE: Suscríbete al tema SNS con tu email para recibir alertas"
echo "   URL: https://console.aws.amazon.com/sns/v3/home?region=$REGION#/topics"
echo ""
echo "💡 Para ver alarmas: https://console.aws.amazon.com/cloudwatch/home?region=$REGION#alarmsV2:"

