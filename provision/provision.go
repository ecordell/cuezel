package provision

import (
	"fmt"
	"io/ioutil"
	"os"
	"sigs.k8s.io/kind/pkg/cluster/nodeutils"
	"sync"
	"time"

	"k8s.io/apimachinery/pkg/util/rand"
	"sigs.k8s.io/kind/pkg/cluster"
	"sigs.k8s.io/kind/pkg/cmd"
)


func Provision(name, kubeconfig string, images []string) (deprovision func(), err error) {
	if name == "" {
		name = fmt.Sprintf("kind-%s", rand.String(16))
	}
	dir, err := ioutil.TempDir("", name)
	if err != nil {
		err = fmt.Errorf("failed to create temporary directory: %s", err.Error())
		return
	}

	provider := cluster.NewProvider(
		cluster.ProviderWithLogger(cmd.NewLogger()),
	)

	var once sync.Once
	deprovision = func() {
		once.Do(func() {
			os.RemoveAll(dir)
			if err := provider.Delete(name, kubeconfig); err != nil {
				fmt.Println(err)
			}
		})
	}

	var clusters []string
	clusters, err = provider.List()

	needsCluster := true
	for _, c := range clusters {
		if c == name {
			needsCluster = false
		}
	}

	if needsCluster {
		err = provider.Create(
			name,
			cluster.CreateWithWaitForReady(5*time.Minute),
			cluster.CreateWithKubeconfigPath(kubeconfig),
			cluster.CreateWithRawConfig([]byte(`
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
`)),
		)
		if err != nil {
			err = fmt.Errorf("failed to create kind cluster: %s", err.Error())
			return
		}
	}

	nodes, err := provider.ListNodes(name)
	if err != nil {
		return nil, fmt.Errorf("failed to list kind nodes: %s", err.Error())
	}

	for _, archive := range images {
		fmt.Printf("loading %s onto nodes\n", archive)
		for _, node := range nodes {
			fd, err := os.Open(archive)
			if err != nil {
				return nil, fmt.Errorf("error opening archive %q: %s", archive, err.Error())
			}
			err = nodeutils.LoadImageArchive(node, fd)
			fd.Close()
			if err != nil {
				return nil, fmt.Errorf("error loading image archive %q to node %q: %s", archive, node, err.Error())
			}
		}
	}

	return deprovision, nil
}
