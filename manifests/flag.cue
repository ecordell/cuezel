package manifests

FlagNamespace: #Namespace & {
	metadata: {
		generateName: "flag-"
		...
	}
}

FlagDeployment: #Deployment & {
	metadata: {
		name:      "theflag"
		namespace: FlagNamespace.metadata.name
		labels: "app.kubernetes.io/name": "theflag"
	}
	spec: {
		replicas: 1
		selector: matchLabels: "app.kubernetes.io/name": "theflag"
		template: {
			metadata: labels: "app.kubernetes.io/name": "theflag"
			spec: containers: [{
				name:            "theflag"
				image:           "quay.io/ecordell/flag"
				imagePullPolicy: "IfNotPresent"
				ports: [{
					name:          "http-public"
					containerPort: 8080
					protocol:      "TCP"
				}]
			}]
		}
	}
}

FlagService: #Service & {
	metadata: {
		name:      "flag-service"
		namespace: FlagNamespace.metadata.name
	}
	spec: {
		selector: "app.kubernetes.io/name": "theflag"
		ports: [ {port: 8080}]
	}
}

FlagIngress: {
	apiVersion: "networking.k8s.io/v1"
	kind:       "Ingress"
	metadata: {
		name:      "flag-ingress"
		namespace: FlagNamespace.metadata.name
		annotations: {
            "nginx.ingress.kubernetes.io/auth-url": "http://$host/auth/verify"
            "nginx.ingress.kubernetes.io/auth-signin": "http://$host/auth/signin"
        }
	}
	spec: rules: [{
		http: paths: [
        {
			path: "/"
			pathType: "Prefix"
			backend: {
				service: {
            		name: "flag-service"
            		port: "number": 8080
				}
			}
		}
		]
	}]
}

FaviconIngress: {
	apiVersion: "networking.k8s.io/v1"
	kind:       "Ingress"
	metadata: {
		name:      "favicon-ingress"
		namespace: FlagNamespace.metadata.name
	}
	spec: rules: [{
		http: paths: [
        {
			path: "/favicon.ico"
			pathType: "Prefix"
			backend: {
				service: {
            		name: "flag-service"
            		port: "number": 8080
				}
			}
		}
		]
	}]
}

OidcNamespace: #Namespace & {
	metadata: {
		generateName: "oidc-proxy"
		...
	}
}

#HydraReady: {
    if len([ for c in HydraDeployment.status.conditions if c.type == "Available" && c.status =="True" {c} ]) > 0 {
        ready: true
    }
}

OidcProxy: #Deployment & {
    _wait: !#HydraReady.ready

	metadata: {
		name:      "oidc-ingress"
		namespace: OidcNamespace.metadata.name
		labels: "app.kubernetes.io/name": "oidc-ingress"
	}
	spec: {
		replicas: 1
		selector: matchLabels: "app.kubernetes.io/name": "oidc-ingress"
		template: {
			metadata: labels: "app.kubernetes.io/name": "oidc-ingress"
			spec: hostAliases: [{
		      ip: IngressControllerService.spec.clusterIP,
              hostnames: ["dyncr.localhost"]
			}]
			spec: containers: [{
				name:            "oidc-ingress"
				image:           "quay.io/ecordell/dyncr:local"
				imagePullPolicy: "IfNotPresent"
				ports: [{
					name:          "http-public"
					containerPort: 8000
					protocol:      "TCP"
				}]
				env: [
				    {
					    name: "PROVIDER"
					    value: "http://dyncr.localhost/hydra/"
					},
					{
					    name: "REGISTRATION_URI"
					    value: "http://\(AdminService.metadata.name).\(AdminService.metadata.namespace).svc.cluster.local:\(AdminService.spec.ports[0].port)/clients"
					},
					{
					    name: "REDIRECT_URI",
					    value: "http://dyncr.localhost/auth/callback"
					},
					{
					    name: "LOGIN_URL"
					    value: "http://dyncr.localhost/login"
					},
				]
			}]
		}
	}
}

OidcService: #Service & {
	metadata: {
		name:      "oidc-service"
		namespace: OidcNamespace.metadata.name
	}
	spec: {
		selector: "app.kubernetes.io/name": "oidc-ingress"
		ports: [ {port: 8000}]
	}
}

OidcIngress: {
	apiVersion: "networking.k8s.io/v1"
	kind:       "Ingress"
	metadata: {
		name:      "oidc-ingress"
		namespace: OidcNamespace.metadata.name
	}
	spec: rules: [{
		http: paths: [
		{
            path: "/auth"
            pathType: "Prefix"
            backend: {
                service: {
                    name: "oidc-service"
                    port: "number": 8000
                }
            }
		}
		]
	}]
}

CoreDNSConfigMap: {
apiVersion: "v1"
kind: "ConfigMap"
metadata: name: "coredns"
metadata: namespace: "kube-system"
data:
  Corefile: """
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        rewrite {
           name regex dyncr.localhost ingress-nginx-controller.ingress-nginx.svc.cluster.local
           answer name ingress-nginx-controller.ingress-nginx.svc.cluster.local dyncr.localhost
        }
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
  """
}

#OidcReady: {
    if len([ for c in OidcProxy.status.conditions if c.type == "Available" && c.status =="True" {c} ]) > 0 {
        ready: true
    }
}

ReadyConfigMap: {
    apiVersion: "v1"
    kind: "ConfigMap"
    metadata: name: "ready"
    metadata: namespace: FlagNamespace.metadata.name
    _wait: !#OidcReady.ready
}
