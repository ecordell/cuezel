package manifests

IngressNamespace: #Namespace & {
	metadata: {
		name: "ingress-nginx"
		labels: {
			"app.kubernetes.io/name":     "ingress-nginx"
			"app.kubernetes.io/instance": "ingress-nginx"
		}
	}
}

IngressServiceAccount: {
	apiVersion: "v1"
	kind:       "ServiceAccount"
	metadata: {
		labels: {
			"helm.sh/chart":               "ingress-nginx-3.10.1"
			"app.kubernetes.io/name":      "ingress-nginx"
			"app.kubernetes.io/instance":  "ingress-nginx"
			"app.kubernetes.io/version":   "0.41.2"
			"app.kubernetes.io/component": "controller"
		}
		name:      "ingress-nginx"
		namespace: IngressNamespace.metadata.name
	}
}

IngressConfigMap: #ConfigMap & {
	apiVersion: "v1"
	kind:       "ConfigMap"
	metadata: {
		labels: {
			"helm.sh/chart":               "ingress-nginx-3.10.1"
			"app.kubernetes.io/name":      "ingress-nginx"
			"app.kubernetes.io/instance":  "ingress-nginx"
			"app.kubernetes.io/version":   "0.41.2"
			"app.kubernetes.io/component": "controller"
		}
		name:      "ingress-nginx-controller"
		namespace: "ingress-nginx"
	}
}

IngressClusterRole: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRole"
	metadata: {
		labels: {
			"helm.sh/chart":              "ingress-nginx-3.10.1"
			"app.kubernetes.io/name":     "ingress-nginx"
			"app.kubernetes.io/instance": "ingress-nginx"
			"app.kubernetes.io/version":  "0.41.2"
		}
		name: "ingress-nginx"
	}
	rules: [{
		apiGroups: [
			"",
		]
		resources: [
			"configmaps",
			"endpoints",
			"nodes",
			"pods",
			"secrets",
		]
		verbs: [
			"list",
			"watch",
		]
	}, {
		apiGroups: [
			"",
		]
		resources: [
			"nodes",
		]
		verbs: [
			"get",
		]
	}, {
		apiGroups: [
			"",
		]
		resources: [
			"services",
		]
		verbs: [
			"get",
			"list",
			"update",
			"watch",
		]
	}, {
		apiGroups: [
			"extensions",
			"networking.k8s.io",
		] // k8s 1.14+
		resources: [
			"ingresses",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [
			"",
		]
		resources: [
			"events",
		]
		verbs: [
			"create",
			"patch",
		]
	}, {
		apiGroups: [
			"extensions",
			"networking.k8s.io",
		] // k8s 1.14+
		resources: [
			"ingresses/status",
		]
		verbs: [
			"update",
		]
	}, {
		apiGroups: ["networking.k8s.io"] // k8s 1.14+
		resources: [
			"ingressclasses",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}]
}

IngressCRB: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "ClusterRoleBinding"
	metadata: {
		labels: {
			"helm.sh/chart":              "ingress-nginx-3.10.1"
			"app.kubernetes.io/name":     "ingress-nginx"
			"app.kubernetes.io/instance": "ingress-nginx"
			"app.kubernetes.io/version":  "0.41.2"
		}
		name: "ingress-nginx"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "ClusterRole"
		name:     "ingress-nginx"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "ingress-nginx"
		namespace: "ingress-nginx"
	}]
}

IngressRole: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "Role"
	metadata: {
		labels: {
			"helm.sh/chart":               "ingress-nginx-3.10.1"
			"app.kubernetes.io/name":      "ingress-nginx"
			"app.kubernetes.io/instance":  "ingress-nginx"
			"app.kubernetes.io/version":   "0.41.2"
			"app.kubernetes.io/component": "controller"
		}
		name:      "ingress-nginx"
		namespace: "ingress-nginx"
	}
	rules: [{
		apiGroups: [
			"",
		]
		resources: [
			"namespaces",
		]
		verbs: [
			"get",
		]
	}, {
		apiGroups: [
			"",
		]
		resources: [
			"configmaps",
			"pods",
			"secrets",
			"endpoints",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [
			"",
		]
		resources: [
			"services",
		]
		verbs: [
			"get",
			"list",
			"update",
			"watch",
		]
	}, {
		apiGroups: [
			"extensions",
			"networking.k8s.io",
		] // k8s 1.14+
		resources: [
			"ingresses",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [
			"extensions",
			"networking.k8s.io",
		] // k8s 1.14+
		resources: [
			"ingresses/status",
		]
		verbs: [
			"update",
		]
	}, {
		apiGroups: ["networking.k8s.io"] // k8s 1.14+
		resources: [
			"ingressclasses",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
	}, {
		apiGroups: [
			"",
		]
		resources: [
			"configmaps",
		]
		resourceNames: [
			"ingress-controller-leader-nginx",
		]
		verbs: [
			"get",
			"update",
		]
	}, {
		apiGroups: [
			"",
		]
		resources: [
			"configmaps",
		]
		verbs: [
			"create",
		]
	}, {
		apiGroups: [
			"",
		]
		resources: [
			"endpoints",
		]
		verbs: [
			"create",
			"get",
			"update",
		]
	}, {
		apiGroups: [
			"",
		]
		resources: [
			"events",
		]
		verbs: [
			"create",
			"patch",
		]
	}]
}
IngressRoleBinding: {
	apiVersion: "rbac.authorization.k8s.io/v1"
	kind:       "RoleBinding"
	metadata: {
		labels: {
			"helm.sh/chart":               "ingress-nginx-3.10.1"
			"app.kubernetes.io/name":      "ingress-nginx"
			"app.kubernetes.io/instance":  "ingress-nginx"
			"app.kubernetes.io/version":   "0.41.2"
			"app.kubernetes.io/component": "controller"
		}
		name:      "ingress-nginx"
		namespace: "ingress-nginx"
	}
	roleRef: {
		apiGroup: "rbac.authorization.k8s.io"
		kind:     "Role"
		name:     "ingress-nginx"
	}
	subjects: [{
		kind:      "ServiceAccount"
		name:      "ingress-nginx"
		namespace: "ingress-nginx"
	}]
}

IngressControllerService: {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		labels: {
			"helm.sh/chart":               "ingress-nginx-3.10.1"
			"app.kubernetes.io/name":      "ingress-nginx"
			"app.kubernetes.io/instance":  "ingress-nginx"
			"app.kubernetes.io/version":   "0.41.2"
			"app.kubernetes.io/component": "controller"
		}
		name:      "ingress-nginx-controller"
		namespace: "ingress-nginx"
	}
	spec: {
		type: "NodePort"
		ports: [{
			name:       "http"
			port:       80
			protocol:   "TCP"
			targetPort: "http"
		}, {
			name:       "https"
			port:       443
			protocol:   "TCP"
			targetPort: "https"
		}]
		selector: {
			"app.kubernetes.io/name":      "ingress-nginx"
			"app.kubernetes.io/instance":  "ingress-nginx"
			"app.kubernetes.io/component": "controller"
		}
	}
}

IngressControllerDeployment: {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	metadata: {
		labels: {
			"helm.sh/chart":               "ingress-nginx-3.10.1"
			"app.kubernetes.io/name":      "ingress-nginx"
			"app.kubernetes.io/instance":  "ingress-nginx"
			"app.kubernetes.io/version":   "0.41.2"
			"app.kubernetes.io/component": "controller"
		}
		name:      "ingress-nginx-controller"
		namespace: "ingress-nginx"
	}
	spec: {
		selector: matchLabels: {
			"app.kubernetes.io/name":      "ingress-nginx"
			"app.kubernetes.io/instance":  "ingress-nginx"
			"app.kubernetes.io/component": "controller"
		}
		revisionHistoryLimit: 10
		strategy: {
			rollingUpdate: maxUnavailable: 1
			type: "RollingUpdate"
		}
		minReadySeconds: 0
		template: {
			metadata: labels: {
				"app.kubernetes.io/name":      "ingress-nginx"
				"app.kubernetes.io/instance":  "ingress-nginx"
				"app.kubernetes.io/component": "controller"
			}
			spec: {
				dnsPolicy: "ClusterFirst"
				containers: [{
					name:            "controller"
					image:           "k8s.gcr.io/ingress-nginx/controller:v0.41.2@sha256:1f4f402b9c14f3ae92b11ada1dfe9893a88f0faeb0b2f4b903e2c67a0c3bf0de"
					imagePullPolicy: "IfNotPresent"
					lifecycle: preStop: exec: command: [
						"/wait-shutdown",
					]
					args: [
						"/nginx-ingress-controller",
						"--election-id=ingress-controller-leader",
						"--ingress-class=nginx",
						"--configmap=$(POD_NAMESPACE)/ingress-nginx-controller",
						"--publish-status-address=localhost",
						"--v=3",
					]
					securityContext: {
						capabilities: {
							drop: [
								"ALL",
							]
							add: [
								"NET_BIND_SERVICE",
							]
						}
						runAsUser:                101
						allowPrivilegeEscalation: true
					}
					env: [{
						name: "POD_NAME"
						valueFrom: fieldRef: fieldPath: "metadata.name"
					}, {
						name: "POD_NAMESPACE"
						valueFrom: fieldRef: fieldPath: "metadata.namespace"
					}, {
						name:  "LD_PRELOAD"
						value: "/usr/local/lib/libmimalloc.so"
					}]
					livenessProbe: {
						httpGet: {
							path:   "/healthz"
							port:   10254
							scheme: "HTTP"
						}
						initialDelaySeconds: 10
						periodSeconds:       10
						timeoutSeconds:      1
						successThreshold:    1
						failureThreshold:    5
					}
					readinessProbe: {
						httpGet: {
							path:   "/healthz"
							port:   10254
							scheme: "HTTP"
						}
						initialDelaySeconds: 10
						periodSeconds:       10
						timeoutSeconds:      1
						successThreshold:    1
						failureThreshold:    3
					}
					ports: [{
						name:          "http"
						containerPort: 80
						protocol:      "TCP"
						hostPort:      80
					}, {
						name:          "https"
						containerPort: 443
						protocol:      "TCP"
						hostPort:      443
					}]
					resources: requests: {
						cpu:    "100m"
						memory: "90Mi"
					}
				}]
				nodeSelector: {
					"kubernetes.io/os": "linux"
				}
				serviceAccountName:            "ingress-nginx"
				terminationGracePeriodSeconds: 0
			}
		}
	}
}

