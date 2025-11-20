# 🎩Rust魔法课堂

## pre 
> rust println!是一个宏

> rust 函数的最后一个表达式的值就是返回值 

> `{:?}`是调试的时候使用的格式化输出,普通情况下使用`{}`,但是有些类可能没有实现Display trait,所以只能使用Debug trait
### 1关于rustlings的那些代码的配置
```rust
#[cfg(test)]//这个是一个属性,表示这个模块只在测试的时候编译,类似于cpp的#ifdef
mod //这个关键字只有在定义模块的时候才用到,类似cpp的class
{
    use super::*; //这个是引入上级模块的所有内容,类似cpp的#include
    #[test] //这个属性表示这是一个测试函数
    fn it_works() {
        let result = add(2, 2);}
}

```
> 被标记为`#[test]`的函数会被测试框架自动识别并运行,不需要我们手动调用

### 2 关于panic
```rust
if weight_in_grams <= 0 {
    panic!("Can not ship a weightless package.");  // 程序会在这里终止
}//就是cpp里面的throw new Exception("Can not ship a weightless package.");

```
**`panic!` 的特点：**
- 立即终止当前线程的执行
- 打印错误信息并展开调用栈（unwind）
- 用于处理**不可恢复的错误**
- 在测试中，可以用 `#[should_panic]` 来测试期望的 panic
- `#[should_panic]`对应cpp里面的try catch

### 3. 关于rust中的字符串
```rust
let s1 = String::from("hello"); // 可变字符串
let s2 = &s1[0..2]; // 切片，获取前两个字节
let s3 = "123"; // 字符串字面量，类型是 &str,这样子的话字符串在程序只读数据段中分配,不可变
//好处是这个字符串全局存在，不需要在堆上分配内存，性能更好
```
### 4. 所有权机制

> mut 可能只是一个和编译器相关的东西

```rust

fn sale_price(price: i32) -> i32 {
    if is_even(price) {
        price - 10
    } else {
        price - 3
    }
}
fn is_even(num: i32) -> bool {
    num % 2 == 0
}
//这个例子里面并没有发生所有权转移,我认为是栈里面保存了一个price
//因为rust似乎只是把那些保存在堆里面的数据类型,设计了这个东西,我认为是rust在弹栈(弹出对应的指针)的时候会对堆进行清理
//也就是说所有权其实是针对堆里面的数据的,所以类似数组和字符串(使用string::from创建的字符串)这些类型才有所有权交换
```

### 5. 闭包和cpp lambda函数的对比
> | 特性 | C++ Lambda | Rust 闭包 |
> |------|------------|-----------|
> | 语法 | `[](){}` | `||{}` |
> | 捕获列表 | 显式 `[=]`, `[&]`, `[var]` | 自动推断 |
> | 返回值 | 可指定 `-> type` | 自动推断或指定 `-> type` |

```rust
// 普通函数
fn is_even(x: i32) -> bool { x % 2 == 0 }

// 闭包（等效）
let is_even_closure = |x: i32| -> bool { x % 2 == 0 };

// 闭包（类型推断，更简洁）
let is_even_closure = |x| x % 2 == 0;
```
#### 捕获变量
```rust
let mut x: i32 = 10;
let y = 20;

// 1. 不可变借用
let print_sum = || println!("{}", x + y);
print_sum(); // 可以多次调用
x = 20;//如果将来还想要调用这个闭包,那么x就不能被修改
print!("{}x现在的值是\n",x);
// 2. 可变借用
let mut z = 5;
let mut add_to_z = |n| { z += n; z };
add_to_z(3); // z 现在是 8

// 3. 移动所有权（使用 move 关键字）
let s = String::from("hello");
let take_ownership = move || println!("{}", s);
take_ownership();
```
> 由于rust的所有权机制,变量还在捕获期间就不能被使用



### 6. 模块系统
> rust的模块系统类似于cpp的命名空间,但是更强大
```rust
mod my_module {//这个是定义一个模块,类似cpp的namespace
    pub fn my_function() {//这个是模块里面的函数,类似cpp的namespace里面的函数
        println!("Hello from my_module!");
    }
} 
```
> 使用模块的时候需要使用use关键字引入,类似cpp的using namespace
```rust
use my_module::my_function;//引入模块里面的函数 
```
- 下面是几个常用的路径前缀
* `self::`：当前模块
* `super::`：父模块
* `crate::`：当前 crate 的根模块（整个包的最顶层）

## 基本数据类型

### 1. 数组
```rust
let a = [0; 1000];//这个是创建了一个连续的数组
let b = [1,2,3,4];//这个是创建了一个有4个元素的数组
let a = [1, 2, 3, 4, 5];

let nice_slice = &a[1..4];

assert_eq!([2, 3, 4], nice_slice)
//这个是切片
```
- 关于数组的迭代
```rust
let v: Vec<&str> = r.split(',').collect();
for it in v.iter() {
    println!("{} ",it)
}
```
### 2. 向量
```rust
let mut v: Vec<i32> = Vec::new(); // 创建一个空的向量
v.push(1); // 添加元素
v.push(2);
let v = vec![10, 20, 30, 40]; // 向量声明
```
- 和数组不同的是,向量是可以动态增长的,所以他是保存在堆里面的

- 数组的迭代

```rust
// let v = vec![10, 20, 30, 40]; // 向量声明
let v: Vec<i32> = (1..).filter(|x| x % 2 == 0).take(5).collect();
//使用迭代器生成向量,(1..)是一个无限迭代器,filter是过滤出偶数,然后take取前5个,最后collect收集成一个向量

for element in v.iter_mut() {
    // multiplied by 2.
    *element *= 2;
}
```


---

## 1. 结构体
> 由于其他的结构体和cpp的差不多,只是说一下他的UnitLikeStruct
### 1.1定义
```rust
struct UnitLikeStruct;
```

## 2. 枚举类型option
>存在的目的:强制让编程的人来处理所有的情况
```rust
struct User {
    name: String,
    age: Option<u32>,  // 年龄可能未知
}

impl User {
    fn new(name: &str) -> Self {
        User {
            name: name.to_string(),
            age: None,
        }
    }
    
    fn with_age(name: &str, age: u32) -> Self {
        User {
            name: name.to_string(),
            age: Some(age),
        }
    }
    
    fn display_age(&self) {
        match self.age {
            Some(age) => println!("{} 的年龄是 {} 岁", self.name, age),
            None => println!("{} 的年龄未知", self.name),
        }
    }
}

fn main() {
    let user1 = User::new("Alice");
    let user2 = User::with_age("Bob", 25);
    
    user1.display_age(); // Alice 的年龄未知
    user2.display_age(); // Bob 的年龄是 25 岁
}
```
> 这里关注age的类型是option ,这枚举默认是包括some 和none,所以我们可以有效处理空指针的问题
> 类似cpp的enum,但是rust使用这个的目的是强制程序员处理所有的情况,避免空指针异常
```rust
fn maybe_icecream(time_of_day: u16) -> Option<u16> {
    // We use the 24-hour system here, so 10PM is a value of 22 and 12AM is a
    // value of 0 The Option output should gracefully handle cases where
    // time_of_day > 23.
    // TODO: Complete the function body - remember to return an Option!
    if time_of_day > 23 {
        None
    } else if time_of_day < 22 {
        Some(5)
    } else {
        Some(0)
    }
}
```
- 如果想要从一个option类型中获取值,可以使用match ,if let, while let等语法结构 
```rust
fn main() {
    let icecream_time = maybe_icecream(21);
    match icecream_time {
        Some(minutes) => println!("Ice cream will be ready in {} minutes.", minutes),
        None => println!("No ice cream available at this time."),
    }
    let target = "rustlings";
    let optional_target = Some(target);

    if let Some(word) = optional_target {
        assert_eq!(word, target);
    }

    let range = 10;
    let mut optional_integers: Vec<Option<i8>> = vec![None];

    for i in 1..(range + 1) {
        optional_integers.push(Some(i));
    }

    let mut cursor = range;

    while let Some(Some(integer)) = optional_integers.pop() {
        assert_eq!(integer, cursor);
        cursor -= 1;
    }

}

```
- 如果不想要损坏原来的option变量,可以使用ref关键字来获取引用
```rust
let y: Option<Point> = Some(Point { x: 100, y: 200 });

match y {
    Some(ref p) => println!("Co-ordinates are {},{} ", p.x, p.y),
    _ => panic!("no match!"),
}//使用Some(ref p)避免移动所有权

y; // Fix without deleting this line.
```



## 3. if 表达式
> 非常有意思的三目运算符
```rust
let identifier = if animal == "crab" {
    1
} else if animal == "gopher" {
    2
} else if animal == "snake" {
    3
} else {
    0
};
//这个说明rust的代码块也是有值的,所以可以直接赋值给一个变量,类似的在函数最后写上一个表达式也是同理
```

## 4. match 
> 类似cpp的switch 但是更强大
```rust
let number = 13;
match number {
    1 => println!("One"),
    2 | 3 | 5 | 7 | 11 => println!("This is a prime"),
    13..=19 => println!("A teen"),
    _ => println!("Ain't special"),
}
//是枚举一个变量的所有可能值,然后_代表剩下的情况

enum PokerCard {
Clubs(u8),
// Spades(u8),
// Diamonds(u8),
Hearts(u8)
}

fn main() {
    let card = PokerCard::Hearts(5);  // 使用match可以看出,一个enum代表一个数据类型,里面的Clubs,hearts是值
    match card {
        PokerCard::Hearts(value) => println!("Hearts with value {}", value),
        _ => println!("Other card"),
    }
}

```

- match还可以使用表达式进行匹配 
```rust
match value {
    // x if x < 0 => Err(CreationError::Negative),
    0 => Err(CreationError::Zero),
    x if x > 0 => Ok(PositiveNonzeroInteger(x as u64)),
    _ => Err(CreationError::Negative)//这个是占位的值
}
```

- 再来看cpp的
```cpp
enum class Color {
    Red, Green, Blue  // 只能有离散值
};
Color c = Color::Red;
switch(c) {
    case Color::Red: /* ... */ break;
    case Color::Green: /* ... */ break;
    // 必须处理所有情况或提供 default
}//但是cpp不能携带数据

```



## 5. HashMap 哈希表
> 首先看一下这个数据结构
- 哈希函数: 将键映射到哈希值的函数
    - 直接定址法: 使用键作为数组索引
    - 链地址法: 每个数组位置存储一个链表，解决冲
> 总而言之就是一个键值对存储结构
```rust
use std::collections::HashMap;  
let mut basket = HashMap::new();

basket.insert(String::from("apple"), 3);//直接插入的方法

// 将 &str 转换为 String 后再使用
if !basket.contains_key("banana") {
    basket.insert(String::from("banana"), 5); // 可以设置任意非零值
}

let entry = basket.entry(String::from("pear")).or_insert(0);
*entry += 2;

println!("{:?}", basket);
```

## 6. 错误处理
> rust中错误处理主要有两种方式:panic 和Result类型
- panic: 用于不可恢复的错误,会立即终止程序
- Result: 用于可恢复的错误,是一个枚举类型,有Ok和Err两个变体
```rust
pub fn total_cost(item_quantity: &str) -> Result<i32, ParseIntError> {
    let processing_fee = 1;
    let cost_per_item = 5;
    let qty = item_quantity.parse::<i32>()?;

    Ok(qty * cost_per_item + processing_fee)
}
```
> 这里的?操作符用于简化错误传播,如果parse失败,会自动返回Err(之后的汉航速),否则继续执行
- 下面的例子表示在一个函数返回Result类型的时候？会直接捕捉错误并返回
```rust
fn main() -> Result<(), ParseIntError>{
    let mut tokens = 100;
    let pretend_user_input = "8";

    let cost = total_cost(pretend_user_input)?;

    if cost > tokens {
        println!("You can't afford that many!");
    } else {
        tokens -= cost;
        println!("You now have {} tokens.", tokens);
    }
    Ok(())
}

pub fn total_cost(item_quantity: &str) -> Result<i32, ParseIntError> {
    let processing_fee = 1;
    let cost_per_item = 5;
    let qty = item_quantity.parse::<i32>()?;

    Ok(qty * cost_per_item + processing_fee)
}
```
### 关于 `Result<T, E>` 的两个参数

- `Result<T, E>` 是一个泛型枚举，有两个类型参数：

    - **`T`**：成功时返回的数据类型（"T" 代表 Type）
    - **`E`**：失败时返回的错误类型（"E" 代表 Error）

- `Result<i32, ParseIntError>` 表示：
  - 成功时返回 **`i32`** 整数

  - 失败时返回 **`ParseIntError`** 错误

- `Result<(), ParseIntError>` 表示：

  - 成功时返回 **`()（空值，表示"没有数据"）`**

  - 失败时返回 **`ParseIntError 错误`**
  
> 简而言之,这个就是Result<T, E> 对应程序可能返回的结果,一个是正常运行的结果一个是我们定义的异常
```rust
fn main() -> Result<(), Box<dyn error::Error>> {//
    let pretend_user_input = "42";
    let x: i64 = pretend_user_input.parse()?;
    println!("output={:?}", PositiveNonzeroInteger::new(x)?);
    Ok(())
}
```

**`Box<dyn error::Error>` 的含义：**

- `Box<T>`：一个在堆上分配的指针
- `dyn error::Error`：任何实现了 `Error` trait 的类型

- **`关于map_err的使用`** 
> 如果是正常的值他直接返回,如果是error类型他会调用我们传入的函数进行转换 
```rust
let x: i64 = s.parse().map_err(ParsePosNonzeroError::from_parseint)?;
PositiveNonzeroInteger::new(x).map_err(ParsePosNonzeroError::from_creation)

```

## 7. 泛型
> 泛型是指在定义函数,结构体,枚举等的时候不指定具体的类型,而是在使用的时候指定类型
```rust
struct Wrapper<T> {
    value: T,
}

// 为泛型类型 T 实现方法
impl<T> Wrapper<T> {
    pub fn new(value: T) -> Self {
        Wrapper { value }
    }
}

```

## 8. traits

> trait类似于cpp的接口,但是更强大
```rust
trait AppendBar {//这个是traits的名字,我一般把traits理解为一个集合,集合的元素是一些方法的定义
    fn append_bar(self) -> Self;
}

impl AppendBar for String {//这个是AppendBar trait的一个实现,实现的是String类型
    fn append_bar(mut self) -> Self {
        self.push_str("Bar");
        self
    }
}
```

- traits可以使用默认的再去覆盖(类似cpp的虚函数)
```rust
pub trait Licensed {
    fn licensing_info(&self) -> String {
        String::from("Some information")
    }
}

struct SomeSoftware {
    version_number: i32,
}

struct OtherSoftware {
    version_number: String,
}

impl Licensed for SomeSoftware {} // Don't edit this line
impl Licensed for OtherSoftware {} // Don't edit this line
```

- 函数参数使用traits
```rust
pub trait Licensed {
    fn licensing_info(&self) -> String {
        "some information".to_string()
    }
}

struct SomeSoftware {}

struct OtherSoftware {}

impl Licensed for SomeSoftware {}
impl Licensed for OtherSoftware {}

// YOU MAY ONLY CHANGE THE NEXT LINE
fn compare_license_types(software: impl Licensed, software_two: impl Licensed) -> bool {
    software.licensing_info() == software_two.licensing_info()
}
fn compare_license_information() {
    let some_software = SomeSoftware {};
    let other_software = OtherSoftware {};

    assert!(compare_license_types(some_software, other_software));
}
//说明：因为两个类都有Licensed方法，所以可以满足上面的函数的参数要求
fn some_func(item: impl SomeTrait + OtherTrait) -> bool {
    item.some_function() && item.other_function()
}//这样是要求item同时实现了两个trait
```


## 9. test

### 基本使用

```rust
#[test]
fn you_can_assert() {
    assert!(true);
    assert_eq!(1,1);//断言两个值相等
    panic!("Rectangle width and height cannot be negative!");//panic直接退出，相当于cpp的throw
}

```

- 关于unsafe代码块
> rust的编译器很保守,有些操作编译器无法保证是安全的,所以需要我们手动标记unsafe代码块

`todo!("The rest of the code goes here");` **表示这个地方的代码还没有写完,运行到这里会直接panic**

- 可以在build.rs文件中添加一些编译时的检查
```rust 
fn main() {
    // In tests7, we should set up an environment variable
    // called `TEST_FOO`. Print in the standard output to let
    // Cargo do it.
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs(); // What's the use of this timestamp here?
    // let your_command = format!(
    //     "Your command here with {}, please checkout exercises/tests/build.rs",
    //     timestamp
    // );
    // println!("cargo:{}", your_command);
    println!("cargo:rustc-env=TEST_FOO={}", timestamp);

    // In tests8, we should enable "pass" feature to make the
    // testcase return early. Fill in the command to tell
    // Cargo about that.
    let your_command = "rustc-cfg=feature=\"pass\"";
    println!("cargo:{}", your_command);
}

```

- rust的链接
```rust
extern "Rust" {
    // #[link_name = "my_demo_function"]  
    fn my_demo_function(a: u32) -> u32;

    #[link_name = "my_demo_function"]//把他也链接到
    fn my_demo_function_alias(a: u32) -> u32;
}

mod Foo {
    // No `extern` equals `extern "Rust"`.
    #[no_mangle] 
    fn my_demo_function(a: u32) -> u32 {
        a
    }
}


```

## 10. 生命周期
> 生命周期是rust用来保证引用有效性的机制,通过标注生命周期参数,编译器可以检查引用在使用时是否仍然有效,防止悬垂引用
> 生命周期参数的语法是使用单引号加一个小写字母,通常使用'a,'b等表示
```rust
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {//本质上是告诉编译器,x和y的生命周期至少和返回值一样长,但是这个只是一个大饼,实际上他可能生命周期不对
    if x.len() > y.len() {
        x
    } else {
        y
    }
}

struct Book <'a>{
    author: &'a str,
    title: &'a str,
}//发现其实生命周期的问题在使用引用的时候经常出现,可能是和指针相关
```

## 11. 迭代器
> 迭代器是rust中用于遍历集合数据结构的工具,它提供了一种统一的方式来访问集合中的元素,而不需要暴露集合的内部结构
```rust
let my_fav_fruits = vec!["banana", "custard apple", "avocado", "peach", "raspberry"];   
let mut my_iterable_fav_fruits = my_fav_fruits.iter();   
my_iterable_fav_fruits.next();//这个每次调用都会返回下一个元素,返回的是一个Option类型
//开始的时候指针指向第一个元素,调用next会返回Some(&"banana"),然后指针向后移动

```

- 发现迭代器可以链式调用
```rust
let numbers = vec![1, 2, 3, 4, 5];
let doubled_numbers: Vec<i32> = numbers
    .iter() // 获取一个不可变引用的迭代器
    .map(|&x| x * 2) // 将每个元素乘以 2
    .collect(); // 收集结果到一个新的向量   
(1..=num).fold(1, |acc, x| acc * x)//rust创建循环小妙招,有等于号表示包含结束值,没有的话就是不包含
// iterator.fold(初始值, |累积值, 下一个元素| { ... }) {}中的内容表示当前这步要怎么做,下一个元素是由iterator给出的

```
- 迭代器还可以有过滤功能
```rust
fn count_collection_iterator(collection: &[HashMap<String, Progress>], value: Progress) -> usize {
    // collection is a slice of hashmaps.
    // collection = [{ "variables1": Complete, "from_str": None, ... },
    //     { "variables2": Complete, ... }, ... ]
    collection
        .iter()
        .flat_map(|map| map.values())
        .filter(|&&v| v == value)//这里是拿&&去匹配一个对象,所以v返回的其实是原来的对象
        .count()
}

```

## 12. 多线程
> cpp里面的多线程会发生数据竞争,而rust通过所有权机制和借用规则来防止数据竞争
- 想在线程间共享 → 必须 Arc<T>

- 想修改共享数据 → 必须 Mutex<T> 或其他同步原语
```rust
let mut status = status_shared.lock().unwrap();
status.jobs_completed += 1;
```
`.lock()` 会返回一个 “智能指针” - **MutexGuard** 

当 guard 离开作用域，Rust 会自动解锁。

```rust
let status = Arc::new(Mutex::new(JobStatus { jobs_completed: 0 }));
let mut handles = vec![];
for _ in 0..10 {
    let status_shared = Arc::clone(&status);
    let handle = thread::spawn(move || {
        thread::sleep(Duration::from_millis(250));

        // 在更新共享数据之前必须先 lock
        let mut status = status_shared.lock().unwrap();
        status.jobs_completed += 1;//这个时候可以把他当成是正常的变量来访问
    });

    handles.push(handle);
}
```

## 13. 智能指针
> 智能指针是rust中用于管理内存和资源的特殊数据类型
- Box<T>: 用于在堆上分配内存,适合存储大小在编译时已知的数据类型
```rust
pub enum List {
    Cons(i32, Box<List>),
    Nil,
}
```

### 13.2 Cow<T>
#### 🟦 1. 情况一：**borrowed & mutated → clone → Owned**

```rust
let slice = [-1, 0, 1];
let mut input = Cow::from(&slice[..]);
abs_all(&mut input);
```

因为 `-1` 需要变成 `1`，Cow 不允许修改 borrowed 数据 → clone → `Owned`.

---

#### 🟩 2. 情况二：**borrowed & no mutation → Borrowed**

```rust
let slice = [0, 1, 2];
let mut input = Cow::from(&slice[..]);
```

没有负数，不需要 to_mut()，所以：

```
还是 borrowed，不 clone
```

---

#### 🟨 3. 情况三：**owned & no mutation → Owned**

```rust
let slice = vec![0, 1, 2];
let mut input = Cow::from(slice);
```

它本来就是 owned，不需要 clone，也不会变成 borrowed，所以依旧：

```
Owned
```

---

#### 🟥 4. 情况四：**owned & mutated → Owned**

```rust
let slice = vec![-1, 0, 1];
let mut input = Cow::from(slice);
```

to_mut() 只是返回原本的 vec 的可变引用，不会 clone。

## 14. 宏
> 声明宏的关键字
```rust
// macro_rules!是声明的关键字

macro_rules! my_macro {//这里的my_macro就是宏的名字
    () => {
        println!("Check out my macro!");
    };
}

fn main() {
    my_macro!();//调用宏的时候需要加上!
}

```

## 14. clippy


### 🧰 Clippy 是啥？

**Clippy** 是 Rust 官方提供的一组“智能提示 / 代码体检工具”（lints）：

* 它会在你代码**能编译**的前提下，继续帮你找：

  * 常见错误
  * 不优雅 / 不符合惯用法的写法
  * 潜在 bug
* 通过 `cargo clippy` 运行。
* 在 rustlings 的 clippy 练习里，**只要 Clippy 报 warning 就当成错误**，所以你必须把 warning 也修掉才能通过。

简单说：

> `rustc` 负责“你这玩意能不能跑”；
> `clippy` 负责“你这玩意写得像不像个 Rustacean 写的”。

> `ps:`Rustacean 是 Rust 程序员的自称，类似 C++ 程序员自称为 C++er,他就是让我们写得专业点
---

```rust
let pi = std::f32::consts::PI;//1要用好编译器的常量
let option = Some(12);
if let Some(x) = option {//2使用if let来处理option类型,他还自己带有一种匹配
    res += x;
}
let my_option: Option<()> = None;
if my_option.is_none() {//3不要犯病写出逻辑问题
    my_option.unwrap();
}

let mut value_a = 45;
let mut value_b = 66;
std::mem::swap(&mut value_a, &mut value_b);//4学会使用标准库的函数

```

## 15. 转化(conversions)
> rust中有很多类型转换的方式,主要有as,from,into,as_ref,as_mut等


- `as`: 用于基本类型之间的转换
```rust
let x: i32 = 10;
let y: u32 = x as u32;//把i32转换成u32
```

- `from`: 用于类型之间的转换,通常用于实现From trait的类型

```rust
let s = String::from("hello");//把字符串字面量转换成String类型
let num = u32::from(42u8);//把u8转换成u32
```

- `into`: 和from相反,通常用于实现Into trait的类型
```rust
let s: String = "hello".into();//把字符串字面量转换成String类型
let num: u32 = 42u8.into();//把u8转换成u32
```

- `as_ref`: 用于获取引用类型的转换
```rust
let s = String::from("hello");
let s_ref: &str = s.as_ref();//把String类型转换成&str类型

//关于自动解析引用
```

- `as_mut`: 用于获取可变引用类型的转换
```rust
let mut s = String::from("hello");
let s_mut: &mut str = s.as_mut_str();//把String类型转换成&mut str类型
``` 

//TODO
> 还有quiz1 2 3
> algorithms 
