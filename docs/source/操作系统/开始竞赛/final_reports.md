# 最终报告

本报告从进程调度、内存管理、磁盘 ext4、系统调用四个方面介绍本操作系统的实现方式与设计思想。

## 进程调度

调度采用基于步长（stride）的公平调度思想。每个任务拥有优先级与累计步长，调度器维护就绪队列（BinaryHeap），每次取“步长最小”的任务运行，同时在取出时为其增加步长，保证长期公平。切换时由 Processor 维护当前任务与空闲上下文，通过 `__switch` 进行上下文切换。

关键流程：
- 新任务创建时初始化优先级与步长相关字段。
- 任务就绪后进入 TaskManager 的就绪队列。
- Processor 的 `run_tasks` 循环取出任务，更新状态并切换上下文。

关键结构体（源代码）：
```rust
pub struct TaskControlBlock {
    //task没有id了...
    /// immutable
    pub process: Weak<ProcessControlBlock>,
    /// Kernel stack corresponding to PID
    pub kstack: KernelStack,
    /// mutable
    inner: UPSafeCell<TaskControlBlockInner>,
}

pub struct TaskControlBlockInner {
    pub res: Option<TaskUserRes>,
    /// The physical page number of the frame where the trap context is placed
    pub trap_cx_ppn: PhysPageNum,
    /// Save task context
    pub task_cx: TaskContext,

    /// Maintain the execution status of the current process
    pub task_status: TaskStatus,
    /// It is set when active exit or execution error occurs
    pub exit_code: Option<i32>,
    /// Stride scheduling priority (bigger => more CPU time)
    pub priority: usize,
    /// Current accumulated stride
    pub stride: usize,
    /// Amount to add to stride whenever task is scheduled
    pub stride_pass: usize,
}

#[derive(Copy, Clone, PartialEq)]
/// The execution status of the current process
pub enum TaskStatus {
    /// ready to run
    Ready,
    /// running
    Running,
    /// blocked
    Blocked,
}
```

```rust
pub struct TaskManager {
    ready_queue: BinaryHeap<StrideEntry>,

    /// The stopping task, leave a reference so that the kernel stack will not be recycled when switching tasks
    /// 当主线程退出的时候,需要把task的指针保留一份ARC的在这里,不然rust会把他回收
    stop_task: Option<Arc<TaskControlBlock>>,
}

// A thin wrapper to keep the stride info in the scheduling heap.
struct StrideEntry {
    stride: usize,//这个和TaskControlBlock里面的变量同步吗?
    id: usize, //由于要适配线程,所以task不维护id了,我们使用task的地址来管理等于的情况
    task: Arc<TaskControlBlock>,
}
```

```rust
/// Processor management structure
pub struct Processor {
    current: Option<Arc<TaskControlBlock>>,

    ///The basic control flow of each core, helping to select and switch process
    idle_task_cx: TaskContext,
}
```

## 内存管理

内存管理由“物理页帧分配 + 页表映射 + 地址空间管理”三层组成：
- 物理页帧分配使用栈式分配器，支持回收复用；FrameTracker 采用 RAII，在释放时自动归还。
- 虚拟内存通过多级页表实现映射，页表项携带权限位。
- MemorySet 管理整个地址空间，MapArea 描述一段连续虚拟页的映射方式（恒等映射或分配页帧），并支持将 ELF 段按权限映射到用户空间。

关键结构体（源代码）：
```rust
/// tracker for physical page frame allocation and deallocation
pub struct FrameTracker {
    /// physical page number
    pub ppn: PhysPageNum,
}

pub struct StackFrameAllocator {
    current: usize,
    end: usize,
    recycled: Vec<usize>,
}
```

```rust
#[derive(Copy, Clone)]
#[repr(C)]
/// page table entry structure
pub struct PageTableEntry {
    /// bits of page table entry
    pub bits: usize,
}

/// page table structure
pub struct PageTable {
    root_ppn: PhysPageNum,
    frames: Vec<FrameTracker>,
}
```

```rust
/// address space
pub struct MemorySet {
    /// page table
    pub page_table: PageTable,
    /// areas
    pub areas: Vec<MapArea>,
}

pub struct MapArea {
    pub vpn_range: VPNRange,
    pub data_frames: BTreeMap<VirtPageNum, FrameTracker>,
    pub map_type: MapType,
    pub map_perm: MapPermission,
}

#[derive(Copy, Clone, PartialEq, Debug)]
pub enum MapType {
    Identical,
    Framed,
}

bitflags! {
    /// map permission corresponding to that in pte: `R W X U`
    pub struct MapPermission: u8 {
        ///Readable
        const R = 1 << 1;
        ///Writable
        const W = 1 << 2;
        ///Excutable
        const X = 1 << 3;
        ///Accessible in U mode
        const U = 1 << 4;
    }
}
```

## 磁盘 ext4

### 简单介绍

文件系统  借鉴了[ext4_rs](https://github.com/yuoo655/ext4_rs/issues)，内核通过块设备驱动提供读写能力，并在内核侧维护 inode 级抽象。OSInode 封装 inode 号与偏移，结合 OpenFlags 统一管理读写权限；Stat/StatMode 用于系统调用层返回文件属性。路径解析通过拆分父目录和遍历目录项完成，最终调用 ext4 的目录/文件接口。

关键结构体（源代码）：
```rust
/// inode in memory
pub struct OSInode {
    readable: bool,
    writable: bool,
    inner: UPSafeCell<OSInodeInner>,
}
/// inner of inode in memory
pub struct OSInodeInner {
    offset: usize,
    inode: u32,
}
```

```rust
bitflags! {
    ///  The flags argument to the open() system call is constructed by ORing together zero or more of the following values:
    pub struct OpenFlags: u32 {
        /// readyonly
        const RDONLY = 0;
        /// writeonly
        const WRONLY = 1 << 0;
        /// read and write
        const RDWR = 1 << 1;
        /// create new file
        const CREATE = 0x40;
        /// truncate file size to 0
        const TRUNC = 0x200;
        /// open directory
        const DIRECTORY = 0x10000;
    }
}
```

```rust
/// The stat of a inode
#[repr(C)]
#[derive(Debug)]
pub struct Stat {
    /// ID of device containing file
    pub st_dev: u64,
    /// inode number
    pub st_ino: u64,
    /// file type and mode
    pub st_mode: StatMode,
    /// number of hard links
    pub st_nlink: u32,
    /// owner uid/gid (always zero for now)
    pub st_uid: u32,
    /// owning group id (always zero for now)
    pub st_gid: u32,
    /// device type (unused)
    pub st_rdev: u64,
    /// padding reserved for future fields
    pub __pad: u64,
    /// total size, in bytes
    pub st_size: i64,
    /// blocksize for filesystem I/O
    pub st_blksize: u32,
    /// extra padding to mirror Linux layout
    pub __pad2: i32,
    /// number of 512B blocks allocated
    pub st_blocks: u64,
    /// timestamps (unused for now)
    pub st_atime_sec: i64,
    /// atime nanoseconds
    pub st_atime_nsec: i64,
    /// modification time seconds
    pub st_mtime_sec: i64,
    /// modification time nanoseconds
    pub st_mtime_nsec: i64,
    /// change time seconds
    pub st_ctime_sec: i64,
    /// change time nanoseconds
    pub st_ctime_nsec: i64,
    /// reserved space
    pub __unused: [u32; 2],
}

bitflags! {
    /// The mode of a inode
    /// whether a directory or a file
    pub struct StatMode: u32 {
        /// null
        const NULL  = 0;
        /// directory
        const DIR   = 0o040000;
        /// ordinary regular file
        const FILE  = 0o100000;
        /// user read
        const USER_READ = 0o400;
        /// user write
        const USER_WRITE = 0o200;
        /// user execute
        const USER_EXEC = 0o100;
        /// group read
        const GROUP_READ = 0o040;
        /// group write
        const GROUP_WRITE = 0o020;
        /// group execute
        const GROUP_EXEC = 0o010;
        /// other read
        const OTHER_READ = 0o004;
        /// other write
        const OTHER_WRITE = 0o002;
        /// other execute
        const OTHER_EXEC = 0o001;
    }
}
```

## 系统调用

系统调用按照功能划分在 `syscall/process.rs` 与 `syscall/fs.rs` 等模块中。关键思想是通过 `translated_ref/translated_byte_buffer` 等函数将用户空间指针转换为内核可访问的地址，保证安全的参数访问。进程相关系统调用覆盖 `exit/yield/getpid/exec/mmap` 等行为，文件系统系统调用覆盖 `open/read/write/getcwd/poll/readv/writev` 等 I/O 行为。

关键结构体（源代码）：
```rust
#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct TimeVal {
    pub sec: usize,
    pub usec: usize,
}

#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct TimeSpec {
    pub tv_sec: usize,
    pub tv_nsec: usize,
}

#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct Tms {
    pub tms_utime: usize,
    pub tms_stime: usize,
    pub tms_cutime: usize,
    pub tms_cstime: usize,
}

#[repr(C)]
pub struct UtsName {
    pub sysname: [u8; 65],
    pub nodename: [u8; 65],
    pub release: [u8; 65],
    pub version: [u8; 65],
    pub machine: [u8; 65],
    pub domainname: [u8; 65],
}
```

```rust
#[repr(C)]
#[derive(Clone, Copy)]
pub struct PollFd {
    pub fd: i32,
    pub events: i16,
    pub revents: i16,
}

#[repr(C)]
pub struct IoVec {
    base: *const u8,
    len: usize,
}
```
