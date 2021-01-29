GO := GO111MODULE=on GOFLAGS="-mod=vendor" go
GINKGO := $(GO) run github.com/onsi/ginkgo/ginkgo

.PHONY: e2e
e2e: dyncr.image.tar
	$(GINKGO) -nodes $(or $(NODES),1) -flakeAttempts 3 -randomizeAllSpecs $(if $(TEST),-focus "$(TEST)") -v -timeout 90m test -- --kind.image=../dyncr.image.tar

bin/dyncr: FORCE
	$(GO) build -o $@ ./cmd/dyncr

.PHONY: provision
provision: bin/dyncr
	$(GO) run ./cmd/cuezel --cleanup-cluster=false

.PHONY: apply
apply: bin/dyncr
	$(eval NAME=$(shell kind get clusters | head -1))
	$(GO) run ./cmd/cuezel --kind.name=$(NAME) --cleanup-cluster=false

.PHONY: FORCE
FORCE: