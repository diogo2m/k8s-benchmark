# Gremio

This repository was developed for eduactional porpuses. We aim to show and evaluate the performance of containerized solutions simulating application protocol behavioring using socket-based applications.


## Getting Started

For this tutorial, we assume you have access to a already installed Kubernetes cluster and Docker tools installed according to their official website.

First, you need to ensure you are on a super user:

```bash
su root
```

Now, you can prepare the ambient by using the following command:

```bash
bash scripts/setup.sh
```

This script is responsible to build and export the images to the nodes of the cluster and install the dependencies.

Now, you can ajust the `scripts/benchmark.sh` to run the desired experiment using the parameters as shown:

```
MIN_CLIENTS=10
MAX_CLIENTS=100
CLIENT_STEP=10

MIN_SERVERS=2
MAX_SERVERS=10
SERVER_STEP=2

REPETITIONS=1

MESSAGES_LIST="1 10 100"

IMAGE_TAG=python
```

Then, you can simply run:

```bash
bash benchmark.sh
```

The script is responsible to handle the pods scaling, message generation and plot the results.
