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
		  admin:
			port: 4445
		  public:
			port: 4444
		  tls:
			allow_termination_from:
			- 10.0.0.0/8
			- 172.16.0.0/12
			- 192.168.0.0/16
		urls:
			self: {}
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
						value: "http://127.0.0.1:4444/"
					}, {
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
					}]
					resources: {}
				}]
			}
		}
	}
}
