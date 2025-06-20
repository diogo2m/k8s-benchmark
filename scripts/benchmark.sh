#!/bin/bash

CURRENT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# General configurations
OUTPUT_FILE_PATH="results/$(date +%s)"

# Benchmark configurations
MIN_CLIENTS=10
MAX_CLIENTS=100
CLIENT_STEP=10

MIN_SERVERS=2
MAX_SERVERS=10
SERVER_STEP=2

REPETITIONS=1

MESSAGES_LIST="1 10 100"

SERVER_IP=$(kubectl get svc socket-server-lb -o jsonpath='{.spec.clusterIP}')
SERVER_PORT=80

# Defines how request will be generated container|script
TRAFFIG_GENERATION_MODE=script

TAG_IMAGE=go

mkdir -p $OUTPUT_FILE_PATH

run_message_generator_script_mode(){
  echo ">>> Starting message generation."
  bash scripts/client.sh $SERVER_IP $SERVER_PORT $c $m
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
    kubectl delete pod "$pod" -n "$namespace"
  done

  kubectl delete deployment server-deploy

  rm -f /mnt/k8s-results/*

}

for (( iter=0; iter<REPETITIONS; iter+=1))
do

  clean_env

  echo ">>> Starting server deployment"
  if [[ "$TAG_IMAGE" == "go" ]]; then
    DEPLOYMENT_FILE=config/base/server-deployment-go.yaml
  else
    DEPLOYMENT_FILE=config/base/server-deployment.yaml
  fi

  kubectl apply -f $DEPLOYMENT_FILE
  kubectl apply -f config/base/server-service.yaml

  for m in $MESSAGES_LIST
  do
    for (( s=MIN_SERVERS; s<=MAX_SERVERS; s+=SERVER_STEP ))
    do
      echo ">>> Scaling servers to $s replicas..."
      kubectl scale deployment server-deploy --replicas=$s

      echo "> Waiting 30 seconds for server scaling..."
      sleep 30

      for (( c=MIN_CLIENTS; c<=MAX_CLIENTS; c+=CLIENT_STEP ))
      do
        echo ">>> Running test with $c clients, $s servers and $m messages..."

        if [[ "$TRAFFIG_GENERATION_MODE" == "script" ]]; then
            run_message_generator_script_mode
        elif [[ "$TRAFFIG_GENERATION_MODE" == "container" ]]; then
            run_message_generator_container_mode
        fi
    
        sleep 2

        # Run mean_results.py with label argument
        python3 scripts/mean_results.py "${c}clients-${s}servers-${m}messages"

        sleep 2

        rm -f /mnt/k8s-results/*

        #envsubst < client-job.yaml | kubectl delete -f -
        sleep 30
      done
    done

    python3 scripts/plot.py average_result.csv
    mv plots ${OUTPUT_FILE_PATH}/plots_${m}_${iter}
    mv average_result.csv ${OUTPUT_FILE_PATH}/average_result_${m}_${iter}.csv
    mv resources_log ${OUTPUT_FILE_PATH}/resources_log_${m}_${iter}

  done
done

echo "DONE!"

