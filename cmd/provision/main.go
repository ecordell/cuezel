package main

import (
	"context"
	"fmt"
	"github.com/cuebernetes/cuebectl/pkg/controller"
	cuedelete "github.com/cuebernetes/cuebectl/pkg/delete"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"log"
	"os"
	"os/signal"
	"syscall"
	//"time"

	"github.com/cuebernetes/cuebectl/pkg/apply"
	flag "github.com/spf13/pflag"
	"k8s.io/cli-runtime/pkg/genericclioptions"
	"k8s.io/client-go/dynamic"
	cmdutil "k8s.io/kubectl/pkg/cmd/util"
	//"github.com/bep/debounce"
	//"github.com/txn2/kubefwd/pkg/fwdcfg"
	//"github.com/txn2/kubefwd/pkg/fwdhost"
	//"github.com/txn2/kubefwd/pkg/fwdport"
	//"github.com/txn2/kubefwd/pkg/fwdservice"
	//"kubefwd/cmd/kubefwd/services"
	//"github.com/txn2/kubefwd/pkg/fwdsvcregistry"
	//"github.com/txn2/kubefwd/pkg/utils"
	//"github.com/txn2/txeh"

	"github.com/ecordell/dyncr/provision"
)

var images = flag.StringArray("kind.image", []string{}, "image archives to load on cluster nodes")
var name = flag.String("kind.name", "", "name of an existing kind cluster")
var cleanup = flag.Bool("cleanup", true, "if true, cleans up resources when process is killed")
var cleanupCluster = flag.Bool("cleanup-cluster", true, "if true, cleans up cluster when process is killed")

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

	deprovision, err := provision.Provision(*name, kubeconfig, *images)
	defer func() {
		if deprovision != nil && *cleanupCluster {
			deprovision()
		}
	}()
	if err != nil {
		log.Fatalf("couldn't provision a kind cluster: %v", err)
	}

	restConfig, err := f.ToRESTConfig()
	if err != nil {
		log.Fatal(err)
	}

	k, err := dynamic.NewForConfig(restConfig)
	if err != nil {
		log.Fatal(err)
	}

	var state *controller.ClusterState
	go func() {
		mapper, err := f.ToRESTMapper()
		if err != nil {
			log.Fatal(err)
		}

		if state, err = apply.CueDir(ctx, os.Stdout, k, mapper, "./manifests", false); err != nil {
			log.Fatalf("couldn't configure cluster: %v", err)
		} else {
			fmt.Println("finished configuring cluster")
		}
	}()



	// TODO: switch to a continuous watch on CUE to drive kubefwd
	//
	//// reqs for kubefwd
	//hasRoot, err := utils.CheckRoot()
	//if !hasRoot || err != nil {
	//	log.Fatal(err)
	//}
	//hostFile, err := txeh.NewHostsDefault()
	//if err != nil {
	//	log.Fatalf("HostFile error: %v\n", err)
	//}
	//_, err = fwdhost.BackupHostFile(hostFile)
	//if err != nil {
	//	log.Fatalf("Error backing up hostfile: %v\n", err)
	//}
	//go func() {
	//	state := <-final
	//
	//
	//	for id, obj := range state {
	//		if id.GroupResource() == "services" {
	//
	//		}
	//	}
	//	fwdsvcregistry.Init(ctx.Done())
	//
	//	clientset, err := f.KubernetesClientSet()
	//	if err != nil {
	//		log.Fatal("couldn't get clientset")
	//	}
	//	clientConfig, err := f.ToRESTConfig()
	//	if err != nil {
	//		log.Fatal("couldn't get restconfig")
	//	}
	//	restClient, err := f.RESTClient()
	//	if err != nil {
	//		log.Fatal("couldn't get rest client")
	//	}
	//	svcfwd := &fwdservice.ServiceFWD{
	//		ClientSet:            *clientset,
	//		Context:              *name,
	//		Namespace:            opts.Namespace,
	//		Hostfile:             hostFile,
	//		ClientConfig:         *clientConfig,
	//		RESTClient:           restClient,
	//		NamespaceN:           opts.NamespaceN,
	//		ClusterN:             opts.ClusterN,
	//		Domain:               opts.Domain,
	//		PodLabelSelector:     selector,
	//		NamespaceServiceLock: opts.NamespaceIPLock,
	//		Svc:                  svc,
	//		Headless:             svc.Spec.ClusterIP == "None",
	//		PortForwards:         make(map[string]*fwdport.PortForwardOpts),
	//		SyncDebouncer:        debounce.New(5 * time.Second),
	//		DoneChannel:          make(chan struct{}),
	//	}
	//	fwdsvcregistry.Add(svcfwd)
	//}()
	<-c

	if *cleanup && state != nil {
		fmt.Println("cleaning up")
		if err := cuedelete.All(ctx, os.Stdout, k, state.Locators(), v1.DeleteOptions{}); err != nil {
			log.Fatal(err)
		}
	}
}
