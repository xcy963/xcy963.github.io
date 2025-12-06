# 👍bash语法解析

```{note}
一般来说bash的脚本支持的语法会多一些,所以一般写脚本在开头写`#!/bin/bash`就好
```


## 1. bash脚本语法分解讲解

### 1）shebang 和注释

```bash
#!/bin/bash
# sudo usermod -aG dialout $USER 使用这个给串口权限
```

* `#!/bin/bash`：告诉系统这个文件用 `bash` 来解释执行。
* `#` 开头的行是 **注释**，不会执行，用来写说明。

如果写成 `#!/bin/sh`，Ubuntu 上实际上会用 `dash` 执行（和 bash 不完全兼容）。

---

### 2）普通命令与 `source`

```bash
echo "设置USB设备权限..."
source /opt/ros/humble/setup.bash
source /home/hitcrt/lib_xcy/ws_moveit2/install/setup.sh
...
echo "USB设备权限设置完成"
sleep 10
```

* `echo`：打印一行文字到终端。
* `source file`：在**当前 shell 中**执行这个脚本（会修改当前环境变量），等价于 `. file`。

  * 在 ROS 里常见，用来加载环境，比如设置 `ROS_DISTRO`、`PATH`、`AMENT_PREFIX_PATH` 等。
* `sleep 10`：当前脚本 **暂停 10 秒**。

> 这里 `source` 是 Bash 的内建命令，`sh` 里一般用 `.`（点）；虽然很多 sh 也支持 `source`，但严格来说这是 bash 风格。

---

### 3）变量与命令替换

```bash
timestamp=$(date +"%Y%m%d_%H%M%S")
```

* `变量名=值`：中间 **不能有空格**：

  * ✅ `a=1`
  * ❌ `a = 1`
* `$(...)`：**命令替换**，执行括号里的命令，把输出结果作为字符串赋值给变量。

  * 这里 `date +"%Y%m%d_%H%M%S"` 输出类似 `20251204_153012`。

以后用变量的时候写 `$timestamp` 或 `"${timestamp}"`。

---

### 4）数组（Bash 特性）

```bash
commands=(
    "ros2 launch engineer_auto_serial moveit.launch.py"
    "ros2 launch engineer_auto_serial launch.py &>> /home/.../visionPLAN_${timestamp}.log"
    "ros2 launch engineer_auto launch.py &>> /home/.../visionDETECT_${timestamp}.log"
    # ...
)
```

* `commands=( ... )`：定义一个 **一维数组**（这是 Bash 的扩展，`sh` 不支持）。
* 每个元素用空格或换行分隔，如果里头有空格需要用 `""` 包起来。
* 取值：

  * `"${commands[0]}"`：第一个元素
  * `"${commands[$i]}"`：第 `i` 个元素
  * `"${!commands[@]}"`：数组下标列表（这里你在 `for` 里用到）

---

### 5）`declare` 声明数组

```bash
declare -a window_ids
declare -a pids
```

* `declare -a`：声明一个 **索引数组** 变量。
* 这也是 Bash 的扩展，`sh` 里一般没有这个（或者行为不一样）。

---

### 6）函数、局部变量、参数

```bash
start_terminal() {
    local cmd="$1"
    gnome-terminal -- bash -c "echo '运行命令: $cmd';source /home/hitcrt/.bashrc; $cmd; echo '命令已退出，2秒后将重启...'; sleep 2" 2>/dev/null &
    sleep 0.5
    local pid=$(pgrep -o -f "$cmd")
    echo $pid
}
```

* `start_terminal() { ... }`：定义一个函数。
* `local cmd="$1"`：

  * `local`：函数内部的局部变量（只在这个函数里有用）。
  * `$1`：函数的第一个参数。
* `gnome-terminal -- bash -c " ... "`：

  * 启动一个新的终端窗口，执行后面那串命令。
  * `bash -c "字符串"` 的意思是：用 bash 执行这段命令字符串。
* `2>/dev/null`：

  * 把 **标准错误输出**（fd 2）重定向到 `/dev/null`，也就是丢掉错误信息。
* 末尾的 `&`：把这条命令放到后台执行，让脚本继续往下走。
* `pgrep -o -f "$cmd"`：

  * `pgrep`：按名字查进程 ID。
  * `-f`：在完整命令行里匹配。
  * `-o`：取 **最早** 的那个匹配（oldest）。
* 函数最后 `echo $pid`：函数的**输出**是用 `echo` 打印出来，再在外面用 `pid=$(start_terminal ...)` 接收。

---

### 7）判断一个进程是否存在

```bash
process_exists() {
    local pid="$1"
    ps -p "$pid" > /dev/null 2>&1
    return $?
}
```

* `ps -p "$pid"`：查看这个 PID 的进程是否存在。
* `> /dev/null 2>&1`：

  * 把标准输出重定向到 `/dev/null`。
  * `2>&1` 把标准错误也重定向到标准输出（最后也丢掉）。
* `$?`：上一条命令的退出状态码：

  * `0`：成功（进程存在）
  * 非 0：失败（进程不存在）
* `return $?`：把这个状态码作为函数的返回值，在 `if` 里用。

调用时：

```bash
if ! process_exists "${pids[$i]}"; then
    ...
fi
```

* `!`：取反，`process_exists` 返回非 0 时（进程不存在），if 条件为真。

---

### 8）`for` 循环遍历数组下标

```bash
for i in "${!commands[@]}"; do
    pid=$(start_terminal "${commands[$i]}")
    pids[$i]=$pid
    echo "启动终端${i} 执行命令: ${commands[$i]} (进程ID: $pid)"
    sleep 1
done
```

* `"${!commands[@]}"`：数组的所有 **下标列表**，比如 `0 1 2`。
* `for i in ...; do ... done`：遍历每个下标。

---

### 9）`while true` 无限循环 + 监控重启

```bash
while true; do
    for i in "${!pids[@]}"; do
        if ! process_exists "${pids[$i]}"; then
            echo "命令进程${i} ... 已退出，正在重启..."
            ...
            new_pid=$(start_terminal "${commands[$i]}")
            pids[$i]=$new_pid
        else
            echo "命令进程${i} ... 仍在运行"
        fi
    done
    sleep 2
done
```

* `while true; do ... done`：死循环。
* 每 2 秒检查一次进程是否还在。
* 如果退出，就再开一个终端重新跑对应的命令。

这是一个简单的 **守护/看门狗** 逻辑。

---


## 2. shell 和 bash 有什么区别？

### （1）“shell”是总称，“bash”是其中一个实现

* **shell**：命令行解释器的统称，常见的有：

  * `sh`（Bourne shell / POSIX sh）
  * `bash`（Bourne Again Shell）
  * `zsh`
  * `fish`
  * …
* **bash**：GNU 的一个 shell 实现，Ubuntu 默认登录 shell 就是它（普通用户）。

所以可以理解为：

> “bash 是一种 shell，但 shell 不等于 bash。”

---

### （2）Ubuntu 上的 `/bin/sh` 是谁？

在 Ubuntu 上：

* `/bin/sh` 通常是链接到 **`dash`** 的；
* `dash` 是一个更小更快的 **POSIX shell**，不是 bash；
* 它不支持很多 Bash 扩展语法，比如：

  * 真·数组（`arr=()`、`arr[0]=...`）
  * `[[ ... ]]` 条件判断的高级特性
  * `(( ... ))` 算术扩展的一些用法
  * `bash` 的 `declare`、`local` 等行为差异
  * `**` 递归通配等

---

### （3）bash 比较常见的“增强功能”

bash 在 POSIX sh 的基础上加了很多东西，比如：

* **数组**：`arr=(1 2 3)`、`${arr[0]}`、`${!arr[@]}` 等（你脚本里用到了）。
* `[[ ... ]]`：更强大的条件判断，支持模式匹配（`==`、`=~`）。
* `(( ... ))`：更方便的整型运算。
* `source`：加载脚本（sh 里一般用 `.`）。
* 花括号展开：`echo {1..10}` → 1 到 10。
* 内建变量：`$RANDOM`、`$FUNCNAME` 等。

你脚本里这些点都是 **Bash 特色**：

* `commands=( ... )`
* `declare -a`
* `local xxx=...`
* `"${!commands[@]}"`（数组下标）

## 终端的语法补充

### 1. if else

```bash
if [ ${CHAPTER} -gt 3 ]; then \
    cargo build $(MODE_ARG) ;\
else \
    CHAPTER=$(CHAPTER) python3 build.py ;\
fi
```

- 这里`[ ${CHAPTER} -gt 3 ]`表示章节大于3
- `CHAPTER=$(CHAPTER) python3 build.py ;`设置一个环境变量给python命令