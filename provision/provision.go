package provision

import (
	"context"
	"fmt"
	"io"
	"os"
	"sync"
	"time"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/load"
	"k8s.io/apimachinery/pkg/util/rand"
	"sigs.k8s.io/kind/pkg/cluster"
	"sigs.k8s.io/kind/pkg/cluster/nodeutils"
	"sigs.k8s.io/kind/pkg/cmd"
)

type KindCluster struct {
	Name           string   `json:"name"`
	Archives       []string `json:"imageArchives"`
	KubeConfigPath string   `json:"kubeconfigPath"`
	RawConfig      string   `json:"rawConfig"`
}

func Provision(ctx context.Context, out io.Writer, r cue.Runtime, instance *cue.Instance, defaultKubeConfig string) (func(), *cue.Instance, error) {
	// load schema for image definitions
	sis := load.Instances([]string{"."}, &load.Config{
		Dir: "./manifests/kind",
	})
	if len(sis) > 1 {
		return nil, instance, fmt.Errorf("multiple instance loading currently not supported")
	}
	if len(sis) < 1 {
		return nil, instance, fmt.Errorf("no instances found")
	}
	si, err := r.Build(sis[0])
	if err != nil {
		return nil, instance, err
	}
	clusterSchema := si.Value().LookupDef("KindCluster")

	// find all cluster definitions
	clusterDefs := make([]cue.Value, 0)
	itr, err := instance.Value().Fields(cue.Definitions(true))
	if err != nil {
		return nil, instance, err
	}
	for itr.Next() {
		val := itr.Value()
		if err := val.Unify(clusterSchema).Validate(); err == nil {
			fmt.Fprintf(out, "found cluster definition: %s\n", val.Path())
			clusterDefs = append(clusterDefs, val)
		} else {
			// TODO: debug logs
			//fmt.Println(itr.Label(), err)
		}
	}
	provider := cluster.NewProvider(
		cluster.ProviderWithLogger(cmd.NewLogger()),
	)

	clusters := make([]KindCluster, 0)

	var once sync.Once
	deprovision := func() {
		once.Do(func() {
			for _, c := range clusters {
				if err := provider.Delete(c.Name, c.KubeConfigPath); err != nil {
					fmt.Println(err)
				}
			}
		})
	}

	for _, def := range clusterDefs {
		var clusterSpec KindCluster

		if err := def.Decode(&clusterSpec); err != nil {
			return nil, instance, err
		}
		if clusterSpec.Name == "" {
			clusterSpec.Name = fmt.Sprintf("kind-%s", rand.String(16))
		}
		if clusterSpec.KubeConfigPath == "" {
			clusterSpec.KubeConfigPath = defaultKubeConfig
		}

		var existing []string
		existing, err = provider.List()
		if err != nil {
			return deprovision, nil, err
		}

		needsCluster := true
		for _, c := range existing {
			if c == clusterSpec.Name {
				needsCluster = false
			}
		}

		if needsCluster {
			err = provider.Create(
				clusterSpec.Name,
				cluster.CreateWithWaitForReady(5*time.Minute),
				cluster.CreateWithKubeconfigPath(clusterSpec.KubeConfigPath),
				cluster.CreateWithRawConfig([]byte(clusterSpec.RawConfig)),
			)
			if err != nil {
				err = fmt.Errorf("failed to create kind cluster: %s", err.Error())
				return deprovision, nil, err
			}
		}

		nodes, err := provider.ListNodes(clusterSpec.Name)
		if err != nil {
			return deprovision, nil, fmt.Errorf("failed to list kind nodes: %s", err.Error())
		}

		for _, archive := range clusterSpec.Archives {
			fmt.Printf("loading %s onto nodes\n", archive)
			for _, node := range nodes {
				fd, err := os.Open(archive)
				if err != nil {
					return deprovision, nil, fmt.Errorf("error opening archive %q: %s", archive, err.Error())
				}
				err = nodeutils.LoadImageArchive(node, fd)
				if err != nil {
					return deprovision, nil, fmt.Errorf("error loading image archive %q to node %q: %s", archive, node, err.Error())
				}
				if err := fd.Close(); err != nil {
					return deprovision, nil, fmt.Errorf("error loading image archive %q to node %q: %s", archive, node, err.Error())
				}
			}
		}
		fmt.Println("Filling instance", def.Path().String())
		instance, err = instance.Fill(&clusterSpec, def.Path().String())
		if err != nil {
			return nil, instance, err
		}
		clusters = append(clusters, clusterSpec)
	}

	return deprovision, instance, nil
}
