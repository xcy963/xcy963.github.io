# risc-v寄存器

```{note}
我喜欢把risc-v寄存器分为硬件会改的,硬件不会改的(只要代码不改他就不动)
**1.硬件不会改的**
- 通用寄存器(x0~x31),硬件不会改,所以由内核维护我们保存在`TrapContext`里面,
    - 其实`sp` `ra` 这些寄存器是有硬件会去读他们的,但是硬件不会主动改
- `satp` `stvec` `sscratch`等杂类,也是硬件可能会读取的
    - `satp:Supervisor Address Translation and Protection Register`就是页表啦
    - `stvec:Supervisor Trap Vector `就是写trap地址的(是一个rust函数,保存上下文,进入内核态啥的)
    - `sscratch`定义是临时寄存器,我们的系统用来保存TrapContext

**2.硬件会改的**
- 特殊寄存器(其实就是trap 4件套`sepc/scause/stval/sstatus`)
    - 这里可以看出trap是允许传递参数的,但是只有一个寄存器,所以如果想要传递多个参数,那么就需要传递指针,可能需要构造页表
    - `sepc`：写入 trap 前的 PC（用于返回）
    - `scause`：写入 trap 原因
    - `stval`：写入附加信息（比如缺页地址）
    - `sstatus`：硬件会更新一些位（比如记录来自 U 还是 S、以及中断相关位）
```

## 1) 通用寄存器（GPR）——按 trap / syscall 场景理解

> 重点：发生 trap 时，**硬件不会自动保存这些 GPR**，需要你的 trap entry 手动保存到 `TrapContext`；trap handler/内核函数调用遵循 ABI：**callee-saved 必须恢复**，caller-saved 可能被覆盖。

| 寄存器     | ABI 名  | 类别           | 典型用途（结合 trap）                            | 在 trap 过程中常见做法                                                          |
| ------- | ------ | ------------ | ---------------------------------------- | ----------------------------------------------------------------------- |
| x0      | zero   | 常量           | 恒为 0                                     | 不保存、不恢复                                                                 |
| x1      | ra     | caller-saved | 返回地址；trap 入口可能被调用链覆盖                     | 一般保存到 TrapContext（你代码里单独 `ld x1`）                                       |
| x2      | sp     | 特殊           | 用户栈/内核栈指针                                | trap entry：切到内核栈并保存用户 sp；trap return：最后再恢复用户 sp（你代码末尾 `ld sp, 2*8(sp)`） |
| x3      | gp     | caller-saved | 全局指针（链接器/运行时用）                           | 一般也保存恢复（你代码单独 `ld x3`）                                                  |
| x4      | tp     | 特殊（平台/线程）    | 线程指针/CPU 本地（TLS）                         | 很多内核**不从用户上下文恢复 tp**（你代码也排除 tp），或由内核另行维护                                |
| x5–x7   | t0–t2  | caller-saved | 临时寄存器；trap stub 常用 t0/t1 读写 CSR/地址       | handler/stub 可随意用，返回前若要还原用户现场就从 TrapContext 恢复                          |
| x8      | s0/fp  | callee-saved | 保存寄存器/帧指针                                | 若内核函数使用，必须按 ABI 保存；通常 TrapContext 也会存它（用于回用户）                           |
| x9      | s1     | callee-saved | 保存寄存器                                    | 同上                                                                      |
| x10–x17 | a0–a7  | caller-saved | 参数/返回值；**syscall：a7=号，a0–a5=参数，返回值放 a0** | trap entry 需保存；syscall handler 读 a7/a0…；返回前把结果写回 a0                     |
| x18–x27 | s2–s11 | callee-saved | 保存寄存器                                    | 同上，通常 TrapContext 全保存全恢复                                                |
| x28–x31 | t3–t6  | caller-saved | 临时寄存器                                    | 同上                                                                      |

---

## 2) 关键 CSR（Supervisor 模式）——trap 入口/出口“硬件自动填”的部分

> 重点：trap 发生时，硬件会更新一些 CSR；trap return 时，`sret` 会依赖 `sstatus/sepc` 等状态。

| CSR        | 作用                 | trap 发生时硬件做什么                           | trap 返回时谁用它 / 怎么用                                    | 在 `__restore` 里的对应动作        |
| ---------- | ------------------ | --------------------------------------- | ---------------------------------------------------- | --------------------------- |
| `sepc`     | Trap 前的 PC（返回地址）   | 写入触发 trap 的指令地址（或下一条，取决于异常类型/实现）        | `sret` 让 PC ← `sepc`                                 | `csrw sepc, t1`             |
| `sstatus`  | 特权状态（含 SPP/SPIE 等） | 关键位会被硬件改：例如设置 SPP 表示来自 U 还是 S，更新 SPIE 等 | `sret` 会根据 `sstatus.SPP` 决定返回到 U 还是 S；SPIE 控制返回后中断使能 | `csrw sstatus, t0`（必须提前恢复好） |
| `scause`   | trap 原因            | 写入异常/中断原因码                              | handler 读它来分发：syscall、page fault、timer interrupt…    | 你的 stub 里没用，但 handler 会用    |
| `stval`    | 附加信息               | 例如 page fault 的坏地址、非法指令等                | handler 用于定位故障地址/指令                                  | stub 不直接用                   |
| `stvec`    | trap 入口地址          | 不自动改（由 OS 配置）                           | 决定 trap 进入哪个入口（direct/vectored）                      | 由初始化设置                      |
| `sscratch` | S 模式临时寄存器          | 硬件不自动写（OS 自用）                           | 常用来在 trap entry/exit 传递 TrapContext/栈指针等             | 你这里 `csrw sscratch, a0`     |

---

## 3) `satp`（地址空间切换）——为什么 trap return 要写它

| CSR    | 作用           | trap/返回中的意义                               | `__restore` 里的动作                       |
| ------ | ------------ | ----------------------------------------- | -------------------------------------- |
| `satp` | 页表根 + 地址翻译模式 | 内核通常在 S 模式使用内核页表；返回用户前切回用户页表，否则用户 VA 解释不对 | `csrw satp, a1`，随后 `sfence.vma` 刷新 TLB |

---

## 4) trap 执行流程里“哪些寄存器在什么时候关键”

| 阶段                 | 关键寄存器/CSR                                                     | 典型用途                    | 常见坑                                                |
| ------------------ | ------------------------------------------------------------- | ----------------------- | -------------------------------------------------- |
| trap 进入（硬件）        | `sepc`, `scause`, `stval`, `sstatus`                          | 记录来源 PC/原因/附加信息/来源特权级   | 以为硬件会保存 GPR（不会）                                    |
| trap entry（软件保存现场） | `sp`（切内核栈）、`sscratch`（放指针）、所有 GPR                             | 保存用户现场到 TrapContext     | 忘记保存 `a0–a7`，syscall 参数就丢了                         |
| handler（内核处理）      | `a7`（syscall号）、`a0–a5`（参数）、`scause`（分发）                       | 执行系统调用/缺页处理/中断处理        | handler 调用深了会覆盖 caller-saved，必须靠 TrapContext 恢复用户态 |
| trap 返回准备          | `sepc`（可能 +4）、`sstatus.SPP=0`、返回值写回 `a0`                      | 设置回用户态、设置下一条 PC、写返回值    | SPP 没清零会 `sret` 回到 S 模式（严重）                        |
| `__restore`（恢复现场）  | `satp`→`sfence.vma`、恢复 `sstatus/sepc`、恢复 GPR、最后恢复 `sp`、`sret` | 让用户程序“像没发生过 trap 一样”继续跑 | 过早恢复 `sp` 会导致无法再从 TrapContext 取数据                  |

