
# ⏱️ **C++ 时间与线程同步笔记（std::chrono & 条件变量）**

> 涵盖：时间表示、时间戳转换与格式化、定时与超时；以及条件变量 + mutex 的线程同步模式。

## 魔法传送门
- <a href="#system_clock转字符串">system_clock转字符串</a>

- <a href="#cpp多线程简单介绍">cpp多线程简单介绍</a>


---

## 1. C++ 时间库：std::chrono 基础

头文件：

```cpp
#include <chrono>
````

常用命名空间：

```cpp
using namespace std::chrono;
```

### 1.1 duration（时间间隔）

`duration<Rep, Period>`：

* `Rep`：数值类型（一般都是 `int64_t`）
* `Period`：以 `std::ratio` 表示的时间单位，例如 `std::milli` 表示 1/1000 秒。

> 关于ratio
> 
> ```cpp
>template <std::intmax_t Num, std::intmax_t Denom = 1>
>struct ratio {
>    static constexpr std::intmax_t num = /* 约分后的分子 */;
>    static constexpr std::intmax_t den = /* 约分后的分母 */;
>};
>```

别名（标准提供的常用类型）：

```cpp
std::chrono::seconds
std::chrono::milliseconds
std::chrono::microseconds
std::chrono::nanoseconds
using nanoseconds	= duration<_GLIBCXX_CHRONO_INT64_T, nano>;
using microseconds	= duration<_GLIBCXX_CHRONO_INT64_T, micro>;
using milliseconds	= duration<_GLIBCXX_CHRONO_INT64_T, milli>;
using seconds	= duration<_GLIBCXX_CHRONO_INT64_T>;
typedef ratio<1,             1000000000000> pico;//
typedef ratio<1,                1000000000> nano;
typedef ratio<1,                   1000000> micro;//表示百万分之一秒
typedef ratio<1,                      1000> milli;//表示千分之一秒
typedef ratio<1,                       100> centi;
typedef ratio<1,                        10> deci;
```

示例：

```cpp
std::chrono::milliseconds  d = std::chrono::milliseconds(1500);
int64_t s = std::chrono::duration_cast<std::chrono::seconds>(d).count(); // duration_cast是截断这个会使用1s
int64_t ms = d.count();  // 1500
```

> 规则：
>
> * 不同单位的 duration 可以 `duration_cast` 相互转换,这个是`**截断**不是四舍五入!`；
> * `.count()` 得到底层整数 / 浮点数。一般类型是`std::chrono::seconds::rep`

### 1.2 time_point（时间点）

由某个 `Clock` + `duration` 组成。常用时钟：

* `steady_clock`：单调、不受系统时间修改影响 → **适合测时 / 超时判断**。
* `system_clock`：系统时间，可与日历时间交互。
* （还有 `high_resolution_clock`，通常是 alias）

示例：

```cpp
auto t0 = std::chrono::steady_clock::now();
// ...
auto t1 = std::chrono::steady_clock::now();

auto dt = std::chrono::duration_cast<std::chrono::milliseconds>(t1 - t0).count();
```

> 习惯：
>
> * 用 `steady_clock` 做逻辑超时 / 心跳；
> * 用 `system_clock` 做“当前日期时间”的记录和日志。

---

## 2. ROS2 时间戳与 std::chrono 互转

以 `builtin_interfaces::msg::Time` 为例：

```cpp
#include <builtin_interfaces/msg/time.hpp>

int64_t stamp_to_nanoseconds(const builtin_interfaces::msg::Time& stamp) {
  return static_cast<int64_t>(stamp.sec) * 1'000'000'000LL + stamp.nanosec;
}
```

如果需要转为 `std::chrono::nanoseconds`：

```cpp
std::chrono::nanoseconds to_chrono_ns(const builtin_interfaces::msg::Time& stamp) {
  return std::chrono::seconds(stamp.sec) + std::chrono::nanoseconds(stamp.nanosec);
}
```

反向转换（chrono → ROS 时间）：

```cpp
builtin_interfaces::msg::Time chrono_to_stamp(const std::chrono::nanoseconds& ns) {
  builtin_interfaces::msg::Time t;
  t.sec = static_cast<int32_t>(
    std::chrono::duration_cast<std::chrono::seconds>(ns).count());
  t.nanosec = static_cast<uint32_t>(
    (ns - std::chrono::seconds(t.sec)).count());
  return t;
}
```

---
<a id="system_clock转字符串"></a>

## 3. 日历时间格式化输出

传统方式使用 `std::time_t` + `std::tm` + `std::put_time`：

```cpp
#include <ctime>
#include <iomanip>
#include <iostream>

std::string current_time_string() {
  using namespace std::chrono;
  auto now = system_clock::now();
  std::time_t t = system_clock::to_time_t(now);

  std::tm tm_buf;
#ifdef _WIN32
  localtime_s(&tm_buf, &t);
#else
  localtime_r(&t, &tm_buf);
#endif

  std::ostringstream oss;
  oss << std::put_time(&tm_buf, "%Y年%m月%d日 %H时%M分%S秒");
  return oss.str();
}
```

* `gmtime_r` / `gmtime_s`：转为 UTC；
* `localtime_r` / `localtime_s`：转为本地时间。

---

## 4. 超时逻辑 & 定时循环

### 4.1 超时判断

```cpp
using namespace std::chrono;

auto deadline = steady_clock::now() + milliseconds(500);

if (steady_clock::now() > deadline) {
  // 已超时
}
```

或：

```cpp
auto start = steady_clock::now();
// ... do some work ...
auto elapsed_ms = duration_cast<milliseconds>(steady_clock::now() - start).count();
if (elapsed_ms > 500) {
  // 超时
}
```

### 4.2 固定周期循环（例：控制 100 Hz）

```cpp
using namespace std::chrono;

auto next = steady_clock::now();

while (running) {
  next += milliseconds(10);  // 10ms 周期 = 100Hz

  // 你的逻辑
  do_work();

  std::this_thread::sleep_until(next);
}
```

> 推荐：
>
> * 用 `sleep_until` 而不是 `sleep_for`，避免累积误差。

---
<a id="cpp多线程简单介绍"></a>

## 5. 线程基础：mutex 与 lock_guard / unique_lock

头文件：

```cpp
#include <thread>
#include <mutex>
#include <condition_variable>
```

### 5.1 mutex + lock_guard

```cpp
std::mutex mtx;
int shared_data = 0;

void worker() {
  {
    std::lock_guard<std::mutex> lock(mtx);
    ++shared_data;
  }  // 出作用域自动解锁
}
```

* `lock_guard` 适合简单加锁/解锁，无需手动控制解锁时机。

### 5.2 unique_lock

```cpp
std::mutex mtx;

void foo() {
  std::unique_lock<std::mutex> lock(mtx);
  // ... 一些逻辑 ...
  lock.unlock();  // 某些场景下提前解锁
  // ... 解锁后的逻辑 ...
}
```

* `unique_lock` 用于配合 `std::condition_variable` 或需要灵活控制锁的场景。

---

## 6. 条件变量：条件 + 队列（推荐写法）

核心模式是“谓词唤醒”，避免假唤醒：

```cpp
std::mutex mtx_;
std::condition_variable cv_;
std::queue<int> q_;
bool running_ = true;

void producer() {
  for (int i = 0; i < 100; ++i) {
    {
      std::lock_guard<std::mutex> lock(mtx_);
      q_.push(i);
    }
    cv_.notify_one();  // 通知消费者有新数据
  }

  {
    std::lock_guard<std::mutex> lock(mtx_);
    running_ = false;
  }
  cv_.notify_all();  // 通知所有等待线程，准备退出
}

void consumer() {
  while (true) {
    std::unique_lock<std::mutex> lock(mtx_);

    cv_.wait(lock, [this] {//这个不被通知就不会继续往下走,除非退出条件满足
      return !q_.empty() || !running_;
    });
    // cv_.wait_for(lock, std::chrono::milliseconds(100), [this] {//这个超时会自己继续往下走
    // return !plot_queue_.empty() || !plot_running_;
    // });

    if (!running_ && q_.empty()) {
      break;  // 真正退出条件
    }

    int value = q_.front();
    q_.pop();
    lock.unlock();  // 解锁后再处理，减小临界区

    // 处理数据
    handle(value);
  }
}
```

要点：

* `wait(lock, predicate)`：

  * 内部会在被唤醒后再次检查谓词；
  * 即使出现假唤醒，也不会导致错误。
* 退出逻辑：

  * 通过 `running_` 之类的标志告诉消费者“不会再有新数据了”；
  * 退出条件必须同时考虑 `队列为空 + running_ = false`。

---

## 7. 带超时的等待（wait_for）

你给出的模式（带超时的 `wait_for`）可以这样写：

```cpp
plot_cv_.wait_for(lock, std::chrono::milliseconds(100), [this] {
  return !plot_queue_.empty() || !plot_running_;
});
```

常见场景：

* 平时等数据，如果超过一段时间没有数据也要“做点事”（例如刷新 GUI、检查退出状态等）。

---

## 8. 条件变量的小结与实践建议

* **永远用谓词版本**：`wait(lock, predicate)` 或 `wait_for(lock, duration, predicate)`。

  * 这是防止假唤醒 / 丢唤醒的标准写法。
* **配合 steady_clock**：

  * `wait_until` / `wait_for` 默认使用 `steady_clock` 作为内部时间源（实现相关），适合做超时控制。
* **通知顺序**：

  * 修改共享状态 → 解锁/仍持锁 → `notify_one()` / `notify_all()`；
  * 通常先更新状态再 `notify`，确保醒来的线程看到的是“最新状态”。

---

## 9. std::thread 简要使用

```cpp
void worker(int id) {
  // ...
}

int main() {
  std::thread t1(worker, 1);
  std::thread t2(worker, 2);

  t1.join();
  t2.join();
}
```

* `join()`：等待线程结束；
* `detach()`：让线程在后台自行运行（谨慎使用，容易搞出“孤儿线程”）。

> 建议：
>
> * 能用线程池（如自己封装）就用线程池；
> * 自己管理线程时要想清楚停止条件与资源回收。

---

## 10. 组合示例：定时工作线程 + 条件变量停止

```cpp
class Worker {
public:
  Worker() : running_(true), th_(&Worker::loop, this) {}

  ~Worker() {
    {
      std::lock_guard<std::mutex> lock(mtx_);
      running_ = false;
    }
    cv_.notify_all();
    if (th_.joinable()) th_.join();
  }

  void notifyWork() {
    cv_.notify_one();
  }

private:
  void loop() {
    using namespace std::chrono;
    auto next = steady_clock::now();

    std::unique_lock<std::mutex> lock(mtx_);

    while (running_) {
      next += milliseconds(10);

      cv_.wait_until(lock, next, [this] {
        return !running_;  // 或有其他“立刻处理”条件
      });

      if (!running_) break;

      lock.unlock();
      do_work();   // 真正的工作
      lock.lock();
    }
  }

  void do_work() {
    // ...
  }

  std::mutex mtx_;
  std::condition_variable cv_;
  bool running_;
  std::thread th_;
};
```

这类模式常用于：

* 固定周期任务（控制循环）；
* 可以被外部唤醒（`notifyWork()`）立即处理某些事；
* 析构时安全退出线程。
