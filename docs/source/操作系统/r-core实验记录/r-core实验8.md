# 🐧r-core实验8线程

## 新知识的介绍

```{note}
线程:一个进程中的一个函数他的特点
- 1. 有自己的pid,也就是说一个程序创建多个线程的话他的子线程都有自己的pid
- 2. 他其实是task,他里面的process是召唤他的程序
- 3. 一个线程和召唤他的线程是共享几乎所有东西的,只有`pc`和`sp`不一样
    - 注意这里栈是相同的,就是栈顶指针可以有偏移
```

## 关于现在的process总结
```{important}
一般我们都是把一个结构体不变的部分直接贴到这个结构体指针附近,变化的东西会使用一个UPSafeCell变成inner,这样是为了适应rust的法则
,这个其实是因为rust的保护机制,我们不想要给跨线程的共享变量加锁,所以只能这样操作(其实是没有必要枷锁,因为我们只有一个cpu,不可能同时操作这个结构),也就是cpu在操作内核相关的结构的时候不像用户程序那样可能被时钟打断
```

### 1. ProcessControlBlock,是一个进化,因为进程要和线程区分开来

> 首次出现是在`ch8b_initproc`创建的时候,为第一个守护进程(负责一系列的资源回收)创建一个任务的相关信息


- 他的创建是根据一个elf文件创建,把各个段的信息直接放到memory_set里面

```rust
pub struct ProcessControlBlock {
    /// immutable
    pub pid: PidHandle,
    /// mutable
    inner: UPSafeCell<ProcessControlBlockInner>,
}

pub struct ProcessControlBlockInner {//inner部分
    /// is zombie?
    pub is_zombie: bool,
    /// memory set(address space)
    pub memory_set: MemorySet,
    /// parent process
    pub parent: Option<Weak<ProcessControlBlock>>,
    /// children process
    pub children: Vec<Arc<ProcessControlBlock>>,
    /// exit code
    pub exit_code: i32,//变为zombi的时候回收读取
    /// file descriptor table
    pub fd_table: Vec<Option<Arc<dyn File + Send + Sync>>>,
    /// signal flags
    pub signals: SignalFlags,
    /// tasks(also known as threads)
    pub tasks: Vec<Option<Arc<TaskControlBlock>>>,
    /// task resource allocator
    pub task_res_allocator: RecycleAllocator,
    /// mutex list
    pub mutex_list: Vec<Option<Arc<dyn Mutex>>>,
    /// semaphore list
    pub semaphore_list: Vec<Option<Arc<Semaphore>>>,
    /// condvar list
    pub condvar_list: Vec<Option<Arc<Condvar>>>,
}

pub fn new(elf_data: &[u8]) -> Arc<Self> {
    trace!("kernel: ProcessControlBlock::new");
    // memory_set with elf program headers/trampoline/trap context/user stack
    let (memory_set, ustack_base, entry_point) = MemorySet::from_elf(elf_data);
    // allocate a pid
    let pid_handle = pid_alloc();
    let process = Arc::new(Self {
        pid: pid_handle,
        inner: unsafe {
            UPSafeCell::new(ProcessControlBlockInner {
                is_zombie: false,
                memory_set,
                parent: None,
                children: Vec::new(),
                exit_code: 0,
                fd_table: vec![
                    // 0 -> stdin
                    Some(Arc::new(Stdin)),
                    // 1 -> stdout
                    Some(Arc::new(Stdout)),
                    // 2 -> stderr
                    Some(Arc::new(Stdout)),
                ],
                signals: SignalFlags::empty(),
                tasks: Vec::new(),
                task_res_allocator: RecycleAllocator::new(),
                mutex_list: Vec::new(),
                semaphore_list: Vec::new(),
                condvar_list: Vec::new(),
            })
        },
    });
    // create a main thread, we should allocate ustack and trap_cx here
    let task = Arc::new(TaskControlBlock::new(
        Arc::clone(&process),
        ustack_base,
        true,
    ));
    // prepare trap_cx of main thread
    let task_inner = task.inner_exclusive_access();
    let trap_cx = task_inner.get_trap_cx();
    let ustack_top = task_inner.res.as_ref().unwrap().ustack_top();
    let kstack_top = task.kstack.get_top();
    drop(task_inner);
    *trap_cx = TrapContext::app_init_context(
        entry_point,
        ustack_top,
        KERNEL_SPACE.exclusive_access().token(),
        kstack_top,
        trap_handler as usize,
    );
    // add main thread to the process
    let mut process_inner = process.inner_exclusive_access();
    process_inner.tasks.push(Some(Arc::clone(&task)));
    drop(process_inner);
    insert_into_pid2process(process.getpid(), Arc::clone(&process));
    // add main thread to scheduler
    add_task(task);
    process
}

```
- 一个pross是不足够的,因为他没有保存上下文的`tss`结构,也没有相应的`中断/任务切换`的时候使用的相关信息
    - 所以他需要被包装在`TaskControlBlock`中,这个结构才能被操作系统管理
    - 把procss独立出来是为了给这个task实现添加线程的操作

```rust
pub struct TaskControlBlock {
    /// immutable
    pub process: Weak<ProcessControlBlock>,//这个task当前在跑的procss
    /// Kernel stack corresponding to PID
    pub kstack: KernelStack,//这个task对应的内核栈
    /// mutable
    inner: UPSafeCell<TaskControlBlockInner>,
}
pub struct TaskControlBlockInner {
    pub res: Option<TaskUserRes>,
    /// The physical page number of the frame where the trap context is placed
    pub trap_cx_ppn: PhysPageNum,//trap的时候内核用来切换的信息,这个会丰富点
    /// Save task context
    pub task_cx: TaskContext,//简化版本的,只是保存返回信息还有内核栈指针,还有12个基础寄存器的

    /// Maintain the execution status of the current process
    pub task_status: TaskStatus,//内核管理是进程信息
    /// It is set when active exit or execution error occurs
    pub exit_code: Option<i32>,
}

pub struct TaskUserRes {
    /// task id
    pub tid: usize,
    /// user stack base
    pub ustack_base: usize,//记录这个task的用户栈
    /// process belongs to
    pub process: Weak<ProcessControlBlock>,//在跑的线程
}
```
- 初始化一个进程的时候内核做的:
  - 1. 根据程序的elf信息加载出memory_set,每个用户对应的内核栈,程序最开始要进入的地址
  - 2. 分配一个pid
  - 3. 设置他的父亲进程,儿子进程,文件描述符号(初始化的是stdin,stdout,stdcerr)
  - 4. 设置信号信息?//待考证
  - 5. 使用`TaskControlBlock`包装,确保内核的调度可以把他轮转起来
    - 当然这个仅仅是保存内核轮转需要的信息,进程/线程需要的信息还是在process里面
  - 6. 设置最开始的trap信息,

```{note}
现在有三种栈,内核自己的栈,用户程序(线程/进程)的栈,用户程序可以访问的内核栈(这个和内核栈完全独立)
```

### 2. PID2PCB

> 底层是一个btree,构建一个pid到进程的映射

### 3. TASK_MANAGER

> 用来维护调度的

```rust
pub struct TaskManager {
    ready_queue: VecDeque<Arc<TaskControlBlock>>,
    
    /// The stopping task, leave a reference so that the kernel stack will not be recycled when switching tasks
    stop_task: Option<Arc<TaskControlBlock>>,//目前意义不明
}
```


### 4. Processor

> 维护跳转的时候的内核的上下文,还有当前在

```{note}
为什么说idle_task_cx是内核的上下文呢?
- 他都是在每次内核态和用户态发生切换的时候被使用的,
    - 内核态到用户态:具体可以看`__switch`,
    - 用户态到内核态:我们是使用虚拟地址倒数第二个页面来保存这个函数,也就是`strampoline`->`.text.trampoline`->`__alltraps`函数
```

```rust
pub struct Processor {
    current: Option<Arc<TaskControlBlock>>,

    ///The basic control flow of each core, helping to select and switch process
    idle_task_cx: TaskContext,
}
```

## 关于线程的创建

```{note}
到目前为止,操作系统已经能轮转起来了,接下来需要他能实现让进程创建线程的系统调用
- 这个部分还有关于一系列的锁的问题都是靠系统调用来完成的
```

### 1. sys_thread_create

```{important}
有了线程的概念之后,我们知道一个程序process他可以有很多个任务task,但是他对应的资源(从elf加载出来之后就锁定的那部分),只有一份
- 为了方便管理,我们把task的东西都存在process里面,因为process才是唯一的,被共享的那个
  - 这里task只是持有process的weak指针,也就是说task是不负责process的生命周期的
- 同一个程序召唤出来的线程都绑定同一个process,但是他们至少pc是不一样的,所以task内部还要有自己的资源
  - 这里其实trapreturn啥的也都是独立的
  - 
```
- 关于一个程序召唤出来的线程持有的所有资源

```rust
pub struct TaskUserRes {
    /// task id
    pub tid: usize,//这个是process分配的
    /// user stack base
    pub ustack_base: usize,//这个其实是复制的召唤他的task的,所以也是共享的,但是可以不一样就是是同一个栈,但是可以指向不一样的地方
    /// process belongs to
    pub process: Weak<ProcessControlBlock>,
}

```

## 锁机制
```{note}
由于一个process的所有线程共享几乎所有的资源(只有pc和sp不一样),那么数据竞争的问题就必须被考虑
- ps:数据竞争是因为对数据的操作是存在`临界区`的,也就是完成一个数据操作对应的指令可能不只一条
```text
// 线程的入口函数
int a=0;
void f() {
  a = a + 1;
}
//对应的汇编
lui       a5,%hi(a)
lw        a5,%lo(a)(a5)
addiw     a5,a5,1
sext.w    a4,a5
lui       a5,%hi(a)
sw        a4,%lo(a)(a5)
```

**关于锁的几个操作**
- 1. 创建锁(锁是一个id,他实际上是由process维护的一个队列)
- 2. 锁对应一个区域,里面的操作无所谓,我们不管(也就是说必须由用户把变量放在锁区域里面操作,他在锁外面操作我们不负责)
- 3. 上锁
- 4. 解锁

- 几个rust的关键实现

```rust
pub trait Mutex: Sync + Send {//锁的底层需求,本质锁只是一个接口
    /// Lock the mutex
    fn lock(&self);
    /// Unlock the mutex
    fn unlock(&self);
}

pub struct MutexSpin {//拿不到就正常跳走
    locked: UPSafeCell<bool>,
}
impl Mutex for MutexSpin {
    /// Lock the spinlock mutex
    fn lock(&self) {
        trace!("kernel: MutexSpin::lock");
        loop {
            let mut locked = self.locked.exclusive_access();
            if *locked {
                drop(locked);
                suspend_current_and_run_next();
                continue;
            } else {
                *locked = true;
                return;
            }
        }
    }
}

pub struct MutexBlocking {//拿不到直接跳出去,把当前线程(task)加入到wait_queue
    inner: UPSafeCell<MutexBlockingInner>,
}


impl Mutex for MutexBlocking {
    /// lock the blocking mutex
    fn lock(&self) {
        trace!("kernel: MutexBlocking::lock");
        let mut mutex_inner = self.inner.exclusive_access();
        if mutex_inner.locked {
            mutex_inner.wait_queue.push_back(current_task().unwrap());
            drop(mutex_inner);
            block_current_and_run_next();
        } else {
            mutex_inner.locked = true;
        }
    }
}

pub struct MutexBlockingInner {
    locked: bool,
    wait_queue: VecDeque<Arc<TaskControlBlock>>,
}

```
**MutexSpin和MutexBlocking的区别是获取锁之后是把当前task加入ready_queue还是blocked_queue**
- 关于blocked_queue需要先了解条件变量机制


## 信号机制

### 课上说的那个信号量,底层也是由`process`维护的一个队列
```rust
pub struct SemaphoreInner {
    pub count: isize,
    pub wait_queue: VecDeque<Arc<TaskControlBlock>>,
}
```
- 可以是负数是因为来一个线程请求的时候都会让信号量减1
  - 有完成的操作都会让信号量加一然后从队列顶拿出来一个task执行

##  条件变量机制
- 首先有必要看一个情景
```rust
static mut A: usize = 0;
unsafe fn first() -> ! {
    mutex.lock();
    A=1;
    mutex.unlock();
    ...
}

unsafe fn second() -> ! {
    mutex.lock();
    while A==0 {
        mutex.unlock();
        // give other thread a chance to lock
        mutex.lock();
    };
    mutex.unlock();
    //继续执行相关事务
}
```
- 如果`second`先执行然后`first`再执行,那么实际上second的锁会干扰first的执行,这个干扰是没有意义的,因为他就算拿到锁了也得解锁先让`first`去改变A的值
  - 这个例子可能不显然,其实比如相机和主线程共享一个`RGB_buffer`,那么其实如果他空的话主线程拿这个锁是没有意义的,因为主线程就算拿了锁也得等相机拿到锁去更新图像

- 具体的实现其实就是一个由process维护的队列
```rust
pub struct Condvar {
    /// Condition variable inner
    pub inner: UPSafeCell<CondvarInner>,
}

pub struct CondvarInner {
    pub wait_queue: VecDeque<Arc<TaskControlBlock>>,
}
```


## 作业部分:

### 死锁的一个例子

- 线程 T1：
  - lock(A)
  - lock(B)

- 线程 T2：
  - lock(B)
  - lock(A)

**当执行顺序是:**
- 1. T1 成功 lock(A)
- 2. T2 成功 lock(B)
- 此时就开始死锁,因为`T1`在尝试lock(B),他在等待`T2`放锁
- 而`T2`也在等`T1`放锁,这个时候他们两个会都让出时间片,导致都不能继续执行

### 死锁检测算法的目的

> 在上述例子中就是`T2` 尝试 lock(B)的时候系统直接拒绝,然后让下一个线程先跑(直接认为`T2`尝试获取锁失败)


### 本次的死锁检测算法(银行家算法)

**使用的数据结构:**
- 1. `Available[j] = k`：第 `j` 类资源当前还剩 `k` 个可分配的实例。(资源的空闲)
- 2. `Allocation[i, j] = g`：线程 `i` 已经拿到了第 `j` 类资源 `g` 个实例。(现有的资源分配)
- 3. `Need[i, j] = d`：线程 `i` 还需要第 `j` 类资源 `d` 个实例，才能“顺利执行到结束”。(由于我们不知道一个进程还需要多少资源,所以我们初始化为max-allocation)

```{note}
算法其实是采取一种贪心的策略来判断是否会发生死锁
- 贪心的点在于:如果批准了当前线程的这个请求,把现在所有的剩余资源都给他,能不能让每一个进程都结束工作
- 关于会不会因为这个判定导致一个线程始终拿不到资源:
  - 其实当死锁发生的时候本身就是两个线程在竞争资源,用户在设计的时候就应该保证一个资源不那么频繁得被一个线程获取
  - 本身发生死锁就是用户设计不好,但是这个情况确实有时候不能从用户端避免
  - 上述情况发生于T1不断占有锁A(比如while循环,而且相当高频), 导致每一次T2请求B的锁的时候都会被拦住,T2进行不下去
  - 但是这个是用户的问题,用户应该表征T1执行不那么高频
```


**算法引入两个运行时变量：**

- Work（工作向量）

`Work` 是一个临时向量，表示“**假设**我们可以把当前可用资源都拿来分配”，系统在模拟过程中能提供的资源量。
初始化：`Work = Available`

- Finish（结束标志）

`Finish[i]` 表示“在这次模拟里，我们能否让线程 i 最终完成并释放资源”。
初始化：全部 `false`

**算法步骤逐条解释**

#### 步骤 A：找“现在就能完成”的线程

从所有还没标记完成的线程里找一个 `i`，满足：

1. `Finish[i] == false`（还没被证明能完成）
2. 对所有资源类型 `j`：`Need[i, j] <= Work[j]`

这句话的意思是：

> 以当前 `Work` 代表的可分配资源量来看，线程 i 剩下缺的资源都能一次性满足，那么它就可以继续运行并最终结束。

#### 步骤 B：假装给它资源、让它跑完、回收它占用的资源

一旦找到这样的线程 `i`，我们在模拟中认为：

* 它会拿到所需资源，执行结束
* 结束后会释放它**当前占有的资源**（`Allocation` 里的那些）

所以更新：

* `Work[j] = Work[j] + Allocation[i, j]`
* `Finish[i] = true`

然后回到步骤 A 再找下一个能完成的线程。

#### 步骤 C：结束判定

* 如果最终所有 `Finish[i]` 都能变成 `true`：说明存在一个“完成顺序”（安全序列），系统处于**安全状态**。
* 如果卡住了：找不到任何线程满足 `Need <= Work`，但还有线程 `Finish=false`：说明系统处于**不安全状态**（可能死锁或即将死锁）。

注意关键点：

* “不安全”不等于“此刻已经死锁”，而是“如果继续这么分配，可能导致无法让所有线程都完成”。为了“检测并预防”，系统会拒绝导致不安全的资源请求。
