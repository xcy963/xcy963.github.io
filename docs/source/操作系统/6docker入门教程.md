# 🐋docker入门
## 魔法传送门🚪
- <a href="#用vscode打开容器">用vscode打开容器</a>

## 一、Docker 是啥，能干嘛？

一句话版：

> Docker = 带“系统环境”的应用打包工具
> 👉 别人只要有 Docker，就能在任何机器上跑出**一模一样的环境**。

比如：

* 你在本机装了一堆 Rust、QEMU、各种库，搞好了 rCore 环境；
* 用 Docker 打成一个镜像；
* 别人只要 `docker run ...`，就直接拿到你这个环境，不用再自己折腾安装。

---

## 二、几个核心概念（一定要分清）

### 1. 镜像（Image）

* 类似于**系统 + 应用**的“快照模板”；
* 你可以从仓库拉现成的：`docker pull ubuntu:22.04`
* 也可以自己写 `Dockerfile` 再 `docker build` 构建。

> 类比：ISO 系统镜像。

### 2. 容器（Container）

* 用镜像**跑起来的一个实例**；
* 一个镜像可以起很多容器；
* 容器里的改动，默认只影响这个容器，不会改源镜像。
- 

> 类比：用一个系统安装盘装出好多虚拟机。

### 3. 仓库（Registry）

* 放镜像的地方，比如 Docker Hub；
* 用：`docker pull 镜像名`、`docker push 镜像名` 和它交互。

---

## 三、先玩几个最基础命令

假设 Docker 已经安装好了（`docker --version` 能跑）。

### 1. 跑个“Hello World”

```bash
docker run hello-world
```

它会做几件事：

1. 本地没这个镜像，就从公网拉一个 `hello-world`；
2. 用这个镜像启动一个容器，输出一段说明文字；
3. 容器跑完就退出。

### 2. 跑一个交互式的容器（像在一个小 Linux 里玩）

```bash
docker run -it --rm ubuntu:22.04 bash
```

参数解释：

* `ubuntu:22.04`：镜像名字:标签；
* `-it`：交互式终端（`-i` + `-t`），你能在里面敲命令；
* `--rm`：容器退出后自动删除；
* `bash`：进入容器后要执行的命令。

进到里面后，你看到的是**容器内部的文件系统和环境**，跟宿主机分开的。

---

## 四、容器常用操作

### 1. 查看容器

```bash
docker ps        # 正在运行的容器
docker ps -a     # 包括已经退出的容器
#这个和linux的ps很像
```

### 2. 停、启、删容器

```bash
docker stop <容器ID或名字>
docker start <容器ID或名字>
docker rm <容器ID或名字>
```

### 3. 看日志

```bash
docker logs <容器ID或名字>
```

### 4. 进入一个正在运行的容器

比如你有一个后台跑着的服务容器：

```bash
docker exec -it <容器ID或名字> bash
```

就能进到里面看文件、调试。

---

## 五、镜像相关命令

### 1. 列出本地镜像

```bash
docker images
```

### 2. 删除镜像

```bash
docker rmi <镜像ID或名字>
```

### 3. 从仓库拉镜像

```bash
docker pull ubuntu:22.04
```

---

## 六、自己写 Dockerfile + build 镜像
```{note}
其实可以把docker的命令写到makefile里面,这样运行的时候会更方便

```
这一步和你 `make build_docker` 关系最大。

假设你有一个最简单的 Python 项目：

**项目结构：**

```text
myapp/
  ├─ app.py
  └─ Dockerfile
```

`app.py`：

```python
print("Hello from Docker!")
```

`Dockerfile` 示例：

```dockerfile
# 1. 以官方 python 3.11 镜像为基础
FROM python:3.11

# 2. 设置工作目录
WORKDIR /app

# 3. 把当前目录的所有文件复制到容器的 /app
COPY . .

# 4. 容器启动时要执行的命令
CMD ["python", "app.py"]
```

在 `myapp` 目录里执行：

```bash
docker build -t my-python-app .
```

含义：

* `docker build`：根据当前目录的 Dockerfile 构建镜像；
* `-t my-python-app`：给镜像起名字 `my-python-app`；
* `.`：构建上下文，就是当前目录。

构建完成后：

```bash
docker run --rm my-python-app
```

就会输出：

```text
Hello from Docker!
```

---

## 七、数据 & 代码怎么跟本机共享？（卷挂载 -v）

你 Makefile 里这行：

```make
docker:
	docker run --network host --rm -it -v ${PWD}:/mnt -w /mnt ${DOCKER_NAME} bash
```

重点参数：

* `-v ${PWD}:/mnt`
  把**当前目录**挂载到容器里的 `/mnt` 目录：

  * 容器里 `/mnt` 看到的，就是你主机当前目录的内容；
  * 你在容器 `/mnt` 里改代码，实际就是改宿主机的文件。

* `-w /mnt`
  进入容器后，把工作目录直接设为 `/mnt`（也就是你的项目根），方便操作。

这个就是典型的“**用 Docker 提供环境，用宿主机保存代码**”模式，非常适合课程 / 竞赛 / 项目开发。

你也可以自己试：

```bash
docker run --rm -it -v $PWD:/mnt ubuntu:22.04 bash
# 进去以后
cd /mnt
ls  # 会看到你宿主机当前目录的文件
```

---

## 八、端口映射：让容器里的服务对外可见（-p）

如果你在容器里跑了个 Web 服务（例如监听 8080 端口），想用浏览器访问，就需要端口映射：

```bash
docker run -d --name web-test -p 8080:80 nginx
```

* `-p 宿主机端口:容器端口`
* 上面这行意思：
  把容器里的 80 端口映射到宿主机的 8080
  → 浏览器访问 `http://localhost:8080` 就能看到 nginx 欢迎页。

你 Makefile 里的 `--network host` 是更强的用法：
它让容器直接使用宿主机网络，不用映射端口，进阶时再研究也行。

---

## 九、回到你的项目：这三条命令在干嘛？

你的 `Makefile`：

```make
DOCKER_NAME ?= rcore-docker

docker:
	docker run --network host --rm -it -v ${PWD}:/mnt -w /mnt ${DOCKER_NAME} bash

build_docker: 
	docker build -t ${DOCKER_NAME} .
```

典型使用流程：

1. **第一次使用 / 环境变了：**

   ```bash
   make build_docker
   ```

   → 构建一个名为 `rcore-docker` 的镜像（里面装好了 rCore 开发所需的工具）。

2. **之后开发：**

   ```bash
   make docker
   ```

   等价于：

   ```bash
   docker run --network host --rm -it -v ${PWD}:/mnt -w /mnt rcore-docker bash
   ```

   → 进入一个*临时*容器，里面：

   * 已经有 Rust/工具链；
   * 当前项目文件挂到了 `/mnt`；
   * 你在里面 `cd os && make run` 就可以跑内核。

3. 容器退出后，因为有 `--rm`，容器自动删掉，镜像还在。

---

## 9.1Docker Compose的简单介绍

```{note}
docker compose可以用于定义和管理多个 Docker 容器的服务
```yaml
version: '3'
services:
  # 定义多个服务，每个服务都对应一个容器
  service_name:
    # 服务的具体配置
networks:
  # 定义网络
volumes:
  # 定义数据卷
```

- 如果想要容器开机自动启动，在compose的服务具体配置里加上`restart: always`

## 十、问题收集

### 1. 发现docker容器里面的bash程序提示词颜色不对
```bash
(ros_jazzy) hitcrt@hitcrt-OMEN:~/rust_learning/sphinx_doc$ bash
(ros_jazzy) hitcrt@hitcrt-OMEN:~/rust_learning/sphinx_doc$ echo "$PS1"
(ros_jazzy) \[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ 
```

```{note}
这里有conda的输出词,我们去掉(ros_jazzy) 留下后面`\[\e`开始的部分
```

- 然后在容器里面使用
```bash
export PS1='\[\e[0;32m\]\u@\h:\w\$ \[\e[0m\] '
```


```{tip}
如果使用的是Dockerfile创建容器,那么还可以在Dockerfile里面添加下面一行
```txt
RUN echo 'export PS1=" \[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$"' >> /root/.bashrc

```
<a id="用vscode打开容器"></a>
### 2. 我有一个容器里面安装了rust我要怎么在这个容器使用vscode的rust analyser
```{note}
其实其他的像是cpp的分析器也是通用的,我们这个相当于开一个vscode的远程服务器
```
- 在主页面创建.devcontainer/devcontainer.json

```json
{
  "name": "Rust in Docker",
  // 用你的镜像名；如果你本地开 VS Code 时有环境变量 DOCKER_NAME，
  "image": "rcore-docker",

  // 对应 --network host
  "runArgs": [
    "--network",
    "host"
  ],
  // VS Code 帮你挂载本机 workspace 到容器，这里我们手动指定成 /mnt
  // 对应你的 -v ${PWD}:/mnt 和 -w /mnt
  "workspaceFolder": "/mnt",
  "mounts": [
    "source=${localWorkspaceFolder},target=/mnt,type=bind"
  ],
  // 一般容器里是 root，如果你镜像里有别的用户可以改
  "remoteUser": "root",
  "customizations": {
    "vscode": {
      "extensions": [
        "rust-lang.rust-analyzer"
      ]
    }
  }
}

```

```{note}
之后想要在vscode里面打开ctrl + shift + p,输入 reopenInContainer
```

### 3. 容器有自己的磁盘吗？我如果不删除他他会有存储空间的浪费吗？

### 4. 容器可以使用compose文件管理,我使用命令怎么没用

- 要在对应的目录使用
```bash
docker compose down
docker compose up -d   # 这次只是为了按新配置重建一次
docker compose stop    # 停掉它
```