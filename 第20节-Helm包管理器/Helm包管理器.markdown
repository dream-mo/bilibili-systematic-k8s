# 一、安装软件至K8S环境如何解决批量yaml文件?

## 1、场景

​	举个例子， 我们要安装一个nginx服务到K8S当中，可能存在以下步骤:

​		1、创建一个namespace给这个nginx使用

​		2、创建deployment

​		3、如果涉及长期存储access.log和error.log，那么还会涉及PVC的创建

​		4、将nginx.conf配置文件使用configmap进行管理，需要创建configmap

​		5、暴露这个nginx服务出来，需要创建service

​	....等等

​	同时我们还需要支持开发环境、测试环境、生产环境， 三种环境的部署， 例如这几个环境当中所需的worker进程数量不同， 或者上传文件大小限制不同，或者deployment的副本数不同(开发环境可能不需要那么多副本，浪费资源).

## 2、传统解决方案

### 1、编写多个环境下yaml文件

​	1、将上述涉及到的所有yaml文件，可以拆分出来，形成单个yaml文件.  最后使用`kubectl apply -f`  整个目录从而进行创建

​	2、将上述所有yaml文件分别拷贝3份，开发环境、测试环境、生产环境， 不同环境配置不同参数即可。



​	1、代码的可维护性降低了

### 2、模板文件思想解决方案

​	参与过开发的同学，应该很了解template模板.  例如Python的`jinjia2`模板、Golang的模板语法等等,  我们可以编写模板文件，模板文件中融入变量、if-else、for循环等等语法.  使用一个程序来解析我们定义好的模板文件，就能动态生成内容。

​	那么这种模板文件的思想，就可以很好地解决我们K8S 资源对象在不同环境下的变化。

​	**只需要编写一份模板，针对不同环境，注入不同参数即可。 不需要针对每个环境，独立编写一份资源清单。 增加了代码的可维护性。**

# 二、Helm包管理器

## 1、简介

​	Helm 是 Kubernetes（K8s）的**包管理工具**，类似于 Linux 中的 `apt`、`yum` 或 Python 中的 `pip`，主要用于简化 Kubernetes 应用的**部署、版本管理、升级和回滚**

​	在 Kubernetes 中，一个应用通常由多个资源对象（如 Deployment、Service、ConfigMap、Ingress 等）组成，这些资源需要通过 YAML 文件定义和管理。当应用复杂时，手动维护大量 YAML 文件会非常繁琐，且难以实现版本控制和批量操作。 可解决K8S资源之间的依赖关系，例如先创建`namespace`的基础之上，再创建其它内容等依赖关系。

​	Helm 正是为解决这些问题而生。

## 2、核心概念

### 1、**Chart**

- 是 Helm 的**打包格式**，包含了一个 Kubernetes 应用的所有资源定义（YAML 文件）、配置模板、依赖关系等。
- 可以理解为 “应用安装包”，比如一个 Nginx 应用的 Chart 会包含 Deployment、Service 等资源的模板。
- Charts 可以存储在本地，也可以发布到公共或私有仓库（如 [Artifact Hub](https://artifacthub.io/) 是常用的公共 Chart 仓库）。

   

   Helm包管理器，管理的就是Chart包, 类似yum管理的是rpm格式的包类似概念.  

   ```shell
   helm   类比=>   yum
   
   Chart  类比=>   rpm
   
   Helm Repository 类比=>  rpm Repository仓库
   ```
   
   Chart包本质就是一个具有规范、标准的压缩包文件, 这个文件里面包含了包的元数据信息、资源清单yaml文件以及values.yaml变量定义注入文件等等。

### 2、**Release**

- 是 Chart 部署到 Kubernetes 集群后的**实例**。
- 同一个 Chart 可以在集群中部署多次，每次部署都会生成一个独立的 Release（通过不同的配置区分）。
- 例如，用同一个 Nginx Chart 部署两个不同的 Release：`nginx-prod`（生产环境）和 `nginx-test`（测试环境）。

​    

   有了Chart包只是一个压缩文件，并不能产生服务进程。 我们基于这个Chart包要运行起来，那么运行起来之后的这个Chart实例就是Release. 一个Chart包多被多次运行，运行为多个Release.  类似一个软件包，可以被运行为多个不同进程类似。

### **3、Repository**

- 用于**存储和分享 Charts**的地方，类似代码仓库（如 GitHub），方便用户查找和下载 Chart。
- Helm 支持添加多个仓库，用户可以通过仓库名获取 Chart（如 `helm repo add stable https://charts.helm.sh/stable`）。

​	

​    存储Chart包和分享Chart包的中央仓库， 类似docker镜像的dockerhub网站类似. 大家可以分享自己的Chart包，例如Nginx、Redis、MySQL等等常用的软件， 都有官方组织为了推广自家产品影响力和融入K8S生态， 会在 [Artifact Hub](https://artifacthub.io/) 或者自家维护自己的Chart仓库Repository。 提供给开发者来进行安装和使用

### 4、values.yaml

​	每个Helm包，都会存在一个values.yaml文件。这个文件就chart包模板文件中，模板变量的具体值的设置。  例如你在chart包的模板中所需一个变量叫app_env,  但是这个app_env应该是根据你部署chart包的实际情况进行编写的，那么这个实际情况的值应该填写在values.yaml中。

​	一旦你设置在values.yaml,那么模板变量从中读取的就是你设置的值。  到这里大家发现吧，上述的开发环境、测试环境、生产环境，在有了helm之后，只需要针对不同环境下填写不同的values.yaml即可。

​	整个软件包的架构、模板不需要改变。 如果调整的话，也只需要调整一次，而不是像传统解决方案，拷贝3份代码，独立维护3份代码。

# 三、Helm的基本原理和使用

## 1、基本原理

​	Helm本身就是使用golang编写的二进制程序。 采用的是Golang的模板语法， 在模板文件中使用golang的模板语法动态生成yaml资源清单。  只要你编写了符合规范的Chart包，以及helm模板文件，那么就能给你动态生成yaml资源清单，并且处理资源清单之间的依赖关系。

​	官网: [helm](http://helm.sh)  helm.sh

​	github: https://github.com/helm/helm



​	Helm本质就是:   一个支持Go 模板语言解析[专为生成K8S资源yaml文件]的二进制程序, 可以通过读取values.yaml中的变量值，注入到K8S资源yaml模板文件中, 动态生成最终部署的K8S资源yaml文件, 最后按照资源依赖关系，创建和管理K8S资源清单。


## 2、基本使用

​	还是举例部署nginx这个软件包为实际场景

### 1、添加helm仓库

```shell
helm repo add bitnami https://charts.bitnami.com/bitnami
#国内加速  https://helm-charts.itboon.top/docs/
helm repo add bitnami "https://helm-charts.itboon.top/bitnami" --force-update
helm repo update
```

### 2、下载helm包至本地

```shell
helm search repo nginx

#将chart包下载到本地
helm pull bitnami/nginx  
```

### 3、部署一个release

```shell
#Chart压缩包解压, 方便修改values.yaml进行部署
tar -zxvf nginx-22.0.0.tgz
cd nginx
#部署chart为release实例  release名称是nginx-release 没有-f 默认就是 values.yaml
#默认副本数只有1个, 例如此时是dev开发环境
helm install nginx-dev-release . -f values.yaml

#再部署一个prod生产环境,副本数是4个
#修改values.yaml  replicaCount参数为4
helm install nginx-prod-release .

```





