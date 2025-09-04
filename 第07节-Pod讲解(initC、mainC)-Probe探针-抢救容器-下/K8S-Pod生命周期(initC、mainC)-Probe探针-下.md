# 一、Pod服务健康探测与"抢救方案"

## 1、怎么对Pod做健康检查?

​	一个Pod本质上是一个关系紧密的容器组，  容器组存在的目的，就是持续、不间断地向外部提供服务， 最常见的是HTTP服务， 也不排除还有TCP服务、gRPC服务.

​	那么如何像docker、docker-compose一样，可以定义health check， 健康检查机制， 例如通过一个程序，定时/定期 执行某些指令， 或者向服务的目标接口发送请求， 通过响应的内容，来判定服务的健康状态?

​	如果存在这种健康检查机制，那么我们能够对服务的状态更加了如指掌， 满足运维人员的监控需求， 以及能够让运维人员快速发现问题、定位问题、解决问题， 保证整个服务的高可用.

## 2、K8S提供的Probe探针-主动拨测机制

​	K8S  通过  `kubelet`组件， 针对Pod内部的容器做`定时拨测`机制，从而来确定Pod容器的服务是否正常， 若正常则不会采取其他措施，若异常则会采取相应"抢救措施"， 抢救Pod 恢复到正常状态.

​	要理解"抢救"这个概念， 抢救只能尽力，无法保证Pod一定能够恢复正常状态.  

### 1、livenessProbe[存活探针]

**作用**：<span style="color:red">检测容器是否仍在正常运行。如果探测失败，kubelet会认为容器不健康并采取相应措施。</span>

**解决的问题**：

- 检测"死锁"或"僵尸"状态的应用程序（进程存在但无法提供服务）
- 识别因内部错误导致应用停止响应的情况

**Kubelet响应**：

- 探测失败 → 抢救方案: <span style="color:red">kubelet会杀死容器并根据重启策略(restartPolicy)重启它</span>
- 目的是恢复应用程序的正常运行状态

### 2、readinessProbe[就绪探针]

**作用**：<span style="color:red">检测容器是否已准备好接收流量。只有当就绪探针成功时，Service才会将Pod纳入端点列表。</span>

**解决的问题**：

- 应用启动时需要较长时间初始化（如加载大数据、连接外部服务）
- 临时不可用状态（如与数据库连接暂时丢失）
- 防止在应用未准备好时向其发送请求

**Kubelet响应**：

- 探测失败 → 从Service的端点列表中移除该Pod，停止向其发送流量
- 探测成功 → 将Pod重新加入端点列表
- 目的是确保流量只被路由到真正准备好的Pod

### 3、startupProbe[启动探针]

**作用**：检测容器应用是否已启动完成。这是Kubernetes 1.16+引入的新探针。

**解决的问题**：

- 处理启动非常缓慢的容器（如遗留系统或Java应用）
- <span style="color:red">避免在启动过程中因livenessProbe失败而导致频繁重启 </span>
- 替代原先通过设置较大`initialDelaySeconds`的临时方案

**Kubelet响应**：

- 在startupProbe成功之前，其他探针(liveness/readiness)不会启动
- 如果探测失败 → 根据配置的重试次数，最终kubelet会杀死容器并重启它
- <span style="color:red">目的是给慢启动应用足够的启动时间</span>

## 3、Probe探测具体执行的途径

```yaml
$探测途径:
  initialDelaySeconds: 3  #3秒后开始探测
  successThreshold: 1  #探测成功1次就算通过
  failureThreshold: 3  #探测3次失败算检测未通过
  periodSeconds: 3  #3秒检测一次
```

### 1、 HTTP GET请求探测 (httpGet)

**工作原理**：
向容器内指定端口和路径发送HTTP GET请求，通过响应状态码判断是否健康

**配置参数**：

- `port`: 容器暴露的端口号或端口名称
- `path`: HTTP访问路径(如/healthz)
- `httpHeaders`: 自定义HTTP头(可选)
- `scheme`: HTTP或HTTPS(默认为HTTP)

**成功条件**：
返回HTTP状态码在200-399之间

```yaml
      # 就绪探针, 解决的问题是, 是否将此Pod加入到对应service后端提供服务
      readinessProbe:
        httpGet:
          port: 80
          #host: localhost
          path: /
        initialDelaySeconds: 3
        periodSeconds: 3
        successThreshold: 1
        failureThreshold: 3
```

### 2、ExecAction  执行容器命令探测(exec)

**工作原理**：
在容器内执行指定的命令，通过命令的退出状态码判断是否健康

**配置参数**：

- `command`: 要执行的命令及其参数数组

**成功条件**：
命令退出状态码为0



如果超时:   `$initialDelaySeconds + ($failureThreshold * $periodSeconds) = 10+3x3=19s ` 超过这个时间，startupProbe还没通过，  那么， 则按照restartPolicy来执行容器重启操作.

前提:       

​	command执行成功，并且可以得到exit退出码.   如果连命令都不存在，就无法谈起exit退出码， 那么就等于 失败次数计数为 0，  成功计数为0  ，  则这个探测会一直持续下去，  也不会重启容器， 也不会进入后续 `就绪探针`  `存活探针`的检测， 一直循环下去.

​	所以， command命令，一定要写对， 至少能拿到exit退出码

```yaml
      # 启动探针, 解决的问题是, 针对慢启动应用, 先通过startupProbe的测试, 再进入后续
      # 就绪探针和存活探针的拨测, 防止启动过慢,导致存活探针过早探测失败,频繁重启
      startupProbe:
        exec:
          command:
            - "ss -lntp | grep "
        initialDelaySeconds: 10  #延迟多少秒 初始化启动探针
        periodSeconds: 3         #探测频率
        successThreshold: 1      #多少次探测成功, 则标记为成功
        failureThreshold: 3      #多少次探测失败, 则标记为失败
```

### 3、TCP SocketAction tcp端口连接探测()

**工作原理**：
尝试与容器指定的端口建立TCP连接

**配置参数**：

- `port`: 容器暴露的端口号或端口名称

**成功条件**：
能够建立TCP连接(端口已打开)

```yaml
      # 存活探针, 解决的问题是, 如进程"假死"、"僵尸进程"等问题,虽然进程存在,但是无法正常提供服务了
      # kubelet 检测到, 会杀死容器, 然后根据restartPolicy策略进行重启"抢救"
      livenessProbe:
        tcpSocket:
          port: 80
          #host: localhost
        initialDelaySeconds: 3
        periodSeconds: 3
        successThreshold: 1
        failureThreshold: 3
        
```

### 4、gRPC 健康检测 (grpc)

用途：专为 gRPC 服务设计的健康检查，直接调用 gRPC 健康检查协议（无需暴露 HTTP 接口）。

和HTTP GET方式差不多， 只是这个是针对gRPC协议， HTTP GET是针对HTTP协议













