
# 📐 **Eigen 基础与几何运算笔记**

> 重点放在日常机器人 / 数学计算中常用的矩阵、向量、几何变换（旋转、位姿、四元数等）用法。

---

## 1. 基本矩阵与向量类型

Eigen header-only，通常简单地：

```cpp
#include <Eigen/Core>
#include <Eigen/Geometry>  // 卡尔曼/位姿/四元数等用到几何模块时
````

命名空间：

```cpp
using Eigen::MatrixXd;
using Eigen::VectorXd;
using Eigen::Matrix3d;
using Eigen::Vector3d;
```

### 1.1 常见类型

* 固定大小矩阵/向量：

  * `Eigen::Matrix3d`   → `3x3` double
  * `Eigen::Vector3d`   → `3x1` double
  * `Eigen::Matrix<double, 6, 1>` → 6 维向量
* 动态大小：

  * `Eigen::MatrixXd`        → 动态矩阵
  * `Eigen::VectorXd`        → 动态列向量
  * `Eigen::RowVectorXd`     → 动态行向量

### 1.2 初始化方式

#### 流式赋值（推荐小矩阵）

```cpp
Eigen::Matrix3d mat;
mat << 1, 2, 3,
       4, 5, 6,
       7, 8, 9;
```

#### 零、常数、单位矩阵

```cpp
Eigen::Matrix3d A = Eigen::Matrix3d::Zero();
Eigen::Matrix3d B = Eigen::Matrix3d::Identity();
Eigen::VectorXd v = Eigen::VectorXd::Constant(6, 1.0); // 6x1 全 1
```

#### 通过尺寸构造

```cpp
Eigen::MatrixXd M(3, 4);  // 3 行 4 列
M.setZero();
```

---

## 2. 矩阵/向量的常用运算

### 2.1 基本运算

```cpp
Eigen::Vector3d a(1, 2, 3);
Eigen::Vector3d b(4, 5, 6);

double dot = a.dot(b);            // 点积
Eigen::Vector3d c = a.cross(b);   // 叉积 (仅 3D)

double n = a.norm();              // 二范数
Eigen::Vector3d unit = a.normalized(); // 单位向量
```

### 2.2 维度访问与分块

```cpp
Eigen::VectorXd v(6);
v << 1, 2, 3, 4, 5, 6;

Eigen::Vector3d head = v.head<3>();  // 前 3 个
Eigen::Vector3d tail = v.tail<3>();  // 后 3 个

Eigen::Matrix<double, 6, 6> M;
auto block = M.block<3, 3>(0, 3);  // 从 (row=0, col=3) 开始的 3x3 子块
```

* `.row(i)` / `.col(j)` 访问行/列。
* `.transpose()` 转置，`.transposeInPlace()` 原地转置。

### 2.3 数组模式：逐元素运算

```cpp
Eigen::Matrix3d M1, M2;
// ...
Eigen::Matrix3d C = M1.array() * M2.array();  // 逐元素乘
Eigen::Matrix3d D = M1.array().sin();         // 对每个元素取 sin
```

* `matrix()` 可以把 array 再转回矩阵。

---

## 3. 线性方程与分解

### 3.1 解线性方程组

`Ax = b`：

```cpp
Eigen::MatrixXd A;  // n x n
Eigen::VectorXd b;  // n x 1

Eigen::VectorXd x = A.colPivHouseholderQr().solve(b);
```

* 推荐用分解方式，不直接 `A.inverse() * b`（数值精度更好）。

常见分解：

* `LLT` / `LDLT`：适用于对称正定矩阵；
* `FullPivLU` / `PartialPivLU`：通用；
* `JacobiSVD`：做最小二乘等。

示例：

```cpp
Eigen::VectorXd x = A.ldlt().solve(b);
```

---

## 4. 几何模块：旋转与位姿

使用前：

```cpp
#include <Eigen/Geometry>
```

### 4.1 旋转矩阵与 AngleAxis

```cpp
double theta = M_PI / 4.0;  // 45°
Eigen::Matrix3d R = Eigen::AngleAxisd(theta, Eigen::Vector3d::UnitZ()).toRotationMatrix();
```

* `Eigen::AngleAxisd(angle, axis)`：以 `axis` 轴旋转 `angle` 弧度。
* `UnitX()/UnitY()/UnitZ()` 提供标准基轴。

### 4.2 Isometry（刚体变换）

```cpp
Eigen::Isometry3d T = Eigen::Isometry3d::Identity();

// 旋转部分
T.rotate(Eigen::AngleAxisd(theta, Eigen::Vector3d::UnitZ()));

// 平移部分
T.pretranslate(Eigen::Vector3d(1.0, 0.0, 0.0));

// 对一个点变换
Eigen::Vector3d p_world = T * Eigen::Vector3d(0.0, 1.0, 0.0);
```

* `Isometry3d` 内部是 4x4 齐次变换矩阵，常用于机器人位姿。
* `pretranslate` / `translate` 区别在于左乘/右乘（组合顺序不同）。

### 4.3 四元数（Quaternion）

```cpp
Eigen::Quaterniond q1(Eigen::AngleAxisd(M_PI/4, Eigen::Vector3d::UnitZ()));
Eigen::Quaterniond q2(Eigen::AngleAxisd(M_PI/4, Eigen::Vector3d::UnitY()));

// 组合旋转（先 q1 再 q2）
Eigen::Quaterniond q = q2 * q1;

// 归一化（防止累计误差）
q.normalize();

// 转回旋转矩阵
Eigen::Matrix3d R = q.toRotationMatrix();
```

* 四元数乘法顺序和旋转应用顺序要注意（右乘 vs 左乘）。
* 在反复累积旋转时，最好时不时 `normalize()` 一下。

### 4.4 四元数插值（slerp）

```cpp
Eigen::Quaterniond q1(...);
Eigen::Quaterniond q2(...);

double t = 0.5;
Eigen::Quaterniond q_mid = q1.slerp(t, q2);
```

* `t ∈ [0, 1]`，0 是 q1，1 是 q2。
* slerp 保持角速度恒定，不会产生奇怪的缩放。

---

## 5. 格式化输出

### 5.1 IOFormat

```cpp
Eigen::IOFormat fmt(3, 0, ", ", "\n", "[", "]");

Eigen::Matrix4d T;
std::cout << T.format(fmt) << std::endl;
```

解释：

* `3`：小数位数；
* `", "`：元素间分隔符；
* `"\n"`：行分隔符；
* `"["` / `"]"`：前缀和后缀。

---

## 6. 性能小提示

* 尽量在栈上使用固定大小矩阵（如 `Matrix3d`），能帮助编译器做更多优化。
* 大矩阵运算时，尽量避免频繁分配：

  * 使用 `.noalias()` 告诉 Eigen “不会别名”，避免临时变量：

    ```cpp
    C.noalias() = A * B;
    ```
* 禁止在运行时频繁创建大对象；可以在类成员中预先分配重用。

---

## 7. 与 ROS / 其他库的互操作（简略）

常见场景：Eigen ↔ geometry_msgs / tf2 等互转，一般通过辅助函数封装，例如：

```cpp
Eigen::Isometry3d poseMsgToEigen(const geometry_msgs::msg::Pose& msg);
geometry_msgs::msg::Pose eigenToPoseMsg(const Eigen::Isometry3d& T);
```

封装好之后，业务代码就可以直接用 Eigen 做运算，最后再转回 ROS 消息。

> 总体思路：
>
> * 内部算法尽量全用 Eigen（清晰、方便矩阵运算）；
> * 接口层（消息、TF）做一次统一转换。