package schema

import (
  configv1alpha4 "sigs.k8s.io/kind/pkg/apis/config/v1alpha4"
)

#KindCluster: {
    provisioner: "kind"
    name?: string
    imageArchives?: [...string]
    kubeconfig?: string
    config?: configv1alpha4.#Cluster
    rawConfig?: string
}