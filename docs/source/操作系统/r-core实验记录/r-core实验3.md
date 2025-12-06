# 🐧r-core实验3
```{note}
本章节有一个时钟中断,现在就可以知道其实计算机是有一个时钟模块来计时的,他每秒钟都会执行固定个周期
```rust
pub fn set_timer(timer: usize) {
    sbi_call(SBI_SET_TIMER, timer, 0, 0);
}//时间到这个周期数量他就触发硬件中断
use crate::config::CLOCK_FREQ;//获取一秒多少个周期
const TICKS_PER_SEC: usize = 100;
pub fn set_next_trigger() {
    set_timer(get_time() + CLOCK_FREQ / TICKS_PER_SEC);
}
```

## 关于全局变量TASK_MANAGER

- 先来看他的定义

```rust
lazy_static! {
    /// Global variable: TASK_MANAGER
    pub static ref TASK_MANAGER: TaskManager = {
        let num_app = get_num_app();
        let mut tasks = [TaskControlBlock {
            task_cx: TaskContext::zero_init(),
            task_status: TaskStatus::UnInit,
        }; MAX_APP_NUM];
        for (i, task) in tasks.iter_mut().enumerate() {
            task.task_cx = TaskContext::goto_restore(init_app_cx(i));
            task.task_status = TaskStatus::Ready;
        }
        TaskManager {
            num_app,
            inner: unsafe {
                UPSafeCell::new(TaskManagerInner {
                    tasks,
                    current_task: 0,
                })
            },
        }
    };
}
```

- 他什么时候被初始化?
> 第一次被使用的时候也就是调用`pub fn run_first_task() { TASK_MANAGER.run_first_task();}`的时候
> 这个是lazy_static!宏的一个特性,他可以把你定义的一个变量搞成那种在第一次引用的时候初始化的变量

## 关于时钟中断

### 我怎么看不到中断表???
- risc-v的中断不需要中断表而是:
  -  1. 把 **stvec**（或 mtvec）设置成一个**统一的 trap 入口函数**；
  -  1. 在这个入口里根据 **scause** 区分：这是时钟中断？系统调用？页错误？
  -  2. 如果是时钟中断，就调用你写的“时钟中断处理逻辑”。
- 总结一下,所有的中断都是同一个函数!!!函数的地址保存在寄存器stvec里面
- 然后我们的汇编就是保存寄存器,做到从用户态转到内核态,最后调用函数trap_handler

```{note}
总结一下和trap相关的寄存器
- `scause`:表示trap的信息,可以是原因
- `stval`:表示trap附加的参数信息

```

## 关于搬迁应用程序的部分

- 先看代码

```rust
let src = unsafe {
    core::slice::from_raw_parts(app_start[i] as *const u8, app_start[i + 1] - app_start[i])
    //汇编里面定义了这个地址是要放用户代码的,论段来说这个内存是位于内核程序的.data段
    //这个数组里面的元素是.data段里面的数据
};
let dst = unsafe { core::slice::from_raw_parts_mut(base_i as *mut u8, src.len()) };
dst.copy_from_slice(src); //copy到一个地址,地址是从上面算出来的,我设计过这个内存不会干涉其他的代码

```
### **补充一个特殊的数据结构`mut[u8]`,他是一个slice**

```rust
let dst: &mut [u8] = unsafe {
    core::slice::from_raw_parts_mut(base_i as *mut u8, src.len())
};
```
- 包含一个地址和一个长度,本例中用到的方式是`copy_from_slice`,这个类似一个memcopy


## 疑问汇总

### **1. 我看不懂汇编的循环怎么办?**
- 好的好的,我会出手
```s
.set n, 5
.rept 27
    SAVE_GP %n
    .set n, n+1
.endr

SAVE_GP是一个宏
.macro SAVE_GP reg
    sd x\reg, \reg*8(sp)
.endm
```

### **2. risc-v寄存器有多少个?为什么有时候叫`x2` `sp`?**

- 这里需要介绍risc-v的寄存器:
  - 主要分为`整数寄存器`还有`浮点寄存器`,`向量寄存器`,`状态寄存器`等等
  - 各个寄存器还有自己的功能名字还有硬件名字,比如`x2`的功能名字就是`sp`,他是栈寄存器,但是在硬件实现上排第二个
  - 写汇编的时候可以`sp`和`x2`混用,不会影响的
- 简单收集一些整数寄存器
  * `x0` → `zero`（永远是 0）
  * `x1` → `ra`（return address）
  * `x2` → `sp`（stack pointer）
  * `x3` → `gp`（global pointer）
  * `x4` → `tp`（thread pointer）
  * `x5~x7` → `t0~t2`（temporaries）
  * `x8~x9` → `s0/fp, s1`（saved regs / frame pointer）
  * `x10~x17` → `a0~a7`（arguments / return values）
  * `x18~x27` → `s2~s11`（saved regs）
  * `x28~x31` → `t3~t6`（temporaries）


### **3. 我不会rust的模块引用怎么办**
- 小事,我从rust的行为说起
```rust
pub mod trace;//比如在src/main.rs里面制定这一行
```
- `rust`会先:
  - 找`src/trace.rs`
  - 或者`src/trace/mod.rs`
- 其实模块还可以内联
  ```rust
    mod trace {
        pub fn hello() {
            println!("from trace");
        }
    }
  ```

```{note}
之后相当于是`trace.rs`里面的代码都像是在`main.rs`里面写的一样,rust还是挺高级的:)
```

### 4. 第一次任务调用的函数为什么回不去?反而是跳到用户代码执行了?
- ret的机制是返回ra指向的地址,但是函数内把他改了,当然就跳不回去了
```s
__switch:
    # __switch(
    #     current_task_cx_ptr: *mut TaskContext,
    #     next_task_cx_ptr: *const TaskContext
    # )
    # save kernel stack of current task
    sd sp, 8(a0)
    # save ra & s0~s11 of current execution
    sd ra, 0(a0)#可以和结构体对照着看
    .set n, 0
    .rept 12
        SAVE_SN %n
        .set n, n + 1
    .endr
    # restore ra & s0~s11 of next execution
    ld ra, 0(a1) #改ra了,所以ret会跳到对应任务去
    .set n, 0
    .rept 12
        LOAD_SN %n
        .set n, n + 1
    .endr
    # restore kernel stack of next task
    ld sp, 8(a1)
    ret


```

## 关于作业

- 使用`make run BASE=0`