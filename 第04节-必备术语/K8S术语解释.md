# 一、K8S的常见术语

## 1、Node节点、Master节点、Cluster集群、Namespace

### 1、Cluster集群

​	一个K8S  clsuter集群是指由**Master节点服务器**[至少1个]、**Node节点服务器**所组成服务器的集合， 这个集合就叫K8S集群.

​	K8S集群简单理解就是一个有多个Node节点服务器组成的  **超大电脑**

​	Pod在这个**超大电脑** 面前， 就是  这个电脑的  进程.

### 2、Namespace

​	K8S集群内进行资源的 **逻辑隔离** 限制机制， 处于某一个Namespace下面的资源， 受到这个Namespace提前定义好的资源限制.  逻辑上对资源对象进行隔离，  不存在一个具体实物， 既不是一个文件、也不是一个程序.

​	逻辑分组， 企业里存在很多业务部门， 不进行逻辑分组管理，会变成大杂烩，不利于管理

### 3、Master节点[控制平面]

​	Master节点服务器， 是整个集群的大脑.  主要运行 三大组件   **kube-apiserver**、**kube-Scheduler**、**Controller Manager**

​	1、 **kube-apiserver**  整个集群唯一的API入口组件，关于资源对象的增删改查，都是需要与kube-apiserver进行交互

​	2、**kube-Scheduler**  负责集群内Pod具体运行的调度策略，  根据目前的K8S集群资源情况，通过各种算法， 最终让Pod调度在最合适的Node节点运行

​	3、  **Controller Manager**  内置存在很多资源对象的Controller控制器，例如Node资源、Pod资源、Service资源、Ingress资源等等控制器的程序功能， watch监听对应的资源变化情况， 做出对应的操作

### 4、Node节点[数据平面]

​	Node节点服务器， 负责具体Pod的生命周期管理、Pod网络访问等. 主要运行  两大组件  **kubelet**、**kube-proxy**

​	1、**kubelet**  负责watch监听kube-apiserver， 一旦有关于分配到本节点的Pod的信息，如创建、更新、删除等事件，则进行对应操作，最后与kube-apiserver交互， 更新Pod的状态 、更新操作的最终结果

​	2、**kube-proxy**  负责watch监听kube-apiserver， 一旦有service、pod变动， service与pod相关的绑定关系等事件触发，kube-proxy利用iptables或者ipvs， 创建对应的规则， 为后期通过service访问Pod提供必要的基础

## 2、Pod[一组关系紧密的容器]

### 1、介绍	

1、Pod是K8S调度的**基本单位**,  类比  CPU调度的基本单位是 线程

2、Pod是由一组关系紧密的容器组成， 包含的容器个数至少1个， 且这些容器共享内置**pause容器** 的某些命名空间[网络命名空间默认是共享的]、其余某些命名空间可选共享或者不共享.   Pod内部各个容器**通过 localhost  进行通信**,  **共享端口监听范围**

​		最常见的:   Nginx+php-fpm组合， 两者关系紧密， Nginx容器解析HTTP协议，通过fastcgi协议转发请求到php-fpm容器

3、Pod在某个Node节点上的生命是不固定，  Pod随时面临在当前Node上死亡[集群运行的错综复杂环境，如资源问题、节点压力问题、运维问题等等造成，造成的因素不固定，不可提前预料], 然后被**kube-Scheduler**重新调度到一个新的、合适的Node节点运行.  <span style="color:red">所以,  不要依赖Pod分配到的IP地址， 因为这个IP地址随着Pod的重建变化而变化</span>

4、**pause容器**, 是组成Pod的一个"内置容器", 这个容器是组成Pod的关键， 非业务容器,  对于我们使用Pod而言，<span style="color:red">这个pause容器是透明的、无感知的</span>	

## 3、Pod控制器

### 1、介绍	

​	针对Pod的一些运行特性，我们如何控制呢? 例如很常见的问题就是Pod能不能有定义副本数的功能，如docker-compose那种， 通过多个副本数提供服务，提高应用的高并发?  或者更加智能的一些特性功能.

​	K8S对此通过控制器来解决这个问题.  

​	一些针对Pod在不同业务场景下面，相对通用的、基础性的、且是一般是官方维护的、内置的、**用于控制Pod运行特性/行为的程序**， 

我们称之为Pod控制器.  

### 2、Pod控制器分类

​	  1、ReplicationController(RC)、ReplicaSet(RS)   控制器:   简单的，控制Pod期望运行的副本数恒定

​	  2、Deployment  控制器:    底层通过控制RS来实现Pod的滚动更新、回滚等. 同时也具备了RS的副本数恒定的控制功能

​	  3、DeamonSet   控制器:    Pod会被控制运行在每个Node节点，并且Node节点只运行1个Pod实例

​	  4、Job/CronJob   控制器:    Pod会执行一次性任务/定时执行一次性任务，执行完毕则正常退出即可，不需要持续运行

​	  5、StatefulSet     控制器:    Pod创建会严格按照顺序进行创建，同时Pod的hostname不会进行随意分配，销毁也是按照顺序删除，而不是随意删除.

​	  6、HPA   控制器			 :     根据资源的使用情况，如CPU占用率、内存占用率等， 动态控制Pod的副本数，动态扩容、或者动态缩容.	

## 4、Service[给Pod提供一个抽象VIP(虚拟IP)访问机制]

### 1、介绍

​	正是因为Pod的生命不固定的， 随时面临死亡， 重新创建。  重新创建会新分配IP地址， 如果客户端通过依赖Pod的IP进行开发，那么毫无疑问，这个IP是不可靠的.  因为Pod的IP会随着Pod的新建变化而变化. 怎么解决这个问题呢?

​	K8S提供了service对象， 来解决这个问题.    

​	service对象可以理解是提供了一个集群的VIP(虚拟IP地址)， 并且这个service和符合label标签规则的Pod进行动态绑定，  如Pod新增， 则这个service VIP的负载均衡后端添加这个IP， 如果Pod被删除，那么负载均衡后端也会自动删除这个IP地址， 这个过程对于客户端是无感的、透明的.

​	客户端只需要一直通过这个VIP或者集群的固定域名[<span style="color:red"><server_name>.<namespace>.svc.cluster.local</span>]进行访问即可， 无须关心后端实际Pod的IP地址变化情况

### 2、service分类

​	1、**ClusterIP**:   默认类型， 分配一个集群的VIP地址，通过VIP地址负载均衡访问后端绑定的Pod

​	2、**NodePort**:   在所有Node节点上，开启一个静态端口(30000-32767)监听,  集群外部的客户端，可以通过Node的IP地址+端口的形式，负载均衡来访问到集群内部这个service后端绑定的Pod

​		例如存在一个节点的IP是:  192.168.1.110，  我可以设置这个service为NodePort类型，指定端口为30080.

​		那么集群外的客户端可以通过访问    http://192.168.1.110:30080  访问到我后端的Pod的服务

​	3、**ExternalName**:   利用集群的dns功能， 给外部服务做一个CNAME别名，写入到集群内部的DNS系统.  这样可以将外部系统通过域名的方式， 纳入/集成到本集群内， 本集群内的客户端，可以使用集群域名的形式，访问外部服务.

​			例如定义一个集群域名，叫 my-baidu，  通过ExternalName的service方式，  CNAME指向www.baidu.com, 那么我们集群内可以通过 访问   my-baidu.<namespace>.svc.cluster.local    访问到百度服务

​	4、**LoadBalancer**:   通过云提供商的负载均衡器（如 AWS ALB、GCP LB）暴露服务.  自动创建外部负载均衡器并分配外部 IP

​	5、**Headless  Service**:    设置service的字段 clusterIP: None， 一般结合提供给Pod控制器 **StatefulSet**进行使用， Headless Service会返回所有后端Pod的IP  A记录列表.  由客户端来自己实现负载均衡策略， service不管

## 5、Ingress[集群外部7层负载均衡访问集群内的Pod]

​	service解决的是集群内部，服务暴露和访问的方式.   那么我们K8S集群本质还是要向外部提供服务，  外部的客户端来访问到集群内的服务，才是最终目的.

​	Ingress 的出现是为了弥补 Service 在外部访问和高级路由管理上的不足, Ingress 是 Kubernetes 的 L7（应用层）入口控制器, 相对service做4层代理， Ingress更多是在7层代理下功夫.  然而我们更多的开发场景下面，都是使用HTTP协议， 处于7层.

​	Ingress支持更多的HTTP路由规则、流量分发功能、 HTTPS证书管理等等， 总结，就是可以根据HTTP  7层协议，能做更精细化的流量分发等功能。

​	Ingress 资源本身只是一个规则声明，需要 Ingress Controller 具体实现这些规则:

​	





