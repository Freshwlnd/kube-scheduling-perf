KIND_CLUSTER_NAME = volcano

KIND_CONFIG = ./kind.yaml 

KUBECONFIG = ./kubeconfig.yaml

LIMIT_CPU ?= 8

.PHONY: up
up: \
	create-cluster
	make wait
	make -j 2 \
		create-kwok \
		create-volcano
	make limit-built-controller-manager

	make uncordon

.PHONY: down
down: \
	delete-cluster 

.PHONY: create-kwok
create-kwok:
	KUBECONFIG=$(KUBECONFIG) kubectl create -k ../../base/kwok/crd
	KUBECONFIG=$(KUBECONFIG) kubectl kustomize ../../base/kwok | ../../hack/local-registry-with-load-images.sh
	sleep 1
	KUBECONFIG=$(KUBECONFIG) kubectl create -k ../../base/kwok

.PHONY: limit-built-controller-manager
limit-built-controller-manager:
	sleep 1
	docker exec -i $(KIND_CLUSTER_NAME)-control-plane sed -i 's/cpu: 200m/cpu: 1\r\n      limits:\r\n        cpu: $(LIMIT_CPU)/' /etc/kubernetes/manifests/kube-controller-manager.yaml 

.PHONY: create-cluster
create-cluster:
	cat kind.yaml | ../../hack/local-registry-with-load-images.sh
	KUBECONFIG=$(KUBECONFIG) KIND_CONFIG=$(KIND_CONFIG) KIND_CLUSTER_NAME=$(KIND_CLUSTER_NAME) ../../hack/kind-with-local-registry.sh
	# Avoid KindNet OOMKilled
	KUBECONFIG=$(KUBECONFIG) kubectl patch daemonset -n kube-system kindnet --type json -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/resources"}]'

	KUBECONFIG=$(KUBECONFIG) kubectl patch daemonset -n kube-system kindnet --type json -p '[{"op": "replace", "path": "/spec/template/spec/nodeSelector", "value": {"node-role.kubernetes.io/control-plane": "" }}]'
	KUBECONFIG=$(KUBECONFIG) kubectl patch daemonset -n kube-system kube-proxy --type json -p '[{"op": "replace", "path": "/spec/template/spec/nodeSelector", "value": {"node-role.kubernetes.io/control-plane": "" }}]'

.PHONY: delete-cluster
delete-cluster:
	KUBECONFIG=$(KUBECONFIG) KIND_CLUSTER_NAME=$(KIND_CLUSTER_NAME) kind delete cluster
	-rm $(KUBECONFIG)

.PHONY: create-volcano
create-volcano:
	KUBECONFIG=$(KUBECONFIG) kubectl kustomize ../../schedulers/volcano | ../../hack/local-registry-with-load-images.sh
	KUBECONFIG=$(KUBECONFIG) kubectl create -k ../../schedulers/volcano
	KUBECONFIG=$(KUBECONFIG) kubectl patch deploy -n volcano-system volcano-admission --type json \
		-p '[{"op": "replace", "path": "/spec/template/spec/containers/0/resources", "value": {"requests":{"cpu": "500m"}, "limits":{"cpu": $(LIMIT_CPU) }}}]'
	KUBECONFIG=$(KUBECONFIG) kubectl patch deploy -n volcano-system volcano-controllers --type json \
		-p '[{"op": "replace", "path": "/spec/template/spec/containers/0/resources", "value": {"requests":{"cpu": "500m"}, "limits":{"cpu": $(LIMIT_CPU) }}}]'
	KUBECONFIG=$(KUBECONFIG) kubectl patch deploy -n volcano-system volcano-scheduler --type json \
		-p '[{"op": "replace", "path": "/spec/template/spec/containers/0/resources", "value": {"requests":{"cpu": "500m"}, "limits":{"cpu": $(LIMIT_CPU) }}}]'
	sleep 1

.PHONY: delete-volcano
delete-volcano:
	KUBECONFIG=$(KUBECONFIG) kubectl delete -k ../../schedulers/volcano

.PHONY: reset-auditlog
reset-auditlog:
	docker exec $(KIND_CLUSTER_NAME)-control-plane sh -c 'true > /var/log/kubernetes/kube-apiserver-audit.$(KIND_CLUSTER_NAME).log' || :

.PHONY: wait
wait:
	-for i in $$(seq 1 60); do \
		KUBECONFIG=$(KUBECONFIG) kubectl wait -A \
			--for=condition=Ready=True pod \
			--all \
			--timeout=10s >/dev/null 2>&1 && break; \
	done
	sleep 1

uncordon:
	KUBECONFIG=$(KUBECONFIG) kubectl uncordon $(KIND_CLUSTER_NAME)-control-plane
