
all:
	make up-base create-kueue
	sleep 30
	true > ./logs/kube-apiserver-audit.log
	make test-kueue
	sleep 300
	mv ./logs/kube-apiserver-audit.log ./logs/kube-apiserver-audit.kueue-$(shell date +%s).log
	make down

	make up-base create-volcano
	sleep 30
	true > ./logs/kube-apiserver-audit.log
	make test-volcano
	sleep 300
	mv ./logs/kube-apiserver-audit.log ./logs/kube-apiserver-audit.volcano-$(shell date +%s).log
	make down

	make up-base create-yunikorn
	sleep 30
	true > ./logs/kube-apiserver-audit.log
	make test-yunikorn
	sleep 300
	mv ./logs/kube-apiserver-audit.log ./logs/kube-apiserver-audit.yunikorn-$(shell date +%s).log
	make down

up-overview: \
	create-cluster \
	create-ingress \
	create-kube-prometheus-stack \
	create-ingress-routes 
	kubectl kustomize ./base/kube-apiserver-audit-exporter | ./hack/local-registry-with-load-images.sh
	./hack/overview.sh | kubectl create -f -

up-base: \
	create-cluster \
	create-kwok

up: \
	create-cluster \
	create-ingress \
	create-kube-prometheus-stack \
	create-kube-apiserver-audit-exporter \
	create-kwok \
	create-ingress-routes 

down: \
	delete-cluster

create-kube-prometheus-stack:
	kubectl create -k ./base/kube-prometheus-stack/crd
	kubectl kustomize ./base/kube-prometheus-stack | ./hack/local-registry-with-load-images.sh
	kubectl create -k ./base/kube-prometheus-stack

create-kube-apiserver-audit-exporter:
	kubectl kustomize ./base/kube-apiserver-audit-exporter | ./hack/local-registry-with-load-images.sh
	kubectl create -k ./base/kube-apiserver-audit-exporter

create-kwok:
	kubectl create -k ./base/kwok/crd
	kubectl kustomize ./base/kwok | ./hack/local-registry-with-load-images.sh
	kubectl create -k ./base/kwok

create-ingress:
	kubectl kustomize ./base/ingress | ./hack/local-registry-with-load-images.sh
	kubectl create -k ./base/ingress

create-ingress-routes:
	kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=360s
	sleep 1
	kubectl create -k ./base/routes

create-cluster:
	cat kind.yaml | ./hack/local-registry-with-load-images.sh
	./hack/kind-with-local-registry.sh 

delete-cluster:
	kind delete cluster
	docker kill kind-registry
	docker rm kind-registry
	-mv ./logs/kube-apiserver-audit.log ./logs/kube-apiserver-audit.$(shell date +%s).log

create-coscheduling:
	kubectl kustomize ./schedulers/coscheduling | ./hack/local-registry-with-load-images.sh
	kubectl create -k ./schedulers/coscheduling

delete-coscheduling:
	kubectl delete -k ./schedulers/coscheduling

create-kueue:
	kubectl kustomize ./schedulers/kueue | ./hack/local-registry-with-load-images.sh
	kubectl create -k ./schedulers/kueue
	kubectl wait --namespace kueue-system \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=360s

delete-kueue:
	kubectl delete -k ./schedulers/kueue

test-kueue:
	go clean -testcache
	go test -timeout 300s ./test/kueue -v

create-volcano:
	kubectl kustomize ./schedulers/volcano | ./hack/local-registry-with-load-images.sh
	kubectl create -k ./schedulers/volcano

delete-volcano:
	kubectl delete -k ./schedulers/volcano

test-volcano:
	go clean -testcache
	go test -timeout 300s ./test/volcano -v

create-yunikorn:
	kubectl kustomize ./schedulers/yunikorn | ./hack/local-registry-with-load-images.sh
	kubectl create -k ./schedulers/yunikorn

delete-yunikorn:
	kubectl delete -k ./schedulers/yunikorn

test-yunikorn:
	go clean -testcache
	go test -timeout 300s ./test/yunikorn -v

cleanup:
	rm -rf ./logs/
