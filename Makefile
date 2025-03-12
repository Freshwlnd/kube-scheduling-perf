
up: \
	create-cluster \
	create-ingress \
	create-kube-prometheus-stack \
	create-kube-apiserver-audit-exporter \
	create-kwok \
	create-ingress-routes 

down: \
	delete-cluster \
	cleanup

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
		--timeout=180s
	sleep 1
	kubectl create -k ./base/routes

create-cluster:
	cat kind.yaml | ./hack/local-registry-with-load-images.sh
	./hack/kind-with-local-registry.sh 

delete-cluster:
	kind delete cluster
	docker kill kind-registry
	docker rm kind-registry

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
		--timeout=180s

delete-kueue:
	kubectl delete -k ./schedulers/kueue

test-kueue:
	go test -timeout 300s ./test/kueue -v

create-volcano:
	kubectl kustomize ./schedulers/volcano | ./hack/local-registry-with-load-images.sh
	kubectl create -k ./schedulers/volcano

delete-volcano:
	kubectl delete -k ./schedulers/volcano

test-volcano:
	go test -timeout 300s ./test/volcano -v

create-yunikorn:
	kubectl kustomize ./schedulers/yunikorn | ./hack/local-registry-with-load-images.sh
	kubectl create -k ./schedulers/yunikorn

delete-yunikorn:
	kubectl delete -k ./schedulers/yunikorn

test-yunikorn:
	go test -timeout 300s ./test/yunikorn -v

cleanup:
	rm -rf ./logs/
