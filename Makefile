SHELL := /bin/bash

PROJECT_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
NAMESPACE := mlcnp-blueprint
IMAGE := mlcnp/java-openrasp-demo:local
KUSTOMIZE_DIR := $(PROJECT_ROOT)/deploy/kubectl

.PHONY: help start build load install quickstart validate verify status forward rasp-logs uninstall stop

help:
	@echo "MLCNP Blueprint"
	@echo "  make quickstart  # start Minikube, build, load, and install"
	@echo "  make validate    # validate the public kubectl template"
	@echo "  make verify      # test an installation running in the current cluster"
	@echo "  make status      # list installed resources"
	@echo "  make forward     # expose the gateway on localhost:18080"
	@echo "  make rasp-logs   # show the application and OpenRASP logs"
	@echo "  make uninstall   # remove the blueprint namespace"
	@echo "  make stop        # stop Minikube"

start:
	minikube start --cni=calico

build:
	docker build --platform linux/amd64 \
		--tag $(IMAGE) \
		--file $(PROJECT_ROOT)/images/java-openrasp-demo/Dockerfile \
		$(PROJECT_ROOT)

load:
	minikube image load $(IMAGE)

install:
	kubectl apply -k $(KUSTOMIZE_DIR)
	kubectl -n $(NAMESPACE) rollout status deployment/mlcnp-gateway --timeout=8m
	kubectl -n $(NAMESPACE) rollout status deployment/mlcnp-application --timeout=8m

quickstart: start build load install

validate:
	$(PROJECT_ROOT)/scripts/validate-kubectl.sh

verify:
	$(PROJECT_ROOT)/scripts/test-cluster.sh

status:
	kubectl -n $(NAMESPACE) get deployments,pods,services,networkpolicies

forward:
	kubectl -n $(NAMESPACE) port-forward service/mlcnp-gateway 18080:8080

rasp-logs:
	kubectl -n $(NAMESPACE) logs deployment/mlcnp-application --container application-with-rasp

uninstall:
	kubectl delete -k $(KUSTOMIZE_DIR)

stop:
	minikube stop
