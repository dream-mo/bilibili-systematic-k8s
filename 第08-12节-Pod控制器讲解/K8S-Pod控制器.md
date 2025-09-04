#  一、Pod控制器-简介

​	Pod的生命周期是不固定的, 如果某个Pod由于不可抗力因素或者运维因素，被进行 驱逐. 那么如果不存在某一种数据结构针对Pod进行"高可用"控制，重新将Pod拉起，那么这些Pod就是不稳定的，不稳定的Pod是无法提供稳定服务的。

​	有什么数据结构或者程序， 可以针对Pod的运行行为、运行特性 做到控制，能够让Pod具备不一样场景下的运行控制，满足我们的实际部署需求呢?

​	答案就是， Pod控制器.   不同类型的Pod控制器可以针对Pod的运行行为、运行特性进行控制，用于满足我们的实际部署需求。 这些Pod控制器是K8S官方内置提供的功能， 作为基础设施的存在， 不需要我们开发者/运维者来进行维护。

​	官方提供的这些基础设施Pod控制器，以及极大程度地保证了稳定性、安全性以及可靠性。 我们只需要学会使用这些Pod控制器即可

# 二、Pod控制器-分类

## 1、ReplicaController[基本副本集]

### 1、简介

​	**作用**： 最基本的Pod控制器， 通过`replicas`字段，保证Pod能够稳定运行期望的副本数.(即使这些Pod由于某些原因导致被杀死，RC控制器会自动感知，并且重新拉起新Pod，满足副本数的期望)

特点:

- 通过标签选择器（`selector`）关联 Pod，仅管理匹配标签的 Pod。
- 仅支持标签选择器为`matchLabels`的等值匹配

   注意📢:   RC 是 Kubernetes 早期的 Pod 副本管理控制器，功能上被 ReplicaSet 取代，目前已不推荐使用。在实际应用中，应优先选择 ReplicaSet 或更易用的 Deployment（它会自动管理 ReplicaSet）。

- <span style="color:red">从 Kubernetes v1.9 开始，RC 被标记为 “过时（Deprecated）”，官方推荐使用 ReplicaSet 或更高层的 Deployment。</span>

### 2、字段参考

参考文档: https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.32/#replicationcontroller-v1-core

```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  # Unique key of the ReplicationController instance
  name: replicationcontroller-example
spec:
  # 3 Pods should exist at all times.
  replicas: 3
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      # Run the nginx image
      - name: nginx
        image: nginx:alpine
```



## 2、ReplicasSet[支持更丰富的labels标签选择器]

### 1、简介

- **作用**：确保指定数量的 Pod 副本始终运行，是最基础的控制器之一。
- 特点:
  - 通过标签选择器（`selector`）关联 Pod，仅管理匹配标签的 Pod。
  - 支持动态扩缩容（调整 `replicas` 字段）。
  - 不支持滚动更新，通常被更高层的控制器（如 Deployment）使用。
  - 支持更复杂的标签选择方法， 如`matchExpressions`
- **适用场景**：单独使用较少，多作为 Deployment 的底层实现。

### 2、字段参考

参考文档: https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.32/#replicaset-v1-apps

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  # Unique key of the ReplicaSet instance
  name: replicaset-example
spec:
  # 3 Pods should exist at all times.
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      # Run the nginx image
      - name: nginx
        image: nginx:alpine
```



## 3、Deployment[无状态服务]

### 1、简介

- **作用**：在 ReplicaSet 基础上增加了**滚动更新**和**版本回滚**能力，是最常用的控制器。
- 特点:
  - 管理 ReplicaSet，通过创建新的 ReplicaSet 实现 Pod 版本更新。
  - 支持配置更新策略（如 `RollingUpdate` 滚动更新、`Recreate` 重建更新）。
  - 可查看历史版本，随时回滚到之前的状态。
- **适用场景**：无状态应用（如 Web 服务、API 服务）的部署和更新。

### 2、字段参考

参考文档: https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.32/#deployment-v1-apps

nginx: 1.16版本:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  # Unique key of the Deployment instance
  name: deployment-example
spec:
  # 3 Pods should exist at all times.
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        # Apply this label to pods and default
        # the Deployment label selector to this value
        app: nginx
    spec:
      containers:
      - name: nginx
        # Run this image
        image: nginx:1.16
```

升级至1.17版本:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  # Unique key of the Deployment instance
  name: deployment-example
spec:
  # 3 Pods should exist at all times.
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        # Apply this label to pods and default
        # the Deployment label selector to this value
        app: nginx
    spec:
      containers:
      - name: nginx
        # Run this image
        image: nginx:1.16
```

### 3、升级/回滚操作

1、回滚到1.16版本，只需要yaml文件的镜像版本改为1.16，执行apply -f，声明式API,会逐步滚动更新Pod， 先新建1.16的部分Pod，这部分pod正常之后，删除1.17的Pod，逐渐滚动直到所有Pod更新为1.16版本， 完成整个Deployment的回滚

```shell
kubectl rollout history deploy my-deploy  #查看升级变更历史

kubectl rollout undo deploy my-deploy --to-revision=1  --record #回滚到目标版本
```

2、通过git 版本控制工具, 进行版本切换，最后执行apply



### 4、核心字段

#### 1、revisionHistoryLimit[保留的部署历史数量限制]

`revisionHistoryLimit` 是 Kubernetes Deployment 中的一个配置参数，用于**控制保留的 ReplicaSet（RS）历史版本数量**，这些 RS 对应 Deployment 的不同修订版本（revision）。

- `revisionHistoryLimit` 定义了 Deployment 最多保留多少个**旧的 ReplicaSet**（不包括当前活跃的 RS）。
- 当 Deployment 进行滚动更新时，每次更新都会创建一个新的 RS，而旧的 RS 会被保留作为历史版本（用于回滚）。
- 当历史 RS 的数量超过 `revisionHistoryLimit` 时，最旧的 RS 会被自动清理删除。

#### 2、strategy[升级/滚回-更新策略]

##### 1、type  策略类型[默认值: RollingUpdate(滚动更新)、另外的可选值: Recreate(完全重新删除、重新创建)]

​	1、RollingUpdate  是滚动更新， 创建部分新Pod， 新Pod就绪后再删除旧Pod， 直到最后  都是新的Pod，并且副本数与期望值一致[服务平滑升级，但是滚动更新阶段， 流量可能会进入部分旧的Pod，部分进入新的Pod.  服务端的api升级，应该最好能兼容新旧api]



​	2、Recreate           将旧的Pod全部删除， 删除完毕后，再创建新的pod  [可能会造成服务中断]

##### 2、rollingUpdate[type为滚动更新，可以指定更新比例]

`maxSurge`: 

- **含义**：在滚动更新过程中，允许超出期望副本数（`replicas`）的最大 Pod 数量。
- **作用**：控制更新时可以 “额外创建” 多少个新 Pod，避免一次性创建过多 Pod 导致资源耗尽。
- 取值
  - 可以是**百分比**（如 `25%`）：基于期望副本数计算（四舍五入）。
  - 也可以是**绝对值**（如 `2`）：固定的额外 Pod 数量。

`maxUnavailable`: 

- **含义**：在滚动更新过程中，允许处于不可用状态的最大 Pod 数量（相对于期望副本数）。
- **作用**：控制更新时可以 “同时删除” 多少个旧 Pod，确保始终有足够的 Pod 提供服务。
- 取值:
  - 可以是**百分比**（如 `25%`）：基于期望副本数计算（向下取整）。
  - 也可以是**绝对值**（如 `1`）：固定的不可用 Pod 数量。
- **默认值**：`25%`









## 4、DaemonSet[每个Node固定运行一个Pod]

###  1、简介

- **作用**：确保集群中**所有（或指定）节点**都运行相同的 Pod 副本。并且副本数恒定等于 1, 有且只有1个
- 特点:
  - 新节点加入集群时，自动在节点上创建 Pod；节点移除时，自动删除 Pod。
  - 可通过节点亲和性（`nodeAffinity`）指定运行的节点。
- **适用场景**：<span style="color:red">日志收集（如 Fluentd）、监控代理（如 Prometheus Node Exporter）、网络插件（如 Calico）等需要在每个节点运行的组件。</span>

### 2、字段参考

参考文档: https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.32/#daemonset-v1-apps

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  # Unique key of the DaemonSet instance
  name: daemonset-example
spec:
  selector:
    matchLabels:
      app: daemonset-example
  template:
    metadata:
      labels:
        app: daemonset-example
    spec:
      containers:
      # This container is run once on each Node in the cluster
      - name: daemonset-example
        image: ubuntu:trusty
        command:
        - /bin/sh
        args:
        - -c
        # This script is run through `sh -c <script>`
        - >-
          while [ true ]; do
          echo "DaemonSet running on $(hostname)" ;
          sleep 10 ;
          done
```



### 3、核心字段



与deployment差不多，  但是 `replicas`字段不能进行设置、也没有这个字段的存在.

因为Daemonset强制规定，`replicas`副本数只能是有且只有1个.  每个节点都运行一个Pod副本.





## 5、Job[普通一次性Job]

### 1、简介

- **作用**：管理**一次性任务**，确保任务成功完成后，正常终止。
- 特点:
  - Pod 执行完任务后, 会自动结束（退出码为 0），Job 根据Pod的退出码来判定任务是否完成。 退出码为0，则代表正常完成，否则存在异常
  - Job支持并行执行（通过 `parallelism` 配置并行数）和任务重试（通过 `backoffLimit` 配置失败重试次数）。
- **适用场景**：数据备份、批处理任务（如数据清洗）、一次性脚本执行等。
- 注意事项:  <span style="color:red">由于存在重试机制， job在退出码为非0, 则容器默认会进行重试(重新执行)，所以我们的业务控制需要做`幂等处理`支持多次执行，不会产生副作用</span>

### 2、字段参考

参考文档: https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.32/#job-v1-batch

本节课不带领大家去官网查询文档，首先掌握核心字段的使用即可，后续有需求再去查看文档，查缺补漏.

样例:

```yaml
#python3 -m http.server 8000
apiVersion: batch/v1
kind: Job
metadata:
  name: busybox-job
spec:
  
  # 并行产生出来的Pod的数量, 默认1个
  # 如果completions 大于 parallelism 则进行分批次执行
  parallelism: 1
  
  # 要求完成次数,达到这个数量才算这个JOB执行完毕. 默认值是1
  completions: 1

  # job定义的JOB时间,超过这个时间JOB就是失败的
  activeDeadlineSeconds: 3000
  # 最大重试次数, 默认值6
  backoffLimit: 1
  # job运行的job和pod 多久会被清理, 默认需要手动清理,否则设置之后 到达这个时间会被自动清理
  ttlSecondsAfterFinished: 30
  template:
    metadata:
      name: example-job
    spec:
      # 重启策略, 失败才会重启. 只有OnFailure、Never
      restartPolicy: OnFailure
      containers:
      - name: curl
        image: nginx:alpine
        command:
          - "curl"
          - "http://192.168.2.109:8000"
```



### 3、核心字段

```yaml
  # 要求完成次数,达到这个数量才算这个JOB执行完毕. 默认值是1
  completions: 1
  # 并行产生出来的Pod的数量, 默认1个
  parallelism: 1
  # job定义的JOB时间,超过这个时间JOB就是失败的
  activeDeadlineSeconds: 3000
```

1、`completions` 

- **含义**：指定 Job 需要成功完成的 Pod 总数。
  当达到这个数量的 Pod 成功结束（状态为 `Completed`），Job 会被标记为 “完成”。
- **默认值**：`1`（即默认只需要 1 个 Pod 成功完成）。
- **示例**：若设置 `completions: 5`，则 Job 会持续创建 Pod 直到有 5 个 Pod 成功完成。

2、`parallelism`

- **含义**：指定 Job 同时运行的 Pod 最大数量（并行度）。
  控制并发执行的 Pod 数量，避免资源过度占用。
- **默认值**：`1`（即默认串行执行，一次只运行 1 个 Pod）。
- **示例**：若 `completions: 5` 且 `parallelism: 2`，则 Job 会每次同时运行 2 个 Pod，直到 5 个 Pod 全部成功完成

3、`activeDeadlineSeconds`

- **含义**：指定 Job 整个生命周期的最大运行时间（秒）。
  从 Job 创建开始计时，若超过这个时间仍未完成（未达到 `completions` 数量），则 Kubernetes 会终止该 Job 下所有运行中的 Pod，并标记 Job 为 “失败”。
- **默认值**：`未设置`（即默认没有超时限制，Job 会一直尝试直到完成）。
- **示例**：若设置 `activeDeadlineSeconds: 3000`，则 Job 最多运行 50 分钟（3000 秒），超时后会被强制终止

4、`ttlSecondsAfterFinished`

​    Kubernetes 1.21+ 引入的特性，用于指定 Job 完成（状态为 `Completed` 或 `Failed`）后，其关联的 Pod 保留的时间（秒）。

​    默认值是，需要管理员手动清理，不依赖系统进行回收清理.



## 6、CronJob[定时Job任务]

### 1、简介

- **作用**：基于**时间调度**的 Job，类似 Linux 的 `cron` 服务。  基于Job在做一层时间调度的封装， K8S时间调度触发Job的执行
- 特点:
  - 按照 cron 表达式（如 `0 3 * * *` 表示每天凌晨 3 点）定期创建 Job。
  - 支持配置任务历史保留数量（`successfulJobsHistoryLimit`、`failedJobsHistoryLimit`）。
- **适用场景**：定时备份、定时报表生成、周期性数据同步等。

### 2、字段参考

参考文档: https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.32/#cronjob-v1-batch

样例:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: busybox-cron-job
spec:
  schedule: "*/1 * * * *"  #调度周期 Cron  分/时/日/月/周
  concurrencyPolicy: Forbid  #上一个周期的任务任务没执行完毕,到时间调度了,则取消并发调度
  failedJobsHistoryLimit: 10  #失败job历史 保存数量
  successfulJobsHistoryLimit: 3 #成功job任务 保存数量
  jobTemplate:
    spec:
      completions: 3    #3次运行成功才算这个job成功
      parallelism: 1    #并发创建Pod的个数
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: busybox-tools
              image: nginx:alpine
              command:
                - "curl"
                - "http://192.168.2.109:8080/"
```

### 3、核心字段

1、`schedule`

​	调度周期字符串，和Linux的cron语法一致， 达到的级别是分钟级别。

​	"*/3 * * * *"    #调度周期 Cron  分/时/日/月/周    每3分钟执行调度执行任务

2、`concurrencyPolicy`

- **含义**：控制当新的 Job 要启动时，若前一次的 Job 仍在运行，应如何处理。
- 取值说明：
  - `Forbid`：禁止并发运行，若前一次 Job 未完成，则跳过本次调度（不创建新 Job）。
  - `Allow`（默认值）：允许并发运行，无论前一次 Job 是否完成，都创建新 Job。
  - `Replace`：若前一次 Job 未完成，则终止它，并用新的 Job 替代。
- 示例：若上一个定时任务还在运行，且 `concurrencyPolicy: Forbid`，则下一个 3 分钟的任务不会启动，直到上一个完成。

3、`failedJobsHistoryLimit`

- **含义**：指定保留的 “失败 Job” 的历史记录数量上限。
- 当 CronJob 生成的 Job 执行失败（状态为 `Failed`）时，Kubernetes 会保留其记录，超过此数值的旧记录会被自动清理。
- **默认值**：`1`（默认保留 1 条失败 Job 记录）。

4、`successfulJobsHistoryLimit`

- **含义**：指定保留的 “成功 Job” 的历史记录数量上限。
- 当 CronJob 生成的 Job 执行成功（状态为 `Completed`）时，超过此数值的旧记录会被自动清理。
- **默认值**：`3`（默认保留 3 条成功 Job 记录）。

5、`jobTemplate`

   控制创建pod的模板, 里面填写的就是和普通Job的spec期望数据格式一致



## 7、StatefulSet[有状态服务]

### 1、简介

- **作用**：用于管理**有状态应用**，确保 Pod 具有稳定的网络标识和存储。
- 特点:
  - Pod 名称固定（如 `web-0`、`web-1`），重启或重建后名称不变。
  - 网络标识稳定（通过 Headless Service 实现固定 DNS 记录）。
  - 存储与 Pod 绑定（使用 `PersistentVolumeClaim` 模板，每个 Pod 独占存储）。
  - 支持有序部署（从 0 到 N）和有序删除（从 N 到 0）。
- **适用场景**：数据库（如 MySQL 集群）、分布式系统（如 ZooKeeper）等有状态应用。



## 8、HPA[自动扩缩容]

- **作用**：根据**监控指标**（如 CPU 使用率、内存使用率、自定义指标）自动调整 Pod 副本数。
- 特点: 
  - 不直接管理 Pod，而是关联 Deployment、ReplicaSet 等控制器，动态调整其 `replicas` 字段。
  - 支持基于 CPU、内存的自动扩缩，也可集成自定义指标（如请求 QPS）。
- **适用场景**：流量波动较大的应用（如电商网站），通过自动扩缩容优化资源利用率。



