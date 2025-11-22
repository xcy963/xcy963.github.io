# 🧱 CMake 与构建笔记

> 目标：整理日常 C++ / ROS2 项目中常见的 CMake 用法，理解“目标（target）”及其依赖、include 路径、链接库、编译配置等。

## 魔法目录,点击可以传送
<!-- - [跳到 CMake 部分](#Pkg::Target导出目标) -->
- <a href="#Pkg::Target导出目标">如何使用Pkg::Target导出目标</a>
---

## 1. 目标（Target）与可见性

在现代 CMake（推荐 3.10+）里，一切以“目标（target）”为中心：

- 可执行程序：`add_executable(my_app main.cpp ...)`
- 库：
  - 静态库：`add_library(my_lib STATIC src/a.cpp ...)`
  - 动态库：`add_library(my_lib SHARED src/a.cpp ...)`
- 导入目标（imported）：由 `find_package` 提供的现成目标，如 `Eigen3::Eigen`、`urdf::urdf` 等。

### 1.1 include 可见性：PUBLIC / PRIVATE / INTERFACE

```cmake
target_include_directories(my_lib
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
  PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)
````

* `PUBLIC`

  * **当前目标 + 依赖当前目标的其他目标** 都能看到这些 include 路径。
  * 典型用法：对外提供的头文件（`include/`）。
* `PRIVATE`

  * 只作用于当前目标，依赖它的目标看不到。
  * 典型用法：库内部实现需要的头文件（`src/`）。
* `INTERFACE`

  * 只对 “依赖当前目标” 生效，本目标自己不使用（一般用于 header-only 库）。

> 小结：
>
> * 库对外 API 头文件：`PUBLIC`
> * 只在库内部用到：`PRIVATE`
> * 纯接口 / header-only 库：`INTERFACE`

#### 常见自保写法（区分构建树 vs 安装树）

```cmake
target_include_directories(my_lib
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
```

* `BUILD_INTERFACE`：在编译本项目时使用的路径。
* `INSTALL_INTERFACE`：在 `make install` 之后，给其他项目使用时提供的路径。

---

## 2. 链接库：target_link_libraries 的语义

```cmake
target_link_libraries(my_app
  PRIVATE
    my_lib
    Eigen3::Eigen
)
```

关键点：

* 仍然支持 `PUBLIC` / `PRIVATE` / `INTERFACE`：

  * `PRIVATE`：只本目标需要链接这些库，依赖它的目标不自动继承。
  * `PUBLIC`：本目标需要，且依赖本目标的其他目标也需要。
  * `INTERFACE`：只给依赖它的目标，自己不链接（常用于 interface 库）。
* 一般规则：

  * 可执行程序通常 `PRIVATE` 链接到所有库。
  * 中间库如果希望“传递依赖”，可以 `PUBLIC` 链接到底层库。

### 2.1 在 ament / ROS 里的注意事项

```cmake
add_executable(class_node src/class_node.cpp)
target_link_libraries(class_node PRIVATE camera_pose_IK)

ament_target_dependencies(class_node
  rclcpp
  sensor_msgs
  # ...
)
```

* `ament_target_dependencies` 本质上会：

  * `target_link_libraries` 目标；
  * 设置 include 路径等。
* 对同一个目标多次调用 `target_link_libraries` / `ament_target_dependencies` 时：

  * 尽量保持风格统一，避免一会儿 `PUBLIC` 一会儿 `PRIVATE`；
  * 避免重复或少链接库（尤其 copy-paste 时最容易出错）。

如果你用 `ament_target_dependencies` 管理依赖库，就不要再单独写老式的 `${foo_LIBRARIES}` 形式，尽量保持“目标风格统一”。

---

## 3. find_package：旧式变量 vs 现代导出目标

### 3.1 旧式写法（不推荐）

```cmake
find_package(Eigen3 REQUIRED)
include_directories(${EIGEN3_INCLUDE_DIR})
target_link_libraries(my_app ${EIGEN3_LIBRARIES})
```

依赖是以“变量”的形式暴露的：

* `<Pkg>_FOUND`
* `<Pkg>_INCLUDE_DIRS`
* `<Pkg>_LIBRARIES`
* `<Pkg>_VERSION`  等

缺点：可读性差、易出错、不利于依赖传播。

<a id="Pkg::Target导出目标"></a>

### 3.2 现代写法：导出目标（推荐）
```cmake
find_package(Eigen3 REQUIRED)

target_link_libraries(my_app
  PRIVATE
    Eigen3::Eigen
)
```

优点：

* 不需要关心 include 路径和底层库名字；
* 可与 `PUBLIC` / `PRIVATE` / `INTERFACE` 机制自然结合，自动传播依赖；
* 跨平台性更好。

> 关于`Pkg::Target`的查找,我先打开源码目录(我们放build的地方),找`**Eigen3Targets.cmake**`文件,比如我的路径是
> /home/hitcrt/libxcy/eigen-3.4.0/build/Eigen3Targets.cmake,一般命名规则是`{我是库名称}Targets.cmake`,里面会有
> `# Create imported target Eigen3::Eigen `
> `add_library(Eigen3::Eigen INTERFACE IMPORTED)`我们照着抄就好
---

## 4. 编译命令导出（compile_commands.json）

为了让 IDE / LSP（clangd 等）精确补全，需要生成 `compile_commands.json`：

### 4.1 纯 CMake 项目

```bash
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build
# build/compile_commands.json
```

### 4.2 ROS2 + colcon

```bash
colcon build \
  --symlink-install \
  --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=YES
```

> 小技巧：可以在工作空间根目录建一个符号链接指向其中一个包的 `compile_commands.json`，方便编辑器配置。

---

## 5. 源树 vs 构建树

* 源树（source tree）：

  * `.cpp` / `.hpp` / `CMakeLists.txt` 所在路径。
* 构建树（build tree）：

  * 所有中间文件（`.o`、`.a`、`.so`）、`CMakeCache.txt`、`compile_commands.json` 等。

常见组织：

```bash
my_ws/
  src/
    my_pkg/
      CMakeLists.txt
      include/
      src/
  build/
  install/
  log/
```

在纯 CMake 项目中，推荐 out-of-source build：

```bash
mkdir -p build && cd build
cmake ..
cmake --build .
```

---

## 6. 构建类型与编译选项

### 6.1 构建类型

```cmake
set(CMAKE_BUILD_TYPE Release)  # 或 Debug / RelWithDebInfo / MinSizeRel
```

CMake 常见预设：

* `Debug`：不开优化，带调试信息。
* `Release`：开启优化（`-O3` 等），默认不带调试信息。
* `RelWithDebInfo`：优化 + 调试信息（推荐日常）。
* `MinSizeRel`：针对体积优化。

在多配置生成器（如 Visual Studio）下，一般在 IDE 里切。

### 6.2 编译选项

现代写法推荐对 target 设置，而不是全局：

```cmake
target_compile_features(my_lib PUBLIC cxx_std_17)

target_compile_options(my_lib
  PRIVATE
    -Wall -Wextra -Wpedantic
)
```

* `target_compile_features`：指定使用的 C++ 标准、语言特性。
* `target_compile_options`：给特定目标添加警告、优化等选项。

---

## 7. 最小可参考示例（含 ROS2 场景）

```cmake
cmake_minimum_required(VERSION 3.10)
project(camera_pose_ik)

# 一般 ROS2 会另外有 find_package(ament_cmake REQUIRED)
find_package(ament_cmake REQUIRED)
find_package(Eigen3 REQUIRED)
find_package(rclcpp REQUIRED)

add_library(camera_pose_IK SHARED
  src/camera_pose_IK.cpp
)

target_include_directories(camera_pose_IK
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_link_libraries(camera_pose_IK
  PUBLIC
    Eigen3::Eigen
)

add_executable(class_node
  src/class_node.cpp
)

target_link_libraries(class_node
  PRIVATE
    camera_pose_IK
)

ament_target_dependencies(class_node
  rclcpp
  # ...
)

install(
  TARGETS camera_pose_IK class_node
  DESTINATION lib/${PROJECT_NAME}
)

ament_package()
```

> 思路总结：
>
> * 凡是“能抽象成一个目标（库/可执行/接口）”的，都尽量抽出来；
> * 所有依赖通过 `target_link_libraries`、`target_include_directories` 等对目标配置；
> * 尽量使用 `find_package` 导出的目标而不是裸变量。
