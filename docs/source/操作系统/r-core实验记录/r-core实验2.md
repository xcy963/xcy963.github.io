# 🐧r-core实验2

```{note}
`elf`与二进制文件:
正常rust编译器生成的文件是elf文件,便于linux操作系统执行,但是我们的目标是编译一个完整的操作系统,
所以我们需要的实际上是二进制文件,所以需要`@$(OBJCOPY) $(KERNEL_ELF) --strip-all -O binary $@`
```


## 应用程序的简单介绍

```{note}
在开始之前,需要介绍以下应用程序的基本概念,一般一个应用程序包含以下的段
高地址(地址字面数值大)
┌─────────────────┐
│    栈(stack)    │ ← 向下生长(栈指针都是做减法的)
├─────────────────┤
│      ...        │
├─────────────────┤
│     堆(heap)    │ ← 向上生长
├─────────────────┤
│    BSS段        │ ← 未初始化/零初始化数据
├─────────────────┤
│    .data段      │ ← 已初始化的全局/静态数据
├─────────────────┤
│    .rodata段    │ ← 只读数据（字符串常量等）
├─────────────────┤
│    .text段      │ ← 代码段
└─────────────────┘
低地址
```
### **各段具体内容示例：**

#### **.text 段（代码段）**
```cpp
// 所有函数代码都在这里
int add(int a, int b) {
    return a + b;
}

int main() {
    return add(1, 2);
}
```

#### **.rodata 段（只读数据）**
```cpp
// 字符串常量、const常量等
const char* msg = "Hello World";  // 字符串"Hello World"在.rodata
const int MAX_SIZE = 1024;        // 可能在.rodata或直接被编译器优化
```

#### **.data 段（已初始化数据）**
```cpp
// 非零初始化的全局/静态变量
int global_var = 100;                 // 在.data段
static int static_var = 200;          // 在.data段
char str[] = "hello";                 // 整个数组在.data段
std::string global_str = "test";      // 对象本身在.data段
```

#### **.bss 段（未初始化/零初始化数据）**
```cpp
// 以下都在.bss段
int uninit_var;                       // 未初始化
int zero_var = 0;                     // 初始化为0
int zero_array[100] = {0};            // 全零数组
char empty_str[1024];                 // 未初始化数组
static long static_uninit;            // 未初始化静态变量
```

### 一些疑问的解答

- **这些段是用什么段寄存器管理的?**
>  一般是 cs ds ss

- **链接的作用是什么?**
> 其实就是在合并不同程序生成的段,具体的合并方法是我们写在ld脚本里面的<a href="#ld脚本">一个ld脚本的示例</a>

- **我们cpp有符号表，但是最终的程序好像没有符号的概念啊**
> 理论上不开调试的话是不会编译符号表的,符号会转化成为全局地址,还有分段模型的概念

```{note}
有的同学会问，那么使用bss就可以避免这个128*4的字节开销吗？不是的，程序跑起来的时候bss就会开那么大，只是存储在磁盘上面的应用程序节约了
```

- **为什么要有bss段?直接使用可变的放data段,不可变的放rodata段不好吗?**
> 这样如果你开一个空间很大的数组(比如开`int a[128]`),那么生成的程序里面就需要128个0来存储这个数组,浪费4*128个字节。也许你还有疑问，那么为什么不省略？开一个符号，然后说这里要128*4个字节不就好了？那么恭喜你发明了bss段：）



## 1.第二章

### 1关于用户程序
```{note}
一般我们说的用户程序都是main函数不同,然后本实验还有用户程序需要使用的lib
也就是
- `user/src/bin`里面是编译main函数的行为的,
- `user/src/*.rs`是写给用户程序的库,还有系统调用啥的
- `user/src/linker.ld`是用户程序的布局说明,说明各个程序段的

```

- 用户程序的main其实是覆盖`lib.rs`里面的main
```rust
![feature(linkage)]    // 启用弱链接特性

[linkage = "weak"]
[no_mangle]
fn main() -> i32 {
    panic!("Cannot find main!");
}
```

- 他所谓的把程序写到`0x80400000`其实是用`build.py`实现的,在makefile里面调用

#### 用户程序的系统调用封装
```rust
fn sys_write(fd: usize, buf: *const u8, len: usize) -> isize;
//目的是使用系统调用把这个封装成库函数,类似标准库
```

- 具体的封装,本质是把汇编直接嵌入,从而在程序中使用系统调用

```rust
// user/src/syscall.rs
fn syscall(id: usize, args: [usize; 3]) -> isize {
  let mut ret: isize;
   unsafe {
      core::arch::asm!(
           "ecall",
           inlateout("x10") args[0] => ret,
          in("x11") args[1],
           in("x12") args[2],
           in("x17") id
      );
   }
   ret
}

// user/src/syscall.rs
const SYSCALL_WRITE: usize = 64; 
pub fn sys_write(fd: usize, buffer: &[u8]) -> isize {
    syscall(SYSCALL_WRITE, [fd, buffer.as_ptr() as usize, buffer.len()])
}


// user/src/lib.rs
use syscall::*;
pub fn write(fd: usize, buf: &[u8]) -> isize { sys_write(fd, buf) }
```

```{note}
小技巧:使用rust在汇编里面获取符号代表的数

```rust
fn clear_bss() {
    extern "C" {
        fn start_bss();//在链接的时候有代码
        /*    .bss : {
                    start_bss = .;
                    *(.bss .bss.*)
                    *(.sbss .sbss.*)
                    end_bss = .;
                }//创建全局符号,然后在rust里面把这个符号当成函数的指针,之后把他强行转化为usize指针就好,
                //这里是利用了函数入口是一个指针的基本事实进行强制转化
                
                */
        fn end_bss();
    }
    unsafe {
        core::slice::from_raw_parts_mut(
            start_bss as usize as *mut u8,
            end_bss as usize - start_bss as usize,
        )
        .fill(0);
    }
}
```

### 2关于内核



- **内核怎么知道要用哪些应用程序?**
> `os/build.rs`创建了一个应用程序的表`link_app.S`,然后使用AppManager进行管理,这里os没有文件系统,不能从磁盘加载,所以使用这个方式


```s
#link_app.S
_num_app:
    .quad 7
    .quad app_0_start

    .section .data
    .global app_0_start
    .global app_0_end
app_0_start:
    .incbin "../user/build/bin/ch2b_bad_address.bin"
app_0_end:

```

```{note}
cpu有个机制(就是缓存,amd擅长的那个小妙招),我们不同的应用程序的代码会放在同一块内存里面,(**似乎我们的操作系统还没有页表的概念**)
所以如果不清除cpu的缓存,那么cpu就不知道我们的内存被写了,他会乱执行代码
```

### trap机制
> 本质上是所有执行内核代码的总称,是操作系统的名词主要包括**异常**还有**中断**
发生trap的时候,硬件做的事情:
- 1. 写 `CSR`
   * `sepc` ← trap 发生前正在执行的那条指令的地址
   * `scause` ← trap 的原因（是系统调用？非法指令？page fault？中断？）
   * `stval` ← 附加信息（比如出错时访问的虚拟地址）
   * `sstatus.SPP` ← trap 前所处特权级（U 或 S）
   * `sstatus.SPIE/SIE` 等字段也会按规范变化（关中断 / 记录之前的中断开关状态）
- 2. **根据 `stvec` 跳转到内核的 trap 入口地址**
  * `stvec` 是你之前在内核初始化时设置的 trap 入口（一般指向一段汇编，比如 `__alltraps`）
  * `stvec` 本质是一个寄存器?那不就是`idtr`
    ```rust
    pub fn init() {
        extern "C" { fn __alltraps(); }
        unsafe {
        stvec::write(__alltraps as usize, TrapMode::Direct);
        }
    }
    ```
- 3. 本章的例子里面的`__alltraps`:保存寄存器器,然后调用`trap_handler`函数


## 后记

<a id="ld脚本"></a>

### 1. ld脚本

```ld
OUTPUT_ARCH(riscv)
ENTRY(_start)

BASE_ADDRESS = 0x0;

SECTIONS
{
    . = BASE_ADDRESS;
    .text : {
        *(.text.entry)
        *(.text .text.*)
    }
    . = ALIGN(4K);
    .rodata : {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
    }
    . = ALIGN(4K);
    .data : {
        *(.data .data.*)
        *(.sdata .sdata.*)
    }
    .bss : {
        start_bss = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        end_bss = .;
    }
    /DISCARD/ : {
        *(.eh_frame)
        *(.debug*)
    }
}
```

### 关于实现的那个println!
```rust
/// Println! to the host console using the format string and arguments.
#[macro_export]
macro_rules! println {
    ($fmt: literal $(, $($arg: tt)+)?) => {
        $crate::console::print(format_args!(concat!($fmt, "\n") $(, $($arg)+)?))
    }
}
//本质上还是调用rust的实现的格式化宏format_args!,
//

```

- `($fmt: literal $(, $($arg: tt)+)?)`表示是把输入的东西匹配成这个,第一个是literal也就是字符串,后面可以是很多个被,分开的字符
  - eg:`println!("x = {}, y = {}", x, y, z);`会被匹配为`console::print(format_args!(concat!("x = {}, y = {}", "\n"), x, y, z));`
  - concat会匹配`{}`把字符丢进去