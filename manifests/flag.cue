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
            "nginx.ingress.kubernetes.io/auth-url": "https://$host/auth/verify"
            "nginx.ingress.kubernetes.io/auth-signin": "https://$host/auth/signin?rd=$escaped_request_uri"
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

OidcNamespace: #Namespace & {
	metadata: {
		generateName: "oidc-proxy"
		...
	}
}

OidcProxy: #Deployment & {
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
					    value: "SETME"
					},
                    {
                        name: "CLIENT_ID"
                        value: "SETME"
                    },
                    {
                        name: "CLIENT_SECRET"
                        value: "SETME"
                    }
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