# 💾r-core实验5进程管理

```{note}
这次开始就是看代码,不懂再看文档,看代码的顺序是按照文档来的
```

## 看系统调用

- `task manager`已经进化了他现在叫做`Processor`

```rust
pub struct Processor {
    ///The task currently executing on the current processor
    current: Option<Arc<TaskControlBlock>>,

    ///The basic control flow of each core, helping to select and switch process
    idle_task_cx: TaskContext,
}
```


### 1. sysfork


