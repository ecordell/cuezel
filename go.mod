module github.com/ecordell/dyncr

go 1.15

require (
	cuelang.org/go v0.3.0-beta.3
	github.com/containers/common v0.33.0
	github.com/containers/image/v5 v5.9.0
	github.com/coreos/go-oidc v2.1.0+incompatible
	github.com/cuebernetes/cuebectl v0.4.0
	github.com/elazarl/goproxy v0.0.0-20181111060418-2ce16c963a8a // indirect
	github.com/go-logr/logr v0.3.0 // indirect
	github.com/googleapis/gnostic v0.5.1 // indirect
	github.com/lib/pq v1.2.0 // indirect
	github.com/onsi/ginkgo v1.14.2
	github.com/onsi/gomega v1.10.4
	github.com/opencontainers/image-spec v1.0.2-0.20190823105129-775207bd45b6
	github.com/opencontainers/umoci v0.4.6
	github.com/pkg/errors v0.9.1
	github.com/pquerna/cachecontrol v0.0.0-20171018203845-0dec1b30a021 // indirect
	github.com/spf13/pflag v1.0.5
	golang.org/x/oauth2 v0.0.0-20200107190931-bf48bf16ab8d
	google.golang.org/appengine v1.6.6 // indirect
	k8s.io/apimachinery v0.20.0
	k8s.io/cli-runtime v0.20.0
	k8s.io/client-go v0.20.0
	k8s.io/kubectl v0.20.0
	sigs.k8s.io/kind v0.9.0
)

replace github.com/cuebernetes/cuebectl => ../cuebectl
