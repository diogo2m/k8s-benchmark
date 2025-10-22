#!/bin/bash

CURRENT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p logs
LOG_FILE="logs/benchmark.log"

# General configurations
OUTPUT_FILE_PATH="results/$(date +%s)"

# Benchmark configurations
MIN_CLIENTS=12
MAX_CLIENTS=12
CLIENT_STEP=10

HPA=true
MIN_SERVERS=2
MAX_SERVERS=10
SERVER_STEP=2

REPETITIONS=1

MESSAGES_LIST="1000 2000 3000 4000 5000"
#"100 150 100 200 100 1000 100"
#"1 10 100"

COOLDOWN_TIME=1

SERVER_IP=$(kubectl get svc socket-server-lb -o jsonpath='{.spec.clusterIP}')
SERVER_PORT=80

# Defines how request will be generated container|script
TRAFFIG_GENERATION_MODE=script

TAG_IMAGE=udp-go

mkdir -p $OUTPUT_FILE_PATH

run_message_generator_script_mode(){
  echo ">>> Starting message generation."
  bash scripts/client2.sh $SERVER_IP $SERVER_PORT $c $m
}

run_message_generator_container_mode(){

  echo "> Deleting old jobs"
  kubectl delete job client-job --ignore-not-found
  kubectl get pods --all-namespaces -o jsonpath="{range .items[?(@.metadata.name=='client-job')]}{.metadata.namespace}{'\t'}{.metadata.name}{'\n'}{end}" | while read namespace pod; do
    kubectl delete pod "$pod" -n "$namespace"
  done

  export NUMBER_OF_CLIENTS=$c
  # Replace variables in client-job template and apply to Kubernetes
  envsubst < config/base/client-job.yaml | kubectl apply -f -

  echo "> Waiting for clients to start..."
  kubectl wait --for=condition=ready pod -l job-name=client-job --timeout=60s > /dev/null 2>&1

  echo "Starting monitoring"
  echo "${c}clients-${s}servers-${m}messages" >> resources_log

  # Run monitor.py and append output to resources_log
  python3 scripts/monitor.py >> resources_log

  echo "" >> resources_log

}

clean_env(){

  echo ">>> Deleting old jobs"
  kubectl delete job client-job --ignore-not-found
  kubectl get pods --all-namespaces -o jsonpath="{range .items[?(@.metadata.name=='client-job')]}{.metadata.namespace}{'\t'}{.metadata.name}{'\n'}{end}" | while read namespace pod; do
    kubectl delete pod "$pod" -n "$namespace" --ignore-not-found
  done

  kubectl delete deployment server-deploy --ignore-not-found
  kubectl delete service socket-server-lb --ignore-not-found
  #kubectl delete daemonset server-deploy
  kubectl delete -f config/base/server-service.yaml --ignore-not-found
  kubectl delete -f config/base/server-service-udp.yaml --ignore-not-found
  kubectl delete hpa server-hpa --ignore-not-found
  kubectl delete -f config/base/metrics-server.yaml --ignore-not-found

  rm -f /mnt/k8s-results/*

}

end_env(){
  clean_env
  sudo kill $PID
}


# MAIN LOOP

trap "end_env; exit 0" SIGINT

clean_env

nohup scripts/monitor.sh > monitor_sh.log 2>&1 &
PID=($!)

for (( iter=0; iter<REPETITIONS; iter+=1))
do

  clean_env

  echo ">>> Starting server deployment"
  if [[ "$TAG_IMAGE" == "go" ]]; then
    DEPLOYMENT_FILE=config/base/server-deployment-go.yaml >> $LOG_FILE
    SERVICE_FILE=config/base/server-service.yaml >> $LOG_FILE
  elif [[ "$TAG_IMAGE" == "udp-go" ]]; then
    DEPLOYMENT_FILE=config/base/server-deployment-udp-go.yaml >> $LOG_FILE
    SERVICE_FILE=config/base/server-service-udp.yaml >> $LOG_FILE
  else
    DEPLOYMENT_FILE=config/base/server-deployment.yaml >> $LOG_FILE
    SERVICE_FILE=config/base/server-service.yaml >> $LOG_FILE
  fi

  kubectl apply -f $DEPLOYMENT_FILE >> $LOG_FILE
  #kubectl apply -f config/base/server-daemonset.yaml
  kubectl apply -f $SERVICE_FILE >> $LOG_FILE

  if [ "$HPA" = "true" ] ; then
    kubectl apply -f config/base/hpa.yaml >> $LOG_FILE
    kubectl apply -f config/base/metrics-server.yaml >> $LOG_FILE
    MIN_SERVERS=-1
    MAX_SERVERS=-1
  fi

  echo ">>> Waiting 30 seconds for server to start..."
  sleep 30

  for m in $MESSAGES_LIST
  do
    for (( s=MIN_SERVERS; s<=MAX_SERVERS; s+=SERVER_STEP ))
    do

      if [ ! "$HPA" = "true" ] ; then
        echo ">>> Scaling servers to $s replicas..."
        kubectl scale deployment server-deploy --replicas=$s
        echo "> Waiting 30 seconds for server scaling..."
        sleep 30
      fi 

      for (( c=MIN_CLIENTS; c<=MAX_CLIENTS; c+=CLIENT_STEP ))
      do
        echo ">>> Running test with $c clients, $s servers and $m messages..."

        if [[ "$TRAFFIG_GENERATION_MODE" == "script" ]]; then
            run_message_generator_script_mode
        elif [[ "$TRAFFIG_GENERATION_MODE" == "container" ]]; then
            run_message_generator_container_mode
        fi
    
        #sleep 2

        # Run mean_results.py with label argument
        #python3 scripts/mean_results.py "${c}clients-${s}servers-${m}messages"

        #sleep 2

        rm -f /mnt/k8s-results/* 2>/dev/null

        #envsubst < client-job.yaml | kubectl delete -f -
        echo ">>> Cooling Down"
        sleep $COOLDOWN_TIME
      done
    done

    #python3 scripts/plot.py average_result.csv
    #mv plots ${OUTPUT_FILE_PATH}/plots_${m}_${iter}
    #mv average_result.csv ${OUTPUT_FILE_PATH}/average_result_${m}_${iter}.csv
    #mv resources_log ${OUTPUT_FILE_PATH}/resources_log_${m}_${iter}

  done
done

#end_env

echo "DONE!"

