# 一、Volume存储卷

​	我们知道， Docker容器运行起来之后，如果没有设置挂载volume卷到容器内，那么容器内产生的文件会随着容器的消亡而消亡，数据不能进行持久化存储。  K8S的volume卷和docker里面的volume作用含义是一样的。

​	例如K8S中要解决的一些场景问题:

​	1、Pod是容器组，多个容器有时候需要对同一份数据目录进行操作。 例如针对一个PHP项目， initC容器存在一个任务是git clone && git pull 拉取最新代码, 那么拉取代码存放到哪个位置呢? 如果存储在initC本身，那么容器执行完毕后数据也随之被删除。

​	我们需要存储到某一个位置之后， 后续的mainC也可以访问到这个位置，后续使用到这里面的源代码进行运行。

​	2、某些Pod可以直接访问宿主机的目录内容，例如在采集宿主机相关指标的时候，如何才能访问到宿主机文件内容? 

​	3、多个Pod需要共享同一份文件/目录, 如何实现这个需求?

​	volume存储卷就是帮助我们解决这些数据存储问题。 volume可以分为多种类型应对不同场景，有些是临时存储，生命周期与Pod周期一致、有些是跟随宿主机本身、有些则是远程存储方式等等。

# 二、宿主机存储卷[本地存储]

## 1、emptyDir

​	Pod所处宿主机节点，会创建目录/var/lib/kubelet/pods/<pod-id>/volumes/kubernetes.io~empty-dir/<volume-name> 

K8S会将此临时目录作为volume的存储介质，挂载到Pod对应的容器当中.

​	特点:

​		1、生命周期与Pod相同，整个Pod被销毁后，emptyDir类型的volume目录也会被删除

​	应用场景:

​		1、针对存储临时性数据，不考虑长期持久化存储，Pod被销毁数据也会被销毁的情况，如拉取仓库源代码进行运行或者做某些临时性操作，数据丢失不敏感

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: empty-dir-deploy
spec:
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      initContainers:
        - name: busybox
          imagePullPolicy: IfNotPresent
          image: nginx:alpine
          volumeMounts:
            - mountPath: /usr/share/nginx/html   #挂载容器的目标路径
              name: code-tmp-dir  #引用数据卷, volume名称
          command:   #模拟git pull拉取代码
            - "/bin/sh"
            - "-c"
            - "echo '<?php echo \"hello world\"; ' > /usr/share/nginx/html/index.php"
      containers:
        - name: nginx
          image: nginx:alpine
          volumeMounts:
            - mountPath: /usr/share/nginx/html 
              name: code-tmp-dir #引用数据卷, volume名称
      volumes:  # 声明有哪些volume卷、volume的名称、volume的存储方式/存储介质/大小限制等等
        - name: code-tmp-dir
          emptyDir:   # 默认为磁盘存储介质
            sizeLimit: 128Mi
#          emptyDir:    # 内存存储介质
#            medium: Memory  # tmpfs 内存临时文件系统
#            sizeLimit: 512Mi

```



## 2、hostPath

​	以Pod随处的宿主机的某一个路径作为volume存储介质，挂载到Pod对应的容器中。 数据的持久化取决于这个宿主机的磁盘大小、磁盘健康情况。  K8S无法感知hostPath类型的volume卷的存储容量。

​	特点:

​		1、数据的持久性与宿主机磁盘的健康强相关

​		2、Pod销毁，hostPath的Volume数据卷路径数据不会销毁

​	应用场景:

​		1、如采集/监控某些和宿主机本身相关的场景， 如Pod采集宿主机运行情况、内核情况等等， 可以将宿主机路径 以 **只读**方式进行挂载，保证数据的安全性采集

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: host-path-deploy
spec:
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          volumeMounts:
            - mountPath: /usr/share/nginx/html
              name: host-path-dir #引用数据卷, volume名称
              readOnly: true   #只读挂载
      volumes:  # 声明有哪些volume卷、volume的名称、volume的存储方式/存储介质/大小限制等等
        - name: host-path-dir
          hostPath:   # 存储介质是Pod所处Node宿主机
            path: /k8s/data/  # 宿主机路径
            #type: DirectoryOrCreate  #目录不存在则创建

```



​	
