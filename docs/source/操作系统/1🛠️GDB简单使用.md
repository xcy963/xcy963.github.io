# 🛠️gdb 简单入门

## 一、gdb 是什么？

**gdb** 是 GNU 调试器，用来在程序“运行时”观察它的状态，比如：

* 程序在哪一行卡住或崩溃
* 变量此刻的值是多少
* 函数调用栈（调用关系）
* 单步执行、设置断点、条件断点等

主要用于 C / C++，也支持其他语言（如汇编、Rust 等）。

---

## 二、准备工作：编译带调试信息的程序

用 gdb 调试时，**一定要加 `-g` 编译选项**，否则看不到源码和变量名。

```bash
# 以 C 为例
gcc -g main.c -o main

# 以 C++ 为例
g++ -g main.cpp -o main
```

常见组合（调试用）：

```bash
g++ -g -O0 main.cpp -o main
```

* `-g`：生成调试信息
* `-O0`：关闭优化，避免优化导致变量被“优化掉”，调起来更直观

> 如果想要直接对二进制文件查看汇编可以使用`objdump`
>```text
># 反汇编整个 .text 段
>objdump -d main
>
># 带上源代码（如果编译时加了 -g）
>objdump -d -S main
>
># 显示所有段（section）信息
>objdump -h main
>
># 显示符号表（类似 nm）
>objdump -t main
>
># 显示更全面的信息（头、段、符号等）
>objdump -x main
>```

---

## 三、启动 gdb 的几种方式

### 1. 直接启动程序

```bash
gdb ./main
```

进入 gdb 后再输入：

```text
(gdb) run     # 或 r
```

### 2. 启动时带参数

```bash
gdb --args ./main arg1 arg2
```

进入 gdb 后：

```text
(gdb) run
```

程序会使用你提供的参数 `arg1 arg2`。

### 3. 调试已经生成的 core dump（崩溃文件）

假设运行时产生了 core 文件 `core`：

```bash
gdb ./main core
```

可以查看崩溃时的调用栈和变量。

---

## 四、gdb 基本操作速查表（常用）

| 功能         | 命令示例                     | 说明                |
| ---------- | ------------------------ | ----------------- |
| 运行程序       | `run` / `r`              | 从头运行              |
| 重新运行       | `run`                    | 再执行一遍             |
| 退出 gdb     | `quit` / `q`             | 退出调试器             |
| 设置断点       | `break 10` / `b 10`      | 在当前文件第 10 行       |
|            | `break main`             | 在函数 `main` 入口     |
|            | `break file.c:20`        | 在 `file.c` 第 20 行 |
| 查看断点       | `info break` / `i b`     | 列出所有断点            |
| 删除断点       | `delete 1` / `d 1`       | 删除编号为 1 的断点       |
| 单步执行(不进函数) | `next` / `n`             | 执行当前行，函数当作一条语句    |
| 单步执行(进入函数) | `step` / `s`             | 执行当前行，如果是函数则进入    |
| 继续运行       | `continue` / `c`         | 一直运行到下一个断点或结束     |
| 打印变量值      | `print x` / `p x`        | 打印变量 `x` 的值       |
| 修改变量值      | `set var x = 10`         | 在调试时修改变量          |
| 查看调用栈      | `backtrace` / `bt`       | 显示函数调用栈           |
| 切换栈帧       | `frame 1` / `f 1`        | 切到第 1 帧           |
| 查看当前源码     | `list` / `l`             | 显示当前行附近的代码        |
| 查看寄存器      | `info registers` / `i r` | 查看寄存器（偏底层）        |

你记住其中 5～6 个就已经能基本调试了：

> `run / break / next / step / print / backtrace / quit`

---

## 五、第一个 gdb 调试示例

我们用一个简单的 C 程序演示：

```c
// file: main.c
#include <stdio.h>

int add(int a, int b) {
    int c = a + b;
    return c;
}

int main() {
    int x = 1;
    int y = 2;
    int z = add(x, y);
    printf("z = %d\n", z);
    return 0;
}
```

### 1. 编译

```bash
gcc -g main.c -o main
```

### 2. 启动 gdb

```bash
gdb ./main
```

你会看到类似：

```text
(gdb)
```

这是 gdb 的提示符。

### 3. 设置断点

在 `main` 函数入口处设置断点：

```text
(gdb) break main
# 或
(gdb) b main
```

### 4. 运行

```text
(gdb) run
```

程序会运行到 `main` 函数的第一行并停下。
此时你可以用 `list` 看到当前行附近的代码：

```text
(gdb) list
```

### 5. 单步执行 + 查看变量

```text
(gdb) next     # 执行 int x = 1;
(gdb) next     # 执行 int y = 2;
(gdb) print x
(gdb) print y
```

你会看到类似输出：

```text
$1 = 1
$2 = 2
```

`$1`、`$2` 是 gdb 给结果起的临时编号。

继续单步：

```text
(gdb) next     # 执行 int z = add(x, y);
```

如果想看函数内部细节，可以回到这行之前，用 `step` 进入：

```text
(gdb) run      # 重新运行
(gdb) break 10 # 在 z = add(x, y); 那一行打断点，行号按实际文件为准
(gdb) continue
(gdb) step     # 进入 add 函数
```

现在就可以在 `add` 函数里 `print a`、`print b`、`print c` 等。

---

## 六、断点的更多用法

### 1. 指定文件和行号

```text
(gdb) break other.c:25
```

在 `other.c` 的第 25 行打断点。

### 2. 条件断点（非常有用）

比如只在 `i == 100` 时暂停：

```text
(gdb) break 42 if i == 100
```

当代码执行到第 42 行并且 `i == 100` 时才会停下来，适合排查循环中某一次的问题。

### 3. 查看/删除断点

```text
(gdb) info break
(gdb) delete 1
(gdb) delete       # 不带编号时会询问是否删除所有断点
```

---

## 七、查看栈和切换函数上下文

当程序崩溃或停在某个断点时，你可以：

### 1. 查看调用栈（函数调用关系）

```text
(gdb) backtrace
# 或
(gdb) bt
```

输出类似：

```text
#0  add (a=1, b=2) at main.c:4
#1  0x000055555555515a in main () at main.c:11
```

* `#0` 是当前函数（最内层）
* `#1` 是谁调用了它，以此类推

### 2. 切换到某一帧（函数上下文）

```text
(gdb) frame 0
(gdb) frame 1
```

切到相应的栈帧后，再 `print` 变量时看到的是该函数上下文中的变量。

---

## 八、观察变量变化：watchpoint

如果你想知道一个变量是**在哪里被改的**，可以用 `watch`：

```text
(gdb) watch x
```

之后每当 `x` 的值改变，程序就会暂停，并显示是在哪一行改变的。

也可以配合 `continue` 用：

```text
(gdb) continue
# 直到 x 的值被改变时停下
```

---

## 九、TUI 模式（源码 + 调试同时看）

gdb 有一个简单的 TUI（文本 UI）模式，可以同时看代码和命令：

```text
(gdb) layout src
```

常用操作：

* `layout src`：显示源码窗口
* `layout regs`：显示寄存器
* `Ctrl + L`：刷新屏幕（有时会用到）

退出 TUI：
按 `Ctrl + x` 再按 `a`（即 `Ctrl+x a`）切换 UI。

---

## 十、调试崩溃（段错误）的小套路

1. 确保编译时加了 `-g`，最好关掉优化：`-O0`

2. 运行程序：

   ```bash
   ./main
   ```

3. 程序段错误（Segmentation fault）时，记下产生 core 文件的位置（不同系统配置略有差异）

4. 进入 gdb：

   ```bash
   gdb ./main core
   ```

5. 在 gdb 中：

   ```text
   (gdb) bt         # 看调用栈
   (gdb) frame 0    # 切到崩溃点
   (gdb) list       # 看崩溃位置附近的源码
   (gdb) print 某些变量
   ```

这样就能定位大概是哪里访问了非法内存。

---

## 十一、遇到忘记的命令怎么办？

gdb 自带帮助：

```text
(gdb) help
(gdb) help break
(gdb) help run
```

不知道怎么用哪个命令，就 `help 那个命令名`，一般都能得到简单说明。

---

## 十二、一个最小使用流程总结

日常排 bug 的典型流程可以是：

```bash
g++ -g -O0 main.cpp -o main    # 1. 编译
gdb ./main                     # 2. 进入 gdb
(gdb) break main               # 3. 在 main 打断点
(gdb) run                      # 4. 运行
(gdb) next / step              # 5. 单步执行
(gdb) print 变量名             # 6. 查看变量
(gdb) backtrace                # 7. 看调用栈（特别是崩溃时）
(gdb) quit                     # 8. 退出
```

---

如果你愿意，我也可以根据你正在调试的具体代码，给你写一套**定制版 gdb 调试步骤**（比如你遇到段错误、死循环、输出不对等具体情况），会更贴合你的实际使用。
