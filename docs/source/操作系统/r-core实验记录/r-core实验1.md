# 🐧r-core实验1

```{note}
如果想要在容器里面打开vscode
- 先建立这个文件`.devcontainer/devcontainer.json`
- 里面写上
```json
{
  "name": "Rust in Docker",

  // 用你的镜像名；如果你本地开 VS Code 时有环境变量 DOCKER_NAME，
  "image": "rcore-docker",

  // 容器内的服务将与宿主机共享网络接口,这样容器内的可以直接访问宿主机的网络
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
"shutdownAction": "stopContainer",
  "customizations": {
    "vscode": {
      "extensions": [
        "rust-lang.rust-analyzer"
      ]
    }
  }
}

```





## 1.第一章

> 本章没啥东西,主要是入门,所以讲一讲实验的目录

```bash
|-- Dockerfile
|-- LICENSE
|-- Makefile
|-- README.md
|-- bootloader #存放qemu模拟器的bios程序
|-- ci-user    #检测工具的存放
|-- merge_chain.sh
|-- os          #我们写代码的地方
|-- rust-toolchain.toml
`-- user

4 directories, 6 files

```

- 下面重点介绍我们开发的内核

```bash
.
|-- Cargo.toml
|-- Makefile
`-- src
    |-- boards
    |   `-- qemu.rs
    |-- console.rs
    |-- entry.asm  #定义_start函数,嵌套调用rust函数
    |-- lang_items.rs #定义panic的行为,由于我们实现宏println!,所以这个是打印panic的信息
    |-- linker.ld #链接脚本
    |-- logging.rs 
    |-- main.rs #rust入口
    `-- sbi.rs
```

```{tip}
本章节只是引入,具体还是看后面的好些
```

```{danger}
在容器里面使用git会有意想不到的bug,还是尽量在宿主机里面做
```