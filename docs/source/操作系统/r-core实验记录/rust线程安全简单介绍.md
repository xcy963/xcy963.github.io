# Rust中的多线程安全

Rust 的线程模型围绕“所有权 + 类型系统”来防止数据竞争。核心要点是：
- 能跨线程移动的类型实现 `Send`；能在多个线程安全共享引用的类型实现 `Sync`。
- 共享只读数据用 `Arc<T>`；共享可变数据在 `Arc` 外再包一层并发原语（`Mutex`/`RwLock`/原子）。



## Send / Sync
- `Send`: 可以安全地把值移动到另一个线程（大多数基础类型、`String`、`Vec` 等都实现了）。
- `Sync`: 对 `&T` 的共享引用可以跨线程安全使用；如果 `T: Sync`，则 `&T: Send`。
- 非线程安全的类型（如 `Rc<T>`、`Cell<T>`、`RefCell<T>`）不实现这些标记，防止误用。

## 共享所有权：Arc
`Arc<T>` 是原子引用计数智能指针(Atomic Reference Counted)，适合多线程共享只读数据：
```rust
use std::{sync::Arc, thread};

fn main() {
    let config = Arc::new(vec![1, 2, 3]);
    let mut handles = vec![];
    for _ in 0..4 {
        let cfg = Arc::clone(&config); // 原子递增计数
        handles.push(thread::spawn(move || {
            println!("len = {}", cfg.len());
        }));
    }
    for h in handles {
        h.join().unwrap();
    }
} // 所有 Arc drop 后，计数归零释放底层数据
```
- 在这个例子中,如果不使用ARC的方法把config复制,那么根据rust的所有权机制config不可能在一次move之后还能被move,
- 这里其实config并没有被移动,而是使用了Arc::clone创建了新的对象,所以不会有所有权交换
- 只能共享不可变数据；要共享可变数据，需要“内部可变性”配合锁或原子。

## 共享可变状态：Arc + Mutex/RwLock
### Arc<Mutex<T>>
```rust
use std::{sync::{Arc, Mutex}, thread};

fn main() {
    let counter = Arc::new(Mutex::new(0));
    let mut handles = vec![];
    for _ in 0..10 {
        let c = Arc::clone(&counter);
        handles.push(thread::spawn(move || {
            let mut guard = c.lock().unwrap(); 
            // 通过 Arc 的 Deref/自动解引用，把 Arc<Mutex<_>> 当作 Mutex<_> 来调用 lock()，获取互斥锁
            *guard += 1;                       // 修改共享数据
        }));
    }
    for h in handles { h.join().unwrap(); }
    println!("result = {}", *counter.lock().unwrap());
}
```
- `Mutex` 提供独占访问，`lock` 返回 `MutexGuard`，在作用域结束时自动释放。
- `lock` 失败会返回 `PoisonError`（其他线程在持锁时 panic），可用 `unwrap_or_else(|e| e.into_inner())` 继续。

### Arc<RwLock<T>>
读多写少场景可用读写锁：
```rust
use std::{sync::{Arc, RwLock}, thread};

fn main() {
    let data = Arc::new(RwLock::new(Vec::<u32>::new()));
    let mut handles = vec![];

    // writer
    {
        let d = Arc::clone(&data);
        handles.push(thread::spawn(move || {
            d.write().unwrap().push(42);
        }));
    }
    // reader
    for _ in 0..3 {
        let d = Arc::clone(&data);
        handles.push(thread::spawn(move || {
            let snapshot = d.read().unwrap();
            println!("len = {}", snapshot.len());
        }));
    }
    for h in handles { h.join().unwrap(); }
}
```
- 读锁可并行，写锁独占；写偏向或饥饿问题取决于实现（`std` 的 `RwLock` 以读优先）。

## 无锁共享：原子类型
对于简单数值计数或标志，原子类型更轻量：
```rust
use std::sync::atomic::{AtomicUsize, Ordering};
use std::{sync::Arc, thread};

fn main() {
    let counter = Arc::new(AtomicUsize::new(0));
    let mut handles = vec![];
    for _ in 0..4 {
        let c = Arc::clone(&counter);
        handles.push(thread::spawn(move || {
            c.fetch_add(1, Ordering::Relaxed);
        }));
    }
    for h in handles { h.join().unwrap(); }
    println!("{}", counter.load(Ordering::Relaxed));
}
```
- `Ordering` 控制内存序；常见有 `Relaxed`（只保证原子性）、`Acquire/Release`、`SeqCst`。
- 只适合简单数据；复杂结构仍需锁或无锁算法。

## 消息传递：Channel
Rust 标准库的 `mpsc` 通道用来隔离状态：
```rust
use std::sync::mpsc;
use std::thread;

fn main() {
    let (tx, rx) = mpsc::channel::<String>();
    for i in 0..3 {
        let sender = tx.clone();
        thread::spawn(move || {
            sender.send(format!("task {i} done")).unwrap();
        });
    }
    drop(tx); // 关闭发送端，避免阻塞
    for msg in rx { println!("{msg}"); }
}
```
- 通道通过移动消息避免共享可变状态；`crossbeam-channel` 提供多生产者多消费者且性能更好。

## 常见陷阱与建议
- **避免 `Rc`/`RefCell` 跨线程**：使用 `Arc` + 并发原语替代。
- **锁粒度与死锁**：保持锁顺序一致，或用单一锁包裹多个字段降低死锁风险。
- **尽量缩短持锁时间**：在锁内只做必要工作，尽早释放 guard。
- **panic 处理**：线程 panic 不会杀死进程；`join` 返回 `Result`，需要检查并决定是否恢复。
- **选择合适工具**：读多写少用 `RwLock`；低竞争下 `Mutex` 足够；原子适合简单计数；状态隔离则用 channel。

Rust 通过类型系统提前限制了跨线程的数据流向，再辅以 `Arc`、锁、原子、channel 等原语，能够在不牺牲性能的前提下提供较强的线程安全保障。
