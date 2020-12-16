GO := GO111MODULE=on GOFLAGS="-mod=vendor" go
GINKGO := $(GO) run github.com/onsi/ginkgo/ginkgo

.PHONY: e2e
e2e: dyncr.image.tar
	$(GINKGO) -nodes $(or $(NODES),1) -flakeAttempts 3 -randomizeAllSpecs $(if $(TEST),-focus "$(TEST)") -v -timeout 90m test -- --kind.image=../dyncr.image.tar

bin/dyncr: FORCE
	$(GO) build -o $@ ./cmd/dyncr

dyncr.image.tar: export GOOS=linux
dyncr.image.tar: export GOARCH=386
dyncr.image.tar: bin/dyncr
	docker build -t quay.io/ecordell/dyncr:local -f Dockerfile bin
	docker save -o $@ quay.io/ecordell/dyncr:local

.PHONY: provision
provision: dyncr.image.tar
	$(GO) run ./cmd/provision --kind.image=dyncr.image.tar

.PHONY: FORCE
FORCE: