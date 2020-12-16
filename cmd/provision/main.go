package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/cuebernetes/cuebectl/pkg/apply"
	flag "github.com/spf13/pflag"
	"k8s.io/cli-runtime/pkg/genericclioptions"
	"k8s.io/client-go/dynamic"
	cmdutil "k8s.io/kubectl/pkg/cmd/util"

	"github.com/ecordell/dyncr/provision"
)

var images = flag.StringArray("kind.image", []string{}, "image archives to load on cluster nodes")

func main() {
	flags := genericclioptions.NewConfigFlags(true)
	// TODO: klog, kubeconfig
	//globalflag.AddGlobalFlags(flag.CommandLine, "provisioner")
	flag.Parse()

	f := cmdutil.NewFactory(flags)

	kubeconfig := f.ToRawKubeConfigLoader().ConfigAccess().GetExplicitFile()
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM, syscall.SIGKILL, syscall.SIGSTOP)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	deprovision, err := provision.Provision(kubeconfig, *images)
	defer func() {
		if deprovision != nil {
			deprovision()
		}
	}()
	if err != nil {
		log.Fatalf("couldn't provision a kind cluster: %v", err)
	}

	go func() {
		restConfig, err := f.ToRESTConfig()
		if err != nil {
			log.Fatal(err)
		}

		k, err := dynamic.NewForConfig(restConfig)
		if err != nil {
			log.Fatal(err)
		}

		mapper, err := f.ToRESTMapper()
		if err != nil {
			log.Fatal(err)
		}

		if err := apply.CueDir(ctx, os.Stdout, k, mapper, "./manifests", false); err != nil {
			log.Fatalf("couldn't configure cluster: %v", err)
		} else {
			fmt.Println("finished configuring cluster")
		}
	}()

	<-c
	fmt.Println("deleting cluster")
}
