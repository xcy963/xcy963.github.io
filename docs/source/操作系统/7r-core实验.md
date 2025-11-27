# 🐧r-core实验

```{note}
就是使用rust来完成linux内核的开发
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
    |-- entry.asm  #定义_start函数
    |-- lang_items.rs 
    |-- linker.ld #链接脚本
    |-- logging.rs 
    |-- main.rs #rust入口
    `-- sbi.rs
```