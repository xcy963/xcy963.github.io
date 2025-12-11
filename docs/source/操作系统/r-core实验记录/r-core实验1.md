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


## 关于编译

### 逆天他的makefile还能直接嵌套python
```python
os.system(
    "cargo rustc --bin %s %s -- -Clink-args=-Ttext=%x"
    % (app, mode_arg, base_address + step * app_id)
)
print(
    "[build.py] application %s start with address %s"
    % (app, hex(base_address + step * app_id))
)
#输出类似  [build.py] application ch2b_bad_address start with address 0x80400000
```

```{important}
这里还使用来python的字符串插入,python真是无敌了
"... %s %s ... %x" % (app, mode_arg, base_address + step * app_id)
- `%s`：把参数按字符串插进去

  - 第一个 %s → app（比如 ch2b_bad_address）

  - 第二个 %s → mode_arg（例如 --release 或者空）

- `%x`：把整数按 十六进制 输出，但 不带 0x 前缀，并且是小写字母

  - base_address + step * app_id = 0x80400000

  - %x 输出：80400000（没有 0x）

```
- 说明:

  - `-C` 是 `rustc` 的「编译器选项」前缀，`link-args` 表示：

  - 把后面的字符串原封不动传给底层的链接器（通常是 `ld`）

### 关于前三章的编译

#### **关于用户程序的编译**

```{note}
rust一般只是会生成一个elf文件比如在
`user/target/riscv64gc-unknown-none-elf/release/ch2b_bad_address`
- 可以使用`file ch2b_bad_address`查看他是不是elf,这个程序默认是linux可以直接运行的

但是我们的操作系统需要在内核的.data段存在一个应用程序的二进制编码,elf和二进制编码的区别主要是elf头
- 所以使用`$(OBJCOPY) $(elf) --strip-all -O binary $(patsubst $(TARGET_DIR)/%, $(TARGET_DIR)/%.bin, $(elf)); `
- 这样会生成一个bin文件
```

```{tip}
`patsubst` 是 `GNU Make` 内置的字符串替换函数，全名是 **pattern substitute（模式替换）**
$(patsubst <pattern>, <replacement>, <text>)
- 主要流程是
  - 在 `<text>` 这串单词列表里，逐个单词匹配 `<pattern>`
  - 凡是匹配到的，就用 `<replacement>` 按模式替换。

- `eg`:
```txt
SRC := foo.c bar.c baz.c
OBJ := $(patsubst %.c, %.o, $(SRC))
# 结果：OBJ = foo.o bar.o baz.o
cp $(elf) $(patsubst $(TARGET_DIR)/%, $(TARGET_DIR)/%.elf, $(elf));)
# 结果就是把${elf} cp 到原来目录.elf
```


#### **关于内核的编译**

- 主要是执行`build.rs`生成`link_app.S`,之后会被嵌入
- 

## 关于执行的流程

### 定义entry.asm
```{tip}
- `call`和`la`都是伪指令,这也解释了为什么call之后还能再回来eg`call rust_main`其实是`jal ra, rust_main`
- mangle是在把函数名编译到汇编时,编译成为乱七八糟的名字的那个选项
```

- 其实可以看一下这个汇编
```asm
    .section .text.entry
    .globl _start
_start:
    la sp, boot_stack_top #设置sp为栈顶高地址,确保在调用rust_main之后有栈可以用
    call rust_main

    .section .bss.stack
    .globl boot_stack_lower_bound
boot_stack_lower_bound: # <-- 栈底（低地址）
    .space 4096 * 16
    .globl boot_stack_top
boot_stack_top:     # <-- 栈顶（高地址）
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

## qemu模拟器简单介绍

### **启动指令**

- 在终端启动(从makefile里面复制出来)
```bash
	@qemu-system-riscv64 \
		-machine virt \
		-nographic \
		-bios $(BOOTLOADER) \
		-device loader,file=$(KERNEL_BIN),addr=$(KERNEL_ENTRY_PA)
```
```{note}
只要传入bios,内核二进制代码,内核入口地址,qemu模拟器就能自己启动.
这里要定义内核入口地址的原因是内核里面可能会有绝对地址或者段寄存器的设定,所以内核的入口要在这里
```


```txt
[rustsbi] RustSBI version 0.3.0-alpha.4, adapting to RISC-V SBI v1.0.0
.______       __    __      _______.___________.  _______..______   __
|   _  \     |  |  |  |    /       |           | /       ||   _  \ |  |
|  |_)  |    |  |  |  |   |   (----`---|  |----`|   (----`|  |_)  ||  |
|      /     |  |  |  |    \   \       |  |      \   \    |   _  < |  |
|  |\  \----.|  `--'  |.----)   |      |  |  .----)   |   |  |_)  ||  |
| _| `._____| \______/ |_______/       |__|  |_______/    |______/ |__|
[rustsbi] Implementation     : RustSBI-QEMU Version 0.2.0-alpha.2
[rustsbi] Platform Name      : riscv-virtio,qemu
[rustsbi] Platform SMP       : 1
[rustsbi] Platform Memory    : 0x80000000..0x88000000 #qemu分配的内存使用范围
[rustsbi] Boot HART          : 0 
[rustsbi] Device Tree Region : 0x87000000..0x87000ef2
[rustsbi] Firmware Address   : 0x80000000   #RustSBI 自己的地址：0x8000_0000
[rustsbi] Supervisor Address : 0x80200000   #内核地址
[rustsbi] pmp01: 0x00000000..0x80000000 (-wr) #Physical Memory Protection，物理内存保护
[rustsbi] pmp02: 0x80000000..0x80200000 (---) #（地址A..B 前闭后开）
[rustsbi] pmp03: 0x80200000..0x88000000 (xwr)
[rustsbi] pmp04: 0x88000000..0x00000000 (-wr)
[kernel] Hello, world!
root@hitcrt-OMEN:/mnt/os$ 
```
- x：execute（取指）
- w：write（写）
- r：read（读）

- `eg`: (-wr) = 可读写，不可执行；(---) = 啥也不允许。


- **之前linux0.00把内核代码搬到了内存最低位置啊,这里为什么内核在`0x80200000`?**
> 我们的内核还需要使用`rustabi`的代码,所以还不能卸磨杀驴,也就是说现在rustabi也是我们内核的一部分!


## 关于risc-v的特权机制


## 1. 基本的特权等级（Privilege Modes）

RISC-V 的核心规范里定义了几个**特权模式（Privilege Modes）**，从权限最高到最低是：

1. **M 模式（Machine Mode）**

   * 最高特权级
   * 通常跑在固件、bootloader、底层运行时（类似于“裸机”）
   * 可以访问所有 CSR 寄存器，控制中断、异常、物理内存映射等
   * 在很多简单的嵌入式场景中，系统甚至只用 M 模式，不需要操作系统

2. **S 模式（Supervisor Mode）**（可选）

   * 通常用来跑操作系统内核（类似 x86 的 ring 0）
   * 拥有对虚拟内存、页表等的控制，但部分底层硬件控制依然需要通过 M 模式
   * 比如 Linux on RISC-V 就是跑在 S 模式

3. **U 模式（User Mode）**

   * 普通应用程序所在的模式
   * 权限最低，不能直接访问特权寄存器、不能做 I/O 特权操作
   * 通过系统调用（ecall）陷入到 S 模式来请求服务

> 简化理解：
>
> * **M**：固件 / hypervisor / 最底层控制
> * **S**：操作系统内核
> * **U**：用户应用程序

## 2. 虚拟化相关的扩展模式（Hypervisor）

在支持虚拟化扩展（H 扩展）的 RISC-V 中，会引入更多“虚拟化后的”模式：

* **HS 模式**：Hypervisor Supervisor

  * 给 hypervisor 用的 “S 模式”，跑虚拟机监控器
* **VS / VU 模式**：Virtual Supervisor / Virtual User

  * 用来跑 “虚拟机中的内核”和“虚拟机中的用户程序”

你可以简单理解为，在有虚拟化时：

* M 模式：最底层，控制所有东西
* HS 模式：虚拟化宿主 OS / hypervisor
* VS / VU：虚拟机里的 S / U

## 3. 对比一下其它架构

* x86：常说的 ring 0（内核）、ring 3（用户）
* ARM：有 EL3（安全监控）、EL2（Hypervisor）、EL1（内核）、EL0（用户）

RISC-V 则是通过 M / S / U（再加上虚拟化扩展的 HS / VS / VU）来实现类似的层次结构。

