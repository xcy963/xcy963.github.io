# 💾r-core实验4虚拟内存空间-看一遍源码

```{note}
本页记录看一遍源码遇到的问题，应用程序的部分可以看作直接把应用程序编译成的elf拿过来,可以放在最后分析下elf
```

## 1 `KERNEL_SPACE`初始化的时候,映射`map_trampoline`
- 也就是映射trap的处理函数

```rust
fn map_trampoline(&mut self) {
    self.page_table.map(
        VirtAddr::from(TRAMPOLINE).into(),//虚拟地址是每个程序统一的最高位
        PhysAddr::from(strampoline as usize).into(),//这个是物理地址,详细参考ld脚本
        PTEFlags::R | PTEFlags::X,
    );
}
```
- 下面解释`strampoline`是什么

```rust
extern "C" {
    //省略号
    fn strampoline();//可以看出来是从汇编来的,搜索strampoline
    //说明这个机制:这句话只是在 Rust 这边声明「有一个名字叫 strampoline 的符号，调用约定是 C，签名是 fn()」。
    //编译器会认为它是一个外部函数，链接阶段用这个名字去找符号：恰好在 linker script 里定义了 strampoline，所以会被解析到你上面那个地址常量。
}

```

```txt
//出自linker.ld
.text : {
    *(.text.entry)
    . = ALIGN(4K);
    strampoline = .;//在rust里面获取到的符号是这个,也就是说我们把物理地址映射到下一行
    *(.text.trampoline);//ld脚本把别的汇编语言的.text.trampoline这个section放到strampoline下面
    . = ALIGN(4K);
    *(.text .text.*)
}

```
- 再次搜索

```txt
//出自trap/trap.s
    .section .text.trampoline
    .globl __alltraps
    .globl __restore
    .align 2
__alltraps:
```

- 破案了,最后我们设置的物理地址指向`__alltraps`

## 2 关于内核部分的虚拟地址空间

- 1 内核的页表支持整个地址空间的寻址
- 2 `MapType::Identical`和`MapType::Framed`的区别只是是否经过`frame_alloc`,还有ppn和vpn的映射关系,还有maparea 里面的b tree`data_frames`需不需要维护值
  - 恒等映射的好处是debug方便,虚拟地址一定连续(而且物理地址也连续),
  - `frame_alloc`是管理应用程序的,他其实不管内核
  - 为了节省,

```{important}
复习下这个操作系统的内存管理`MemorySet`
`
pub struct MemorySet {
    page_table: PageTable,
    areas: Vec<MapArea>,//用来分段
}
`

- 组成是一个页表,加上一个逻辑段,逻辑段用来定位使用了那部分内存,是一个从va到pa的映射
- 内核不使用MapArea,直接认为虚拟地址恒等于真实地址,好处如下
    - 内核需要能够访问所有的内存空间,使用恒等映射能推断所有的内存位置
    

```

```{error}
**内核的页表是恒等映射,但是仍然使用页表映射,这个不会浪费存储空间吗?**
- 可能是为了统一使用mmu做出的牺牲,但是这个是可以优化的地方

**内核页表映射了整个存储空间,那这个页表是不是相当巨大**
- 确实是映射了整个内存,但是页表似乎效率还行,分析一下
    - 内存从`0x80000000..0x88000000`一共128MB
    - `offset`一共12bit,也就是4kB使用一个`entry`
    - 一共需要32K个PTE,`SV39`是树结构,深度为4,节点数一共1+1+128+32k,每个节点是8B,大约是256KB
- 总结:只是使用几百KB,正常的操作系统会支持大页,会更小
- 说页表全满需要很大的内存,但是全开就能找到$2^{39}B = 2^{9}GB$,这么多使用几个G也正常


```

### 内核也是有几个段,但是开始初始化的时候似乎没有填入数据,那么是什么时候填入的呢?

> 根本不需要填入,他是恒等映射,所以就是映射到那个位置,在这之前对应地址上已经有bios拷贝好了的内核代码了

## 3 是怎么设置trap的

```{note}
根据我之前的理解,这个只需要设置寄存器`stvec`即可,下面简单介绍
- `Supervisor Trap Vector Base Address Register`,编号是0x105
    - stvec[1:0]   = MODE(分为direct / vectored)
    - stvec[XLEN-1:2] = BASE (以 4 字节对齐)
- 我们的操作系统统一是direct
```

- 之后内核态的跳转也就是设置寄存器

```rust
fn set_user_trap_entry() {
    unsafe {
        stvec::write(TRAMPOLINE as usize, TrapMode::Direct);
    }
}
```

## 4 TaskManager在这个阶段是什么

- 看相关定义
```rust
pub struct TaskManager {
    /// total number of tasks
    num_app: usize,
    /// use inner value to get mutable access
    inner: UPSafeCell<TaskManagerInner>,
    //本质是构造一个随处可以读写的副本,但是rust本身不允许这个事情发生,所以需要这样
}
struct TaskManagerInner {
    /// task list
    tasks: Vec<TaskControlBlock>,
    /// id of current `Running` task
    current_task: usize,
}

pub struct TaskControlBlock {
    /// Save task context
    pub task_cx: TaskContext,

    /// Maintain the execution status of the current process
    pub task_status: TaskStatus,

    /// Application address space
    pub memory_set: MemorySet,

    /// The phys page number of trap context
    pub trap_cx_ppn: PhysPageNum,

    /// The size(top addr) of program which is loaded from elf file
    pub base_size: usize,

    /// Heap bottom
    pub heap_bottom: usize,

    /// Program break
    pub program_brk: usize,
}

```

## 5 每个应用的初始化流程是什么

<img src="../../_static/img/操作系统/应用程序的内存分布.png" alt="img_miss" style="zoom: 70%;"/>

- 1. 创建最高位虚拟地址的映射
- 2. 建立每个段(Program Header)的虚拟地址(页表),还有填充内容
- 3. 设置用户栈,堆内存
- 4. 很重要的是map context,是进入trap之前的`tss`,这个段初始化的时候需要赋值

- 需要解释下app初始化的时候的TrapContext(内核栈),为此需要看一下内核的地址空间布局

<img src="../../_static/img/操作系统/内核地址布局.png" alt="img_miss" style="zoom: 70%;"/>

```{note}
**为什么内核栈(应用执行trap,进入内核态的时候使用的栈)不统一存放,而是每个应用程序一个呢?**
- 应用程序的页表里面不能放内核的段,不然应用程序就可以修改内核数据了,非常危险!
- 每个应用一个,而且放在他自己的地址空间,他就可以修改,而且不同应用隔离,就没有风险,而且这样还可以使用`内存空洞`来管理溢出的内核栈
```

```{important}
`内存空洞`:栈附近的保护page,只是发生在虚拟内存中,实际内存没有这个空洞
```


```{attention}
**xcy小问题1,内核在启用虚拟地址的时候寻址逻辑变化了,但是为什么我们的代码还是能连续执行不需要jump?TLB等cpu缓存里面的东西需要改变吗?**
- 内核的代码虚拟内存和物理内存是恒等的,访存只是中间加了一个页表
- 可以使用汇编`sfence.vma`来清除缓存

**xcy小问题2,内核把用户程序的那个内存块放在内存的哪里?这个时候开启虚拟地址了,那么是怎么管理的?**
- 之前使用管理器就发挥作用了`frame_alloc`来锁定页面,所以是在内核代码段之后,是帧管理器初始化的时候开的那些页面

```

## 6关于trap
```{note}
- **应用被初始化的时候需要怎么设置trap,让他从内核态进入用户态?**
- **应用本身trap的时候怎么进入内核态?**
- **怎么回来?**
- **任务切换是不是只需要栈指针和寄存器就ok了?**
```

### 具体过程1:第一个应用是怎么进入用户态的

- 1先标记任务状态是`TaskStatus::Running`
- 2读取任务的`task_cx`,这个之前使用`TaskContext::goto_trap_return`设置
```rust
/// Create a new task context with a trap return addr and a kernel stack pointer
pub fn goto_trap_return(kstack_ptr: usize) -> Self {
    Self {
        ra: trap_return as usize,//return address,这个是一个函数
        sp: kstack_ptr,  //stack pointer,这里是应用对应的内核栈
        s: [0; 12],//寄存器,先初始化为0
    }
}

```
-  调用`__switch`函数,这个写在汇编里面
-  
```text
__switch:
    # __switch(
    #     current_task_cx_ptr: *mut TaskContext,//这个是内存的一个指针,放在a0里面
    #     next_task_cx_ptr: *const TaskContext//这个是内存的一个指针,放在a0里面,顺序是ra sp s (返回地址 栈指针 寄存器)
    # )
    # save kernel stack of current task
    sd sp, 8(a0)
    # save ra & s0~s11 of current execution
    sd ra, 0(a0)
    .set n, 0
    .rept 12
        SAVE_SN %n
        .set n, n + 1
    .endr
    # restore ra & s0~s11 of next execution
    ld ra, 0(a1)
    .set n, 0
    .rept 12
        LOAD_SN %n
        .set n, n + 1
    .endr
    # restore kernel stack of next task
    ld sp, 8(a1)
    ret

```

- 执行过后其实就是跳转到`trap_return`函数
- trap_return只是设置用户态,然后远跳转`__restore`
```rust
pub fn trap_return() -> ! {
    set_user_trap_entry();
    let trap_cx_ptr = TRAP_CONTEXT_BASE;
    let user_satp = current_user_token();
    extern "C" {
        fn __alltraps();
        fn __restore();
    }
    let restore_va = __restore as usize - __alltraps as usize + TRAMPOLINE;//计算虚拟地址,之前把TRAMPOLINE的虚拟地址指向__alltraps
    //也就是构造出来restore_va的虚拟地址
    // trace!("[kernel] trap_return: ..before return");
    unsafe {
        asm!(//这段就是长跳转到__restore
            "fence.i",
            "jr {restore_va}",         // jump to new addr of __restore asm function
            restore_va = in(reg) restore_va,
            in("a0") trap_cx_ptr,      // a0 = virt addr of Trap Context
            in("a1") user_satp,        // a1 = phy addr of usr page table
            options(noreturn)
        );
    }
}
```
```text
__restore:
    # a0: *TrapContext in user space(Constant); a1: user space token
    # switch to user space
    csrw satp, a1  #切换虚拟内存模式为用户的,这个当作是把a1的值赋值给satp
    sfence.vma    #刷新cpu缓存
    csrw sscratch, a0 #交换内核上下文(内核栈),和用户栈的地址a0:内核栈
    mv sp, a0  #设置sp是内核栈指针
    # now sp points to TrapContext in user space, start restoring based on it
    # restore sstatus/sepc
    ld t0, 32*8(sp)
    ld t1, 33*8(sp)
    csrw sstatus, t0 #设置回哪里还有中断使能
    csrw sepc, t1    #跳转地址
    # restore general purpose registers except x0/sp/tp
    ld x1, 1*8(sp) #恢复用户寄存器
    ld x3, 3*8(sp)
    .set n, 5
    .rept 27
        LOAD_GP %n
        .set n, n+1
    .endr
    # back to user stack
    ld sp, 2*8(sp) #恢复用户栈指针
    sret

```

### 具体过程2:在用户态怎么切换,比如有trap发生?

在用户态记录trap的寄存器是`stvec(Supervisor Trap Vector Base Address Register)`

这个设置为`__alltraps`的地址,返回`rust写的trap_handler函数`