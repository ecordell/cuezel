package test

import (
	"context"
	"flag"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/cuebernetes/cuebectl/pkg/apply"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	//flag "github.com/spf13/pflag"
	"k8s.io/cli-runtime/pkg/genericclioptions"
	"k8s.io/client-go/dynamic"
	cmdutil "k8s.io/kubectl/pkg/cmd/util"

	"github.com/ecordell/dyncr/provision"
)

var (
	deprovision = func() {}
	k           dynamic.Interface
)
var images = flag.String("kind.image", "", "image archive to load on cluster nodes")

func TestEndToEnd(t *testing.T) {
	RegisterFailHandler(Fail)
	SetDefaultEventuallyTimeout(1 * time.Minute)
	SetDefaultEventuallyPollingInterval(1 * time.Second)
	RunSpecs(t, "e2e")
}

var _ = BeforeSuite(func() {
	var err error
	flags := genericclioptions.NewConfigFlags(true)
	f := cmdutil.NewFactory(flags)
	kubeconfig := f.ToRawKubeConfigLoader().ConfigAccess().GetExplicitFile()
	archives := strings.Split(*images, ",")
	deprovision, err = provision.Provision("", kubeconfig, archives)
	Expect(err).ToNot(HaveOccurred())

	k, err = f.DynamicClient()
	Expect(err).To(Succeed())
	restConfig, err := f.ToRESTConfig()
	Expect(err).To(Succeed())

	k, err := dynamic.NewForConfig(restConfig)
	Expect(err).To(Succeed())

	mapper, err := f.ToRESTMapper()
	Expect(err).To(Succeed())
	_, err = apply.CueDir(context.Background(), os.Stdout, k, mapper, "../manifests", false)
	Expect(err).To(Succeed())
})

var _ = AfterSuite(func() {
	if deprovision != nil {
		deprovision()
	}
})
