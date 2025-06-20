#!/bin/bash

CURRENT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

build_server_python() {
  echo ">>> Building Gremio-Py"
  cd docker/base/server-container-python || exit 1
  docker build . -t gremio:python
  docker save gremio:python -o gremio-py.tar
  ctr -n k8s.io image import gremio-py.tar
  cd $CURRENT_DIR
}

build_server_go() {
  echo ">>> Building Gremio-Go"
  cd docker/base/server-container-golang || exit 1
  docker build . -t gremio:go
  docker save gremio:go -o gremio-go.tar
  ctr -n k8s.io image import gremio-go.tar
  cd $CURRENT_DIR
  DEPLOYMENT_FILE=server-deployment-go.yaml
}

build_client() {
  echo ">>> Building Gremio-Client"
  cd docker/base/client-container || exit 1
  docker build . -t gremio-client
  docker save gremio-client -o gremio-client.tar
  ctr -n k8s.io image import gremio-client.tar
  cd $CURRENT_DIR
}

if [[ "$1" == "python" ]]; then
  build_server_python
elif [[ "$1" == "go" ]]; then
  build_server_go
else
  build_server_python
  build_server_go
fi

build_client

echo ">>> DONE!"

