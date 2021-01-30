GINKGO := $(GO) run github.com/onsi/ginkgo/ginkgo
GO := GO111MODULE=on GOFLAGS="-mod=vendor" go

.PHONY: e2e
e2e:
	$(GINKGO) -nodes $(or $(NODES),1) -flakeAttempts 3 -randomizeAllSpecs $(if $(TEST),-focus "$(TEST)") -v -timeout 90m test

.PHONY: provision
provision:
	$(GO) run ./cmd/cuezel --cleanup-cluster=false

# TODO: pass existing kind cluster name as a cue value
.PHONY: apply
apply:
	$(eval NAME=$(shell kind get clusters | head -1))
	$(GO) run ./cmd/cuezel --kind.name=$(NAME) --cleanup-cluster=false