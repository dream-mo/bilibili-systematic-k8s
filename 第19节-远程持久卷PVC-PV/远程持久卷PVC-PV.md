# 一、持久卷volume[远程存储]

## 1、简介

​	`emptyDir`、`hostPath`  两者都Pod所处的宿主机上的目录进行存储volume数据卷内容，最后挂载到Pod容器， 只是`emptyDir`是kubelet管理的、且创建的临时目录，`hostPath`是宿主机自定义目录[不受kubelet管理]， 最后两个挂载到Pod的容器中，达到数据存储的目的。

​	但是，这两者的存储方式volume卷，数据的可靠性较低， 特别是`emptyDir`与Pod生命周期是绑定的，Pod删除，目录也会被删除。 `hostPath`虽然比`emptyDir`稍微可靠，但是，可靠性也是强依赖于宿主机的可靠性。 假设宿主机出现问题，那么`hostPath`的数据卷数据也会丢失。

​	实际开发中，我们需要持久化存储的volume数据卷的场景很多、很频繁、也很重要，我们希望能够有一种volume数据卷本身与Pod所处宿主机无关， 并且提供高可用、可靠性高的存储方式， 可以提供给多Pod进行共享存储。  

​	并且，存储服务应该由专有团队进行维护，应用方无需关心底层实现细节。 无论底层是使用Minio还是HDFS还是OSS等等，应用层只需要能拿到这个volume进行存储即可。

​	答案是:   K8S提供的持久化Volume， 全称  `PersistentVolume`   简称 `PV`

​	K8S 的持久化存储（Persistent Storage）是**解决容器生命周期短暂导致数据易丢失问题的方案**，通过将数据存储在容器之外的独立存储资源中，确保 Pod 重启、迁移或删除后数据仍能保留。

## 2、核心思想

​	1、"存算分离"思想， 计算节点Pod与存储方式进行解耦,  Pod要使用`PV`不是直接使用，而是Pod需要提出所需存储volume申请`PVC` 全称`PersistentVolumeClaim`  简称`PVC`,  `PVC`里面声明了所需的存储类型名称、存储所需的容量等, 通过关联`PVC`从而使用`PV`

​	2、至于这个`PV`实际的实现方式， 例如底层是通过NFS、HDFS、Minio、OSS、或者Ceph等等存储技术，Pod无须关心，只需要提交"PVC申请单"即可，"PVC"申请单拿到PV之后，PVC与PV进行绑定， 最后将PVC和Pod进行绑定， 最后Pod可以使用对应PV进行挂载使用

​	3、Pod销毁之后，不影响之前存储的数据，之前存储的数据还会进行持久化保留。 下一次继续挂载这个PVC，数据还会呈现，不会丢失

![image-20250907184014230](/Users/mojun/Desktop/code/bilibili-systematic-k8s/第19节-远程持久卷PVC-PV/assets/image-20250907184014230.png)

## 3、PV(PersistentVolume)持久卷

### 1、数据共享策略

定义 PV 允许被如何访问，决定数据共享策略，常见模式：

- **ReadWriteOnce (RWO)**：仅允许一个 Pod 以读写方式挂载（最常用，如单实例数据库）。
- **ReadOnlyMany (ROX)**：允许多个 Pod 以只读方式挂载（如共享配置文件）。
- **ReadWriteMany (RWX)**：允许多个 Pod 以读写方式挂载（如分布式文件系统 NFS、GlusterFS）。

### 2、PV的底层实现驱动

PV底层的实现驱动遵循CSI规范即可.   只要你符合CSI的规范，那么就可以作为K8S  PV的底层存储介质。  例如场景的存储实现方式有:

1、NFS

2、Minio

3、Ceph

等等.    存储团队只需要关心如何提高PV的高可用、高可靠性、稳定性、更大的容量、更快的速度等等， 不需要和业务本身进行耦合。

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv-10g
spec:
  storageClassName: "nfs"
  nfs:
    path: /nfs-data/share/pv10g     #NFS存储数据的实际路径, 里面会存储index.html文件
    server: 192.168.2.109           #NFS的地址
  capacity:
    storage: 10Gi                   #PV的容量
```



## 4、PVC(PersistentVolumeClaim) 持久卷存储申请

​	Pod不与PV进行直接绑定， 两者进行了解耦， 引入PVC  持久卷申请的概念.  开发者不关心底层PV如何实现，  存储团队也无须关心上层Pod所需存储业务需求。

​	Pod只需要提出PVC申请， 那么K8S会基于给的需求，例如存储介质名称storeageClassName、所需存储容量、所需数据共享策略方式、labels标签等等，  让K8S根据这些需求进行匹配，经过一系列的决策，最后给定一个可用的PV，  PV与PVC进行绑定， 最后绑定到Pod，完成绑定过程，  Pod容器向使用本地磁盘操作方式一样操作数据即可， 无需关心底层实现.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim         #PVC申请单
metadata:
  name: nfs-pv
spec:
  storageClassName: "nfs"           #指定的存储类名称 与 PV的storageClassName 名称一致才能匹配
  resources:
    requests:                       #资源所需申请 10Gi 存储空间
      storage: 10Gi
  accessModes:                      #PV的访问方式是多节点读写需求
    - ReadWriteMany
```

## 5、静态PV和动态PV

### 1、静态PV

需要管理员预先创建PV， 提供给业务方进行使用， 如果没有预先创建PV， 提出的PVC申请单无法找到匹配的PV， 那么无法与PV进行绑定，导致Pod处于Pending状态，  PVC也处于未绑定状态。

适用场景:   所需PV数量需求少，需求明确.  如果需求量大， 需要管理员频繁创建PV， 增加了管理员运维压力

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv-10g
spec:
  storageClassName: "nfs"
  accessModes:
    - ReadWriteMany
  nfs:
    path: /nfsdata/share/pv10g     #NFS存储数据的实际路径, 里面会存储index.html文件
    server: 192.168.2.109           #NFS的地址
  capacity:
    storage: 10Gi                   #PV的容量
---
apiVersion: v1
kind: PersistentVolumeClaim         #PVC申请单
metadata:
  name: nfs-pvc
spec:
  storageClassName: "nfs"           #指定的存储类名称 与 PV的storageClassName 名称一致才能匹配
  resources:
    requests:                       #资源所需申请 10Gi 存储空间
      storage: 10Gi
  accessModes:                      #PV的访问方式是多节点读写需求
    - ReadWriteMany
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      volumes:
        - name: html-data-volume        #定义volume数据卷
          persistentVolumeClaim:        #volume的存储驱动是 PVC  持久卷方式
            claimName: nfs-pvc          #PVC 持久卷申请的名称 nfs-pvc
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
              name: http
          volumeMounts:
            - mountPath: /usr/share/nginx/html    #容器目标路径
              name: html-data-volume     #将volume数据卷挂载到目标路径
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
spec:
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30090
  type: NodePort
```



### 2、动态PV

底层PV不需要管理员手动创建，而是根据PVC申请单，动态创建PV之后PVC和PV再进行绑定。

适用场景:  所需PV数量大， 需求不明确， 都是动态需求或者需求不固定。  此时使用动态PV，增加了灵活性，减少管理员干预的运维压力

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc
spec:
  storageClassName: "nfs-client"           #指定的存储类名称 与 PV的storageClassName 名称一致才能匹配
  resources:
    requests:                       #资源所需申请 10Gi 存储空间
      storage: 10Gi
  accessModes:                      #PV的访问方式是多节点读写需求
    - ReadWriteMany
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      volumes:
        - name: html-data-volume        #定义volume数据卷
          persistentVolumeClaim:        #volume的存储驱动是 PVC  持久卷方式
            claimName: nfs-pvc          #PVC 持久卷申请的名称 nfs-pvc
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
              name: http
          volumeMounts:
            - mountPath: /usr/share/nginx/html    #容器目标路径
              name: html-data-volume     #将volume数据卷挂载到目标路径
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
spec:
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30090
  type: NodePort
```

