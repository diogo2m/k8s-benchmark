#!/bin/bash

TARGET_PORT="9999"
MONITOR_DURATION_SECONDS="1"
LOG_FILE="monitoramento_pacotes.log"
SERVER_DEPLOY="server-deploy"

echo "--- Monitoramento de Pacotes Recebidos para Serviço (Porta $TARGET_PORT) ---"
echo "O monitoramento será realizado a cada $MONITOR_DURATION_SECONDS segundos."
echo "O log será salvo em: $LOG_FILE"
echo "Pressione Ctrl+C para parar."
echo ""

# 1. Checa se 'tcpdump' e 'bc' estão instalados
if ! command -v tcpdump &> /dev/null; then
    echo "ERRO: O comando 'tcpdump' não foi encontrado."
    echo "Por favor, instale-o (ex: sudo apt install tcpdump)."
    exit 1
fi
if ! command -v bc &> /dev/null; then
    echo "ERRO: O comando 'bc' (Calculadora de Precisão Arbitrária) não foi encontrado."
    echo "É necessário para cálculos de ponto flutuante. Instale-o (ex: sudo apt install bc)."
    exit 1
fi

get_replicas() {
    local deployment_name="$1"
    # Usa jsonpath para extrair diretamente o valor de .spec.replicas
    local replicas
    replicas=$(kubectl get deployment "$deployment_name" -o=jsonpath='{.spec.replicas}' 2>/dev/null)

    # Se o comando falhar (e.g., deployment não existe) ou for vazio, retorna 0
    if [ $? -ne 0 ] || [ -z "$replicas" ]; then
        echo "0"
    else
        echo "$replicas"
    fi
}

# Inicializa o arquivo de log com o cabeçalho
echo "Horário (UTC) | Pacotes Recebidos | Duração Captura (s) | Taxa (PPS) | # of Replicas" > "$LOG_FILE"
echo "Log inicializado. O console mostrará um resumo, os dados completos estão em $LOG_FILE."

# 2. Loop principal de monitoramento
while true; do
    # Captura o tempo inicial com alta precisão
    START_TIME=$(date +%s.%N)

    # Usa 'tcpdump' para capturar pacotes e 'timeout' para garantir a duração
    # -i any: monitora em todas as interfaces de rede
    # "dst port $TARGET_PORT": filtra apenas pacotes que têm o destino na porta 9999
    
    PACKET_COUNT=$(timeout $MONITOR_DURATION_SECONDS tcpdump -i any -n -l "dst port $TARGET_PORT" 2>/dev/null | wc -l)
    
    # Captura o tempo final
    END_TIME=$(date +%s.%N)

    REPLICAS=$(get_replicas $SERVER_DEPLOY)
    
    # Calcula a duração real da captura usando 'bc' para floats
    ACTUAL_DURATION=$(echo "scale=3; $END_TIME - $START_TIME" | bc)
    
    # Garante uma duração mínima para o cálculo do PPS para evitar erros de divisão
    # O 'bc' compara a duração real com um valor mínimo (0.001s).
    MIN_DURATION=$(echo "scale=3; if ($ACTUAL_DURATION < 0.001) $MONITOR_DURATION_SECONDS else $ACTUAL_DURATION" | bc)
    
    # Calcula a taxa de pacotes por segundo (PPS)
    PPS=$(echo "scale=2; $PACKET_COUNT / $MIN_DURATION" | bc)
    
    # Formata a linha de log com milissegundos e fuso horário UTC (boa prática para logs)
    CURRENT_TIME=$(date -u +"%Y-%m-%d %H:%M:%S.%3N")
    
    LOG_LINE="$CURRENT_TIME | $PACKET_COUNT | $MIN_DURATION | $PPS | $REPLICAS"

    # Salva no arquivo de log (append)
    echo "$LOG_LINE" >> "$LOG_FILE"

    # Exibe no console (apenas um resumo para feedback imediato)
    printf "[%s] Pacotes: %-5s | PPS: %s (Log salvo)\n" "$CURRENT_TIME" "$PACKET_COUNT" "$PPS"

    CURRENT_TIME=$(date +%s.%N)
    DURATION_TO_SLEEP=$(echo "$MONITOR_DURATION_SECONDS - ($END_TIME - $START_TIME)" | bc -l)

    if (( $(echo "$DURATION_TO_SLEEP < 0" | bc -l) )); then
        DURATION_TO_SLEEP=0
    fi

    sleep "$DURATION_TO_SLEEP"

done
