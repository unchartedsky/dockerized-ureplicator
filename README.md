[![](https://images.microbadger.com/badges/image/unchartedsky/ureplicator.svg)](https://microbadger.com/images/unchartedsky/ureplicator "Get your own image badge on microbadger.com")
[![Build Status](https://travis-ci.com/unchartedsky/dockerized-ureplicator.svg?branch=master)](https://travis-ci.com/unchartedsky/dockerized-ureplicator)

# dockerized-ureplicator

Docker image for [uber/uReplicator](https://github.com/uber/uReplicator). Thanks to [danielcoman/kubernetes-uReplicator
](https://github.com/danielcoman)!

# Available configurations

Essential parts can be configured via environment variables:

- `SERVICE_TYPE`: `controller` or `worker`
- `SRC_ZK_CONNECT`: For instance, `zk-0.zookeeper.source-kafka.svc.cluster.local:2181,zk-1.zookeeper.source-kafka.svc.cluster.local:2181,zk-2.source-kafka.monitoring.svc.cluster.local:2181/kafka`.
- `CONSUMER_GROUP_ID`: For instance, `ureplicators`.
- `HELIX_CLUSTER_NAME`: For instance, `uReplicator`.
- `HELIX_ENV`: For instance, `dev`.
- `HELIX_ZK_CONNECT`: For instance, `zk-0.zookeeper.ureplicator.svc.cluster.locaal:2181,zk-1.zookeeper.ureplicator.svc.cluster.local:2181,zk-2.ureplicator.monitoring.svc.cluster.local:2181/ureplicator`.
- `HELIX_ZK_ADDRESS`: For instance, `zookeeper.ureplicator`
- `HELIX_ZK_PORT`: For instance, `2181`.
- `SRC_ZK_CONNECT`: For instance, `zk-0.zookeeper.destination-kafka.svc.cluster.local:2181,zk-1.zookeeper.destination-kafka.svc.cluster.local:2181,zk-2.destination-kafka.monitoring.svc.cluster.local:2181/kafka`.
- `DST_BOOTSTRAP_SERVERS`: For instance, `kafka-0.broker.destination-kafka.svc.cluster.local:9092,kafka-1.broker.destination-kafka.svc.cluster.local:9092,kafka-2.broker.destination-kafka.svc.cluster.local:9092`
- `TOPICS`: For instance, `DummyTopic1,DummyTopic2,DummyTopic3`.
- `PARTITIONS`: For instance, `1,2,3`
- `WORKER_ABORT_ON_SEND_FAILURE`: Set the value to `--abort.on.send.failure`. It only works when `SERVICE_TYPE` is `worker`. Default is `false`.
- `JAVA_OPTS`
- `LOGICAL_PROCESSORS` is automatically calculated if it is not set by manual.

# Run on Kubernetes

``` yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ureplicator-envs
data:
  SRC_ZK_CONNECT: zk-0.zookeeper.source-kafka.svc.cluster.local:2181,zk-1.zookeeper.source-kafka.svc.cluster.local:2181,zk-2.source-kafka.monitoring.svc.cluster.local:2181/kafka

  CONSUMER_GROUP_ID: ureplicators

  HELIX_CLUSTER_NAME: uReplicator

  HELIX_ENV: dev

  HELIX_ZK_CONNECT: zk-0.zookeeper.ureplicator.svc.cluster.locaal:2181,zk-1.zookeeper.ureplicator.svc.cluster.local:2181,zk-2.ureplicator.monitoring.svc.cluster.local:2181/ureplicator

  HELIX_ZK_ADDRESS: zookeeper.ureplicator

  HELIX_ZK_PORT: '2181'

  DST_ZK_CONNECT: kafka-0.broker.destination-kafka.svc.cluster.local:9092,kafka-1.broker.destination-kafka.svc.cluster.local:9092,destination-kafka-2.broker.next.svc.cluster.local:9092

  DST_BOOTSTRAP_SERVERS: kafka-0.broker.destination-kafka.svc.cluster.local:9092,kafka-1.broker.destination-kafka.svc.cluster.local:9092,kafka-2.broker.destination-kafka.svc.cluster.local:9092

  TOPICS: DummyTopic1,DummyTopic2,DummyTopic3
  PARTITIONS: '1,2,3'

  WORKER_ABORT_ON_SEND_FAILURE: 'true'

---
apiVersion: apps/v1beta2 # for versions before 1.8.0 use apps/v1beta1
kind: Deployment
metadata:
  name: ureplicator-controller
  labels:
    app: ureplicator
    component: controller
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ureplicator
      component: controller
  template:
    metadata:
      labels:
        app: ureplicator
        component: controller
    spec:
      terminationGracePeriodSeconds: 10
      initContainers:
      - name: init-zk
        image: busybox
        command:
          - /bin/sh
          - -c
          - 'until [ "imok" = "$(echo ruok | nc -w 1 $HELIX_ZK_ADDRESS $HELIX_ZK_PORT)" ] ; do echo waiting ; sleep 1 ; done'
        env:
        - name: SERVICE_TYPE
          value: "init"
        envFrom:
        - configMapRef:
            name: ureplicator-envs
      containers:
      - name: ureplicator-controller
        image: unchartedsky/ureplicator:latest
        imagePullPolicy: Always
        env:
        - name: SERVICE_CMD
          value: "start-controller.sh"
        - name: SERVICE_TYPE
          value: "controller"
        - name: FOR_GODS_SAKE_PLEASE_REDEPLOY
          value: "123"
        envFrom:
        - configMapRef:
            name: ureplicator-envs
        ports:
        - name: api-port
          containerPort: 9000
        livenessProbe:
          httpGet:
            path: /health
            port: api-port
          initialDelaySeconds: 120
          timeoutSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: api-port
          initialDelaySeconds: 120
          timeoutSeconds: 10
        resources:
          requests:
            cpu: 1000m
            memory: 3000Mi
          limits:
            cpu: 1000m
            memory: 3000Mi
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: ureplicator-worker
  labels:
    app: ureplicator
    component: worker
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ureplicator
      component: worker
  template:
    metadata:
      labels:
        app: ureplicator
        component: worker
    spec:
      terminationGracePeriodSeconds: 10
      initContainers:
      - name: init-zk
        image: busybox
        command:
          - /bin/sh
          - -c
          - 'until [ "imok" = "$(echo ruok | nc -w 1 $HELIX_ZK_ADDRESS $HELIX_ZK_PORT)" ] ; do echo waiting ; sleep 10 ; done'
        envFrom:
        - configMapRef:
            name: ureplicator-envs
      containers:
      - name: ureplicator-worker
        image: unchartedsky/ureplicator:latest
        env:
        - name: SERVICE_TYPE
          value: "worker"
        - name: SERVICE_CMD
          value: "start-worker.sh"
        - name: FOR_GODS_SAKE_PLEASE_REDEPLOY
          value: "123"
        envFrom:
        - configMapRef:
            name: ureplicator-envs
        resources:
          requests:
            cpu: 1000m
            memory: 3000Mi
          limits:
            cpu: 1000m
            memory: 3000Mi
```

# TODO

- [ ] The combination of `HELIX_ZK_ADDRESS` and `HELIX_ZK_PORT` might be able to replace `HELIX_ZK_CONNECT`

# See also

- [Kafka Mirror Maker Best Practices - Hortonworks](https://community.hortonworks.com/articles/79891/kafka-mirror-maker-best-practices.html)
- [uReplicator: Uber Engineering’s Robust Apache Kafka Replicator](https://eng.uber.com/ureplicator/)
- [danielcoman/kubernetes-uReplicator
](https://github.com/danielcoman)
