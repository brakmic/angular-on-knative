# Angular apps with Knative

This project contains an Angular app + a [Knative](https://knative.dev/) YAML that can be used to deploy services on Kubernetes without dealing with its complexities.

Instead of using a myriad of different YAML files that describe various low-level aspects like Deyploment, Ingress, Service and so on, we use a single YAML file and let Knative do the heavy lifting for us.

### Setup

You will need a running Kubernetes instance like [minikube](https://minikube.sigs.k8s.io/docs/start/), [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) or [Kubernetes on Docker Desktop](https://birthday.play-with-docker.com/kubernetes-docker-desktop/).


After you have setup your preferred K8s it's time to [install Knative](https://knative.dev/docs/install/). Knative itself comprises of two basic blocks: Eventing and Serving. In the past there was a third one, Building, but it got extracted into a project of its own: [Tekton](https://tekton.dev/).

The easiest way to install Knative is via Knative's [quickstart](https://knative.dev/docs/install/quickstart-install/) plugin.

### Running Knative

Test your Knative installation by entering these commands:

`$ kn version`

```shell
Version:      v1.3.1
Build Date:   2022-03-11 18:43:10
Git Revision: a591c0c0
Supported APIs:
* Serving
  - serving.knative.dev/v1 (knative-serving v1.3.0)
* Eventing
  - sources.knative.dev/v1 (knative-eventing v1.3.0)
  - eventing.knative.dev/v1 (knative-eventing v1.3.0)
```

`$ kubectl get pods -n knative-serving`

```shell
NAME                                     READY   STATUS      RESTARTS   AGE
activator-855fbdfd77-5jhn5               1/1     Running     0          7h30m
autoscaler-85748d9cf4-p654d              1/1     Running     0          7h30m
controller-798994c5bd-8vsgk              1/1     Running     0          7h30m
default-domain-nl86s                     0/1     Completed   0          7h29m
domain-mapping-59fdc67c94-qnxgt          1/1     Running     0          7h30m
domainmapping-webhook-6df595d448-5k8vl   1/1     Running     0          7h30m
net-kourier-controller-74dc74797-bp65n   1/1     Running     0          7h29m
webhook-69fdbbf67d-wxwsg                 1/1     Running     0          7h30m
```

`$ kubectl get pods -n knative-eventing`

```shell
NAME                                    READY   STATUS    RESTARTS   AGE
eventing-controller-59475d565c-74qrt    1/1     Running   0          7h29m
eventing-webhook-74cbb75cb-f4hc2        1/1     Running   0          7h29m
imc-controller-84c7f75c67-7jbg8         1/1     Running   0          7h29m
imc-dispatcher-7786967556-48tcx         1/1     Running   0          7h29m
mt-broker-controller-65bb965bf9-hkn7q   1/1     Running   0          7h29m
mt-broker-filter-8496c9765-q6rg2        1/1     Running   0          7h29m
mt-broker-ingress-67959dc68f-8sf7c      1/1     Running   0          7h29m
```

### Deploying Angular app via Knative

All that needs to be done is:

`$ kubectl apply -f ng-demo.yaml`

The YAML file itself contains the [CRD](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) `Service` which is [defined by Knative](https://github.com/knative/specs/blob/main/specs/serving/knative-api-specification-1.0.md#service).

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: ng-demo
spec:
  template:
    metadata:
      # This is the name of the revision. It must follow the convention {service-name}-{revision-name}
      name: ng-demo-v2
      annotations:
        autoscaling.knative.dev/target: "2"
    spec:
      containers:
        - image: brakmic/ng-demo:0.2
          ports:
            - containerPort: 80
```

To check the deployment status of the app:

`$ kn services list`

```shell
NAME      URL                                         LATEST       AGE   CONDITIONS   READY   REASON
ng-demo   http://ng-demo.default.127.0.0.1.sslip.io   ng-demo-v2   31m   3 OK / 3     True
```

Knative is not only defining all the basic stuff like Deyploment, Ingress, Service, but also setting up a local DNS.

To get the K8s deployment:

`$ kubectl get deployments -n default`

```shell
NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
ng-demo-v1-deployment       0/0     0            0           42m
ng-demo-v2-deployment       0/0     0            0           29m
```

As shown above, we can have many `revisions` that can also run in parallel and get assigned different ports. In your case you'll see only the second deployment as this is the only one available by default when running from this repo. 

However, it's very easy to create a new revision. Just change the `name` in the `metadata` of the YAML file and do a `kubectl apply` again.

### Running multiple revisions in parallel

With Knative we can also run multiple revisions art the same time and also split the traffic between them.

```yaml
traffic:
  - tag: current
    revisionName: ng-demo-v2
    percent: 50
  - tag: upcoming
    revisionName: ng-demo-v3
    percent: 50
```

Take the other YAML file called `ng-demo-with-revisions` and apply it with `kubectl`.

Then execute this to get an overview of running services and routes:

`$ watch -n 1 kubectl get pod,ksvc,configuration,revision,route`

You should see two pods and deployments in a list similar to this:

```shell
Every 1.0s: kubectl get pod,ksvc,configuration,revision,route                                                                                                        BRAK9000
NAME                                         READY   STATUS    RESTARTS   AGE
pod/ng-demo-v2-deployment-59c4b8b784-zjhxp   2/2     Running   0          58s
pod/ng-demo-v3-deployment-f4648c7cd-2spdl    2/2     Running   0          24s0
NAME                                  URL                                         LATESTCREATED   LATESTREADY   READY   REASON
service.serving.knative.dev/ng-demo   http://ng-demo.default.127.0.0.1.sslip.io   ng-demo-v3      ng-demo-v3    True

NAME                                        LATESTCREATED   LATESTREADY   READY   REASON
configuration.serving.knative.dev/ng-demo   ng-demo-v3      ng-demo-v3    True

NAME                                      CONFIG NAME   K8S SERVICE NAME   GENERATION   READY   REASON                     ACTUAL REPLICAS   DESIRED REPLICAS
revision.serving.knative.dev/ng-demo-v1   ng-demo                          1            False   ProgressDeadlineExceeded   0
revision.serving.knative.dev/ng-demo-v2   ng-demo                          2            True                               1                 1
revision.serving.knative.dev/ng-demo-v3   ng-demo                          3            True                               1                 1

NAME                                URL                                         READY   REASON
route.serving.knative.dev/ng-demo   http://ng-demo.default.127.0.0.1.sslip.io   True
```
