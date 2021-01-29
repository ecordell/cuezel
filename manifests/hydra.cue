package manifests

import (
	corev1 "k8s.io/api/core/v1"
	appsv1 "k8s.io/api/apps/v1"
)

// imported schemas don't specify kind/apiversion
#Namespace: corev1.#Namespace & {
	apiVersion: "v1"
	kind:       "Namespace"
	...
}

#ConfigMap: corev1.#ConfigMap & {
	apiVersion: "v1"
	kind:       "ConfigMap"
	...
}

// not using kube secret def, conflicts byte and string
#Secret: {
	apiVersion: "v1"
	kind:       "Secret"
	...
}

#Service: corev1.#Service & {
	apiVersion: "v1"
	kind:       "Service"
	...
}

#Deployment: appsv1.#Deployment & {
	apiVersion: "apps/v1"
	kind:       "Deployment"
	...
}

HydraNamespace: #Namespace & {
	metadata: {
		generateName: "hydra-"
		...
	}
}

HydraConfig: #ConfigMap & {
	metadata: {
		name:      "hydra"
		namespace: HydraNamespace.metadata.name
		labels: {
			"app.kubernetes.io/name":     "hydra"
			"app.kubernetes.io/instance": "hydra"
			"app.kubernetes.io/version":  "v1.8.5"
		}
	}
	data: "config.yaml": """
		serve:
			cookies:
				same_site_mode: Lax:
			admin:
				port: 4445
		  	public:
				port: 4444
			tls:
				allow_termination_from:
				- 10.0.0.0/8
				- 172.16.0.0/12
				- 192.168.0.0/16
		"""
}

Secrets: #Secret & {
	metadata: {
		name:      "hydra"
		namespace: HydraNamespace.metadata.name
		labels: {
			"app.kubernetes.io/name":     "hydra"
			"app.kubernetes.io/instance": "hydra"
			"app.kubernetes.io/version":  "v1.8.5"
		}
	}
	type: "Opaque"
	data: {
		secretsSystem: "WEVJU0ZtQmc0elRhQjN6ZldvRExqSGVJWUF0UWc1YUE="
		secretsCookie: "OVdKRTFTRHFMS3J5U0ljUmYzZlREMkxVVjJXb2w0Tjg="
		dsn:           "bWVtb3J5Cg=="
	}
}

AdminService: #Service & {
	metadata: {
		name:      "hydra-admin"
		namespace: HydraNamespace.metadata.name
		labels: {
			"app.kubernetes.io/name":     "hydra"
			"app.kubernetes.io/instance": "hydra"
			"app.kubernetes.io/version":  "v1.8.5"
		}
	}
	spec: {
		type: "ClusterIP"
		ports: [{
			port:       4445
			targetPort: "http-admin"
			protocol:   "TCP"
			name:       "http"
		}]
		selector: {
			"app.kubernetes.io/name":     "hydra"
			"app.kubernetes.io/instance": "hydra"
		}
	}
}

PublicService: #Service & {
	metadata: {
		name:      "hydra-public"
		namespace: HydraNamespace.metadata.name
		labels: {
			"app.kubernetes.io/name":     "hydra"
			"app.kubernetes.io/instance": "hydra"
			"app.kubernetes.io/version":  "v1.8.5"
		}
	}
	spec: {
		type: "ClusterIP"
		ports: [{
			port:       4444
			targetPort: "http-public"
			protocol:   "TCP"
			name:       "http"
		}]
		selector: {
			"app.kubernetes.io/name":     "hydra"
			"app.kubernetes.io/instance": "hydra"
		}
	}
}

HydraDeployment: #Deployment & {
	metadata: {
		name:      "hydra"
		namespace: HydraNamespace.metadata.name
		labels: {
			"app.kubernetes.io/name":     "hydra"
			"app.kubernetes.io/instance": "hydra"
			"app.kubernetes.io/version":  "v1.8.5"
		}
	}
	spec: {
		replicas: 1
		selector: matchLabels: {
			"app.kubernetes.io/name":     "hydra"
			"app.kubernetes.io/instance": "hydra"
		}
		template: {
			metadata: {
				labels: {
					"app.kubernetes.io/name":     "hydra"
					"app.kubernetes.io/instance": "hydra"
					"app.kubernetes.io/version":  "v1.8.5"
				}
			}
			spec: {
				volumes: [{
					name: "hydra-config-volume"
					configMap: name: "hydra"
				}]
				containers: [{
					name:            "hydra"
					image:           "oryd/hydra:v1.4.6"
					imagePullPolicy: "IfNotPresent"
					command: ["hydra"]
					volumeMounts: [{
						name:      "hydra-config-volume"
						mountPath: "/etc/config"
						readOnly:  true
					}]
					args: [
						"serve",
						"all",
						"--config",
						"/etc/config/config.yaml",
						"--dangerous-force-http",
					]

					ports: [{
						name:          "http-public"
						containerPort: 4444
						protocol:      "TCP"
					}, {
						name:          "http-admin"
						containerPort: 4445
						protocol:      "TCP"
					}]
					livenessProbe: {
						httpGet: {
							path: "/health/alive"
							port: "http-admin"
						}
						initialDelaySeconds: 30
						periodSeconds:       10
						failureThreshold:    5
					}
					readinessProbe: {
						httpGet: {
							path: "/health/ready"
							port: "http-admin"
						}
						initialDelaySeconds: 30
						periodSeconds:       10
						failureThreshold:    5
					}
					env: [{
						name:  "URLS_SELF_ISSUER"
						value: "http://dyncr.localhost/hydra"
					}, {
                        name:  "URLS_SELF_PUBLIC"
                        value: "http://dyncr.localhost/hydra"
                    },
                    {
                        name: "URLS_LOGIN"
                        value: "http://dyncr.localhost/login"
                    },
                    {
                        name: "URLS_CONSENT"
                        value: "http://dyncr.localhost/consent"
                    },
                    {
                        name: "URLS_LOGOUT"
                        value: "http://dyncr.localhost/logout"
                    },
                    {
						name:  "DSN"
						value: "memory"
					}, {
						name: "SECRETS_SYSTEM"
						valueFrom: secretKeyRef: {
							name: "hydra"
							key:  "secretsSystem"
						}
					}, {
						name: "SECRETS_COOKIE"
						valueFrom: secretKeyRef: {
							name: "hydra"
							key:  "secretsCookie"
						}
					},{
					    name: "LOG_LEVEL"
					    value: "debug"
					},{
					    name: "SERVE_COOKIES_SAME_SITE_MODE"
					    value: "Lax"
					}]
					resources: {}
				}]
			}
		}
	}
}

HydraIngress: {
	apiVersion: "networking.k8s.io/v1"
	kind:       "Ingress"
	metadata: {
		name:      "hydra-ingress"
		namespace: HydraNamespace.metadata.name
		annotations:  "nginx.ingress.kubernetes.io/rewrite-target": "/$1"
	}
	spec: rules: [{
		http: paths: [
		{
            path: "/hydra/(.*)"
            pathType: "Prefix"
            backend: {
                service: {
                    name: "hydra-public"
                    port: "number": PublicService.spec.ports[0].port
                }
            }
		},
		{
			path: "/admin/(.*)"
			pathType: "Prefix"
			backend: {
				service: {
					name: "hydra-admin"
					port: "number": AdminService.spec.ports[0].port
				}
			}
        }
		]
	}]
}

HydraLoginDepoyment: #Deployment & {
    metadata: {
        name:      "hydra-login"
        namespace: HydraNamespace.metadata.name
        labels: {
            "app.kubernetes.io/name":     "hydralogin"
            "app.kubernetes.io/instance": "hydralogin"
            "app.kubernetes.io/version":  "v1.9.0"
        }
    }
    spec: {
        replicas: 1
        selector: matchLabels: {
            "app.kubernetes.io/name":     "hydralogin"
            "app.kubernetes.io/instance": "hydralogin"
        }
        template: {
            metadata: {
                labels: {
                    "app.kubernetes.io/name":     "hydralogin"
                    "app.kubernetes.io/instance": "hydralogin"
                    "app.kubernetes.io/version":  "v1.9.0"
                }
            }
            spec: {
                containers: [{
                    name:            "hydra-login"
                    image:           "oryd/hydra-login-consent-node:v1.9.0-alpha.3"
                    imagePullPolicy: "IfNotPresent"
                    ports: [{
                        name:          "http"
                        containerPort: 3000
                        protocol:      "TCP"
                    }]
                    env: [{
                       name:  "HYDRA_ADMIN_URL"
                       value: "http://dyncr.localhost/admin"
                    }]
                    resources: {}
                }]
            }
        }
    }
 }


LoginService: #Service & {
	metadata: {
		name:      "hydra-login"
		namespace: HydraNamespace.metadata.name
		labels: {
			"app.kubernetes.io/name":     "hydralogin"
			"app.kubernetes.io/instance": "hydralogin"
			"app.kubernetes.io/version":  "v1.9.0"
		}
	}
	spec: {
		type: "ClusterIP"
		ports: [{
			port:       3000
			targetPort: "http"
			protocol:   "TCP"
			name:       "http"
		}]
		selector: {
			"app.kubernetes.io/name":     "hydralogin"
			"app.kubernetes.io/instance": "hydralogin"
		}
	}
}

HydraLoginIngress: {
	apiVersion: "networking.k8s.io/v1"
	kind:       "Ingress"
	metadata: {
		name:      "login-ingress"
		namespace: HydraNamespace.metadata.name
	}
	spec: rules: [{
		http: paths: [
		{
            path: "/login"
            pathType: "Prefix"
            backend: {
                service: {
                    name: "hydra-login"
                    port: "number": LoginService.spec.ports[0].port
                }
            }
		},
        {
            path: "/consent"
            pathType: "Prefix"
            backend: {
                service: {
                    name: "hydra-login"
                    port: "number": LoginService.spec.ports[0].port
                }
            }
        },
        {
            path: "/logout"
            pathType: "Prefix"
            backend: {
                service: {
                    name: "hydra-login"
                    port: "number": LoginService.spec.ports[0].port
                }
            }
        }
		]
	}]
}
