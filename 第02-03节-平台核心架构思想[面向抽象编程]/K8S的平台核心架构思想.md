## 一、K8S的平台核心架构思想

  1、**出标准**, 做上层接口抽象, 不负责具体实现. 让各个厂家都能合理、公平竞争，针对接口做出更好的实现
  2、投入更加聚焦时间在平台建设，而非具体实现
  3、具体实现会"死"，  平台不会死.   平台不固定依赖某个具体实现，不会存在一家独大，威胁平台本身, 随时可以替换

## 二、发展历程

  1、2003年, Google早期的Borg系统是K8S的前身. 当时容器编排技术在Google已经十分成熟.可运行数十万个来自不同应用程序的作业，为 K8s 的诞生奠定了基础。

  2、2014 年中，Google 推出 Kubernetes，作为 Borg 的开源版本。6 月 7 日，Kubernetes 在 GitHub 上完成第一次提交。7 月 10 日，微软、RedHat、IBM、Docker 等加入 Kubernetes 社区。

  3、Docker如日中天, 趁着docker的东风, 将K8S的整个运行时机制和Docker进行绑定, 获得了大量的用户

  4、吞并Apache mesos、docker Swarm,  成为容器编排的事实标准

  5、逐渐往平台化发展，  提出CRI、CNI、CSI 接口标准,  CRI标准的提出, 代表着docker不再是k8s的唯一容器运行时.但是docker还是占据大量市场, docker没有向CRI靠拢,  那么K8S考虑到现状， 加入dockershim垫片[中间过渡，docker实现CRI的一个插件程序]，用来兼容docker


  6、2022年, dockershim于1.24版本彻底被移除, 后期使用containerd作为k8s的默认容器运行时

## 三、Ingress的例子


  1、Ingress的规则是平台化的、标准的[除了annotations,各厂家注入的属性可能不同，来实现不同标记功能],  可以切换不同的ingress控制器的实现, 最终完成一样的7层流量负载

  2、nginx ingress控制器 切换为   haproxy 控制器实现,  很简单  只需要更改ingress的资源清单, apply 之后 由haproxy来自己更新规则.

  通过haproxy来进行接管流量

## 四、Gateway API

  1、下一代 ingress 7层、4层代理的抽象资源接口，  同样的套路， 只是提供抽象接口， 具体实现由各个厂家实现

