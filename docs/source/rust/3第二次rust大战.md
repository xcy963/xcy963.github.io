# 🦀第二次rust大战

## 提示笔记

### 1. 全局变量一定要指明变量类型
```rust
const NUMBER:i32 = 3;

fn main() {
    println!("Number: {NUMBER}");
}
```

### 2. 关于rust的mut
- 仅仅是起到一个提示编译器的作用,而且这个mut是可以改变的

```rust
fn fill_vec(vec:  Vec<i32>) -> Vec<i32> {
    let mut vec = vec;
    vec.push(88);
    vec
}

```

### 3. rust的引用机制

- 不能同时有两个引用
```rust
let mut x = Vec::new();
let y = &mut x;
y.push(42);
let z = &mut x;//不能同时存在两个引用,除非有实现锁
z.push(13);
assert_eq!(x, [42, 13]);
```

- 引用不传递所有权

```rust
let data = "Rust is great!".to_string();
get_char(&data);
string_uppercase(data);
```

### 4. rust debug 模式下的特殊输出

```rust
enum Message {
    Resize { width: u64, height: u64 },
    Echo(String),
    Quit,
}

impl Message {//这里看似是对一整个类型实现的,但是其实一个enum变量只能是一种类型,不能把他当作结构体来看待
    fn call(&self) {
        println!("{self:?}");//格式化捕获变量
    }
}

fn main() {
    let messages = [
        Message::Resize {
            width: 10,
            height: 30,
        },
        Message::Move(Point { x: 10, y: 15 }),
        Message::Echo(String::from("hello world")),
        Message::ChangeColor(200, 255, 255),
        Message::Quit,
    ];

    for message in &messages {
        message.call();
    }
}
```
- 输出是

```text
Resize { width: 10, height: 30 }
Echo("hello world")
Quit
```

### 5. 字符串加法的所有权转移

```rust
let a = String::from("hello"); 
let b = String::from("world");

let c = a.clone() + " " + &b; // + 左边 String 会被 转移所有权(所以使用clone)
```

### 6. box
```{note}
在rust里面编译期不确定数据字节大小的变量需要box
```
```rust

fn foo() -> Result<(), Box<dyn Error>> {
    // ...
    Ok(())
}

let b = Box::new(123);  // b: Box<i32>
println!("{}", *b);     // 解引用得到 i32

```


### 7. rust里面的pi

```rust
let pi = std::f32::consts::PI;
```

### 8. rust里面的类型转化
- 使用as
```rust
fn average(values: &[f64]) -> f64 {
    let total = values.iter().sum::<f64>();
    total / values.len() as f64
}
```

### 9. rust里面的范围判断

```rust
if !(0..=255).contains(&r) || !(0..=255).contains(&g) || !(0..=255).contains(&b) {
    return Err(IntoColorError::IntConversion);
}

```

## 变量


### Shadowing

```rust
fn main() {
    let number = "T-H-R-E-E"; // Don't change this line
    println!("Spell a number: {number}");

    let number = 3;//直接修改这个数据类型,底层就是地址相同,但是上面的值以及编译器对于他的解释不同
    println!("Number plus two is: {}", number + 2);
}
```

## 条件判断

### if and elseif

```rust
fn picky_eater(food: &str) -> &str {
    if food == "strawberry" {
        "Yummy!"
    } else if food == "potato"{//不用加上括号
        "I guess I can eat that."
    } else {//一定要有else
        "No thanks!"
    }
}
```

### match

## vector

### 容器的几种初始化方式

```rust
use std::collections::{HashMap, HashSet, VecDeque};

fn main() {
    // 1) 空容器
    let v1: Vec<i32> = Vec::new();
    let m1: HashMap<&str, i32> = HashMap::new();
    let s1: HashSet<&str> = HashSet::new();

    // 2) 宏直接初始化（最常用）
    let v2 = vec![1, 2, 3];
    let v3 = vec![0; 5]; // [0, 0, 0, 0, 0]

    // 3) 指定容量（减少扩容次数）
    let mut v4: Vec<i32> = Vec::with_capacity(10);
    v4.push(42);

    // 4) 从迭代器 collect 初始化
    let v5: Vec<i32> = (1..=5).collect();
    let s2: HashSet<i32> = [1, 2, 2, 3].into_iter().collect(); // 去重后 {1,2,3}

    // 5) 从键值对数组初始化 HashMap
    let m2: HashMap<&str, i32> = [("alice", 100), ("bob", 90)].into_iter().collect();

    // 6) 其他容器：VecDeque
    let mut q: VecDeque<i32> = VecDeque::from([1, 2, 3]);
    q.push_front(0);

    let _ = (v1, m1, s1, v2, v3, v4, v5, s2, m2, q);
}
```


### 数组切片

```rust
let a = [1, 2, 3, 4, 5];
let nice_slice = &a[1..4];
assert_eq!([2, 3, 4], nice_slice);
```

### 容器访问语法

```{note}
- 下面介绍下两种不同的容器

```rust
fn array_and_vec() -> ([i32; 4], Vec<i32>) {
    let a = [10, 20, 30, 40]; // Array

    // TODO: Create a vector called `v` which contains the exact same elements as in the array `a`.
    // Use the vector macro.
    let v = vec![10, 20, 30, 40];

    (a, v)
}
```

```rust
use std::collections::{HashMap, VecDeque};

fn main() {
    // Vec / 数组：下标访问
    let v = vec![10, 20, 30];
    let a = [1, 2, 3, 4];//原生定长数组
    let x = v[1]; // 20
    let y = a[2]; // 3

    // Vec::get：安全访问（返回 Option）
    let ok = v.get(2); // Some(&30)
    let miss = v.get(99); // None

    // 切片访问（区间）
    let part = &a[1..3]; // &[2, 3]

    // HashMap：按 key 访问
    let mut score = HashMap::new();
    score.insert("alice", 100);
    score.insert("bob", 90);
    let alice = score.get("alice"); // Some(&100)
    let tom = score.get("tom"); // None

    // HashMap 可变访问
    if let Some(v) = score.get_mut("bob") {
        *v += 5;
    }

    // VecDeque：首尾访问
    let mut q = VecDeque::from([1, 2, 3]);
    let front = q.front(); // Some(&1)
    let back = q.back(); // Some(&3)
    q.push_front(0);
    q.push_back(4);

    let _ = (x, y, ok, miss, part, alice, tom, front, back);
}
```

### 关于迭代器

```{note}
只要数据类型实现了 traits: `IntoIterator`，就可以在 `for` 中遍历，也可以手动调用 `.into_iter()` 进入迭代器链式处理。
```

- 简单的使用案例汇总
```rust
fn main() {
    let nums = vec![1, 2, 3, 4, 5, 6];

    // 1) map: 映射
    let doubled: Vec<i32> = nums.iter().map(|x| x * 2).collect();

    // 2) filter: 过滤
    let evens: Vec<i32> = nums.iter().copied().filter(|x| x % 2 == 0).collect();

    // 3) find / any / all
    let first_gt_4 = nums.iter().find(|&&x| x > 4); // Some(&5)
    let has_odd = nums.iter().any(|x| x % 2 == 1); // true
    let all_positive = nums.iter().all(|x| *x > 0); // true

    // 4) fold: 归约
    let sum = nums.iter().fold(0, |acc, x| acc + x);

    // 5) take / skip / enumerate
    let first_three: Vec<i32> = nums.iter().copied().take(3).collect();
    let after_two: Vec<i32> = nums.iter().copied().skip(2).collect();
    for (idx, val) in nums.iter().enumerate() {
        println!("idx={idx}, val={val}");
    }

    // 6) 链式组合
    let result: Vec<i32> = nums
        .into_iter()
        .filter(|x| x % 2 == 0)
        .map(|x| x * x)
        .collect(); // [4, 16, 36]

    let _ = (doubled, evens, first_gt_4, has_odd, all_positive, sum, first_three, after_two, result);
}
```


## rust的数组 元组 uni_struct

### 初始化
```rust
struct ColorRegularStruct {
    red: u8,
    green: u8,
    blue: u8,
}
struct ColorTupleStruct(u8,u8,u8);
struct UnitStruct;

let green = ColorRegularStruct {
    red: 0,
    green: 255,
    blue: 0,
};

let green =ColorTupleStruct(0,255,0);
let unit_struct = UnitStruct;
```

### 更新语法

```rust
let your_order = Order {
    name: String::from("Hacker in Rust"),
    count: 1,
    //使用..order_template表示剩下的
    ..order_template
};
```

## enum

### 初始化

```rust
//最简单的enum
enum Message {
    Resize,
    Move,
    Echo,
    ChangeColor,
    Quit
}

// 带有存储信息的enum
enum Message {
    // TODO: Define the different variants used below.
    Resize { width: u64, height: u64 },
    Move(Point),
    Echo(String),
    ChangeColor(u8, u8, u8),
    Quit,
}

impl Message {//可以为enum实现统一的方法
    fn call(&self) {
        println!("{self:?}");//格式化捕获变量
    }
}

```

### 调用match

```rust
fn process(&mut self, message: Message) {
    // TODO: Create a match expression to process the different message
    // variants using the methods defined above.
    match message {//顺便自动解析
        Message::Resize { width, height } => self.resize(width, height),
        Message::Move(point) => self.move_position(point),
        Message::Echo(s) => self.echo(s),
        Message::ChangeColor(r, g, b) => self.change_color(r, g, b),
        Message::Quit => self.quit(),
    }
}
```

## 字符串

### 几个和字符串相关的数据类型

- `String`：可增长、可修改，存储在堆上。
- `&str`：字符串切片，通常是不可变借用，常用于函数参数。
  - 这一般底层就是一个指针,指向一个字符串数组的首地址
- `str`：动态大小类型（DST），几乎不会单独使用，通常以 `&str` 形式出现。
- `char`：单个 Unicode 标量值，占 4 字节，不等于“1 字节字符”。

```rust
//简单的例子
fn main() {
    let s1: &str = "hello";          // 字符串字面量，类型是 &'static str
    let mut s2: String = String::new();
    s2.push_str("hello");
    s2.push(' ');
    s2.push_str("rust");

    let c: char = '你';
    println!("{s1}, {s2}, {c}");
}
```

- **如果想要做字符串比较**

```rust
//最好转化为&str,这个类型不会有所有权等等问题
if let Some(fsname) = fstype.as_deref() {//转化成字符串引用
    if fsname == "error" || fsname == "overlay" {
        return ENODEV;
    }
}
```


- 相互转化
```rust
fn main() {
    // &str -> String
    let s1: &str = "hello";
    let s2: String = s1.to_string();
    let s3: String = String::from(s1);

    // String -> &str（借用，不转移所有权）
    let s4: &str = &s2;          // 等价于 s2.as_str()
    let s5: &str = s2.as_str();

    // String -> Vec<u8>（拿走所有权）
    let bytes1: Vec<u8> = s3.into_bytes();

    // &str -> Vec<u8>（借用后复制）
    let bytes2: Vec<u8> = s4.as_bytes().to_vec();

    // UTF-8 bytes -> String
    let s6 = String::from_utf8(bytes1).expect("invalid utf-8");

    // String <-> char 不是直接互转：通常用 chars() 或 push()
    let first: Option<char> = s6.chars().next(); // String -> char
    let mut one = String::new();
    one.push('你'); // char -> String

    // char -> u32（Unicode 码点）
    let code: u32 = 'A' as u32;
    println!("{s5} {bytes2:?} {first:?} {one} {code}");
}
```


### String 的创建

```rust
fn main() {
    let a = String::new();
    let b = String::from("hello");
    let c = "world".to_string();
    let d = format!("{b} {c}"); // 推荐拼接方式，不转移 b/c 的所有权
    println!("{a:?} {d}");
}
```

### 借用与所有权（最常见）

```rust
fn len_of(s: &str) -> usize {
    s.len()
}

fn main() {
    let s = String::from("hello");
    let n1 = len_of(&s);       // &String -> &str（自动解引用）
    let n2 = len_of("rust");   // 字面量本来就是 &str
    println!("{n1}, {n2}");
}
```

- 读字符串优先用 `&str` 作为参数类型，兼容性最好。
- 只有确实需要拥有所有权时再用 `String` 参数。

### 常用修改操作

```rust
fn main() {
    let mut s = String::from("hello");
    s.push('!');
    s.push_str(" rust");
    s.insert(0, '[');
    s.insert_str(1, "say ");
    s.pop(); // 删除最后一个字符，返回 Option<char>
    s.replace_range(0..4, "hi");
    let input:str = "I think cars are cool";
    input.replace("cars", "balloons");//替换所有的cars
    println!("{s}");
}
```

### 拼接方式对比

```rust
fn main() {
    let a = String::from("hello");
    let b = String::from("world");

    let c = a.clone() + " " + &b; // + 左边 String 会被 转移所有权(所以使用clone)

    let d = format!("{a} {b}");   // 推荐：清晰且不 交换所有权

    println!("{c}");
    println!("{d}");
}
```

### UTF-8 与索引陷阱

Rust 字符串是 UTF-8 编码，不能直接用下标访问（例如 `s[0]`）。

```rust
fn main() {
    let s = String::from("你好, rust");

    // 1) 按字节遍历
    for b in s.bytes() {
        print!("{b} ");
    }
    println!();

    // 2) 按 Unicode 标量值遍历
    for ch in s.chars() {
        print!("{ch} ");
    }
    println!();
}
```

### 字符串切片

```rust
fn main() {
    let s = String::from("hello");
    let h = &s[0..1];
    let he = &s[..2];
    let lo = &s[3..];
    println!("{h} {he} {lo}");
}
```

- 切片区间必须落在 UTF-8 字符边界上，否则会 panic。
- 对包含中文/emoji 的字符串，优先用 `chars()` 处理逻辑，不要手写字节下标,否则容易乱码


## 哈希表

### 简单的遍历语法
```rust
let fruit_kinds = [
    Fruit::Apple,
    Fruit::Banana,
    Fruit::Mango,
    Fruit::Lychee,
    Fruit::Pineapple,
];
for fruit in fruit_kinds {

    basket.entry(fruit).or_insert(1);
}
```

### 查找对应条目
```rust
let t1 = scores.entry(team_1_name).or_default();
```

## option

### 构造option

```rust
fn maybe_ice_cream(hour_of_day: u16) -> Option<u16> {
    if hour_of_day > 23 {
        None
    } else if hour_of_day >= 22 {
        Some(0)
    } else {
        Some(5)
    }
}

```

### 解析option
```rust
let ice_creams = maybe_ice_cream(12).unwrap();
// ice_creams = ice_creams
assert_eq!(ice_creams, 5); // Don't change this line.
```

### 使用rust的匹配语法解析option

```rust

fn simple_option() {
    let target = "rustlings";
    let optional_target = Some(target);

    //这个是特殊的if他不需要写else
    if let  Some(word) = optional_target {
        assert_eq!(word, target);
    };
}

fn layered_option() {
    let range = 10;
    let mut optional_integers: Vec<Option<i8>> = vec![None];

    for i in 1..=range {
        optional_integers.push(Some(i));
    }

    let mut cursor = range;

    //这里因为pop本身有套一层option 我们的数组本身又是一个option
    while let Some(Some(integer)) = optional_integers.pop() {
        assert_eq!(integer, cursor);
        cursor -= 1;
    };

    assert_eq!(cursor, 0);
}
```

### 使用普通的match会移动所有权

```rust
fn main() {
    let optional_point = Some(Point { x: 100, y: 200 });

    //这里的some需要加上ref来保留所有权
    match optional_point {
        Some(ref p) => println!("Coordinates are {},{}", p.x, p.y),
        _ => panic!("No match!"),
    }

    println!("{optional_point:?}"); // Don't change this line.
}
```

## 错误类型

```{note}
rust的result包括两个部分,第一个是一个基本数据类型,第二个是错误类型
`Result<(), ParseIntError> `
```

### 基本构造
```rust
fn generate_nametag_text(name: String) -> Result<String, String> {
    if name.is_empty() {
        Err("Empty names aren't allowed".to_string())
    } else {
        Ok(format!("Hi! My name is {name}"))
    }
}
```

### 简单的错误抛出

- 简单加一个?就好
```rust
fn total_cost(item_quantity: &str) -> Result<i32, ParseIntError> {
    let processing_fee = 1;
    let cost_per_item = 5;

    let qty = item_quantity.parse::<i32>()?;

    Ok(qty * cost_per_item + processing_fee)
}
```

### error 解析

```rust
//total_cost是上面提到的函数
assert_eq!(
    total_cost("beep boop").unwrap_err().kind(),
    &IntErrorKind::InvalidDigit,
);
```

### 如果一个函数可能返回多个error

```rust
fn main() -> Result<(), Box<dyn Error>>{
    let pretend_user_input = "42";
    let x: i64 = pretend_user_input.parse()?;
    println!("output={:?}", PositiveNonzeroInteger::new(x)?);
    Ok(())
}

```

### 和option对应的也可以使用?抛出错误

```rust
fn parse(s: &str) -> Result<Self, ParsePosNonzeroError> {
    let x: i64 = s.parse().map_err(ParsePosNonzeroError::from_parse_int)?;//这个方法可以重定向错误
    Self::new(x).map_err(ParsePosNonzeroError::from_creation)
}
```

## 泛型

```rust
//注释里面是原来一个特定的写法
// struct Wrapper { 
//     value: u32, 
// }
struct Wrapper<T> {
    value: T,
}
// impl Wrapper {
//     fn new(value: u32) -> Self {
//         Wrapper { value }
//     }
// }
impl<T> Wrapper<T> {
    fn new(value: T) -> Self {
        Wrapper { value }
    }
}
```

## traits

### 一般写法

```rust
trait AppendBar {
    fn append_bar(self) -> Self;
}

impl AppendBar for String {
    fn append_bar(self) -> Self {
        self + "Bar"
    }
}

trait Licensed {
    fn licensing_info(&self) -> String{//可以在定义traits的时候定义一个默认的实现,后续的实现可以覆盖这个也可以沿用
        "Default license".to_string()
    }
}
struct SomeSoftware {
    version_number: i32,
}

struct OtherSoftware {
    version_number: String,
}
impl Licensed for SomeSoftware {} // Don't edit this line.
impl Licensed for OtherSoftware {} // Don't edit this line.
```

### 利用traits统一接口的示范

```rust

fn compare_license_types<T: Licensed, U: Licensed>(software1: T, software2: U) -> bool {
    software1.licensing_info() == software2.licensing_info()
}
fn main(){
    assert!(compare_license_types(SomeSoftware, OtherSoftware));
    assert!(compare_license_types(OtherSoftware, SomeSoftware));
}

//traits可以使用加号来要求同时实现两种
fn some_func<T:SomeTrait + OtherTrait>(item: T) -> bool {
    item.some_function() && item.other_function()
}

```

### 在结构体里面统一接口

```rust
use std::fmt::Display;
struct ReportCard<T: Display> {
    grade: T,
    student_name: String,
    student_age: u8,
}

impl<T: Display> ReportCard<T> {
    fn print(&self) -> String {
        format!(
            "{} ({}) - achieved a grade of {}",
            &self.student_name, &self.student_age, &self.grade,
        )
    }
}
```


## 生命周期

### 关于引用在函数中
- 先看一个有问题的代码
```rust
fn longest(x: &str, y: &str) -> &str {
    if x.len() > y.len() {
        x
    } else {
        y
    }
}
fn main(){
    let r;
    {
        let s1 = String::from("abcd");
        let s2 = String::from("xyz");
        r = longest(s1.as_str(), s2.as_str());
    } // s1 和 s2 在这里都被 drop 了
    println!("{}", r); // 如果允许，就会用到悬垂引用（dangling reference）
}

```

- 所以在rust里面函数的签名需要显式标注这个事情,让编译器能分析出上面的函数应该在这个地方报错

```rust
//一个正确的函数签名还需要定义一个生命周期变量a
fn longest<'a>(x: &'a str, y: &'a str) -> &'a str {
    if x.len() > y.len() { x } else { y }
}
```

- `'static`表示一个特殊的生命周期变量,他修饰的变量的生命周期硬性要求是和程序同寿命的

```rust
fn longest(x: &'static str, y: &'static str) -> &'static str {
    if x.len() > y.len() { x } else { y }
}
let s1 = String::from("abcd");
let s2 = String::from("123");
longest(s1.as_str(), s2.as_str()); // ❌ 不能满足 &'static str
//堆上分配的字符串在这里就不能被调用
```

```{note}
这个生命周期的标注只是给编译器一个标注,并不能实际改变编译的行为,也就是说上面的例子我们必须要手动clone
```

```rust
fn longest(x: &str, y: &str) -> &str {
    if x.len() > y.len() {
        x
    } else {
        y
    }
}
fn main(){
    let r;
    {
        let s1 = String::from("abcd");
        let s2 = String::from("xyz");
        r = longest(s1.as_str(), s2.as_str()).to_string();
    } // s1 和 s2 在这里都被 drop 了
    println!("{}", r); // 如果允许，就会用到悬垂引用（dangling reference）
}
```
### 在结构体里面需要提前声明生命周期变量

```rust
struct Book<'a> {
    author: & 'a str,
    title: &'a str,
}

fn main() {
    let book = Book {
        author: "George Orwell",
        title: "1984",
    };

    println!("{} by {}", book.title, book.author);
}

```


## iter

### 从列表获取迭代器,然后使用next遍历

```rust
fn main(){
    let my_fav_fruits = ["banana", "custard apple", "avocado", "peach", "raspberry"];
    
    let mut fav_fruits_iterator = my_fav_fruits.iter();
    //这里next是指把迭代器的指针移动一个位置,然后返回调用的时候迭代器指针指向的数据
    assert_eq!(fav_fruits_iterator.next(), Some(&"banana"));
}

```
### 迭代器的使用例子

```rust
fn capitalize_first(input: &str) -> String {
    let mut chars: std::str::Chars<'_> = input.chars();//获取到的chars是一个迭代器

    match chars.next() {
        None => String::new(),
        Some(first) => first.to_ascii_uppercase().to_string() + chars.as_str()//这里转化为str之后可以相加
    }
}
fn capitalize_words_vector(words: &[&str]) -> Vec<String> {

    words.iter().map(|w| capitalize_first(w)).collect()//类似cpp的lambda函数,map表示把这个lambda函数应用于输入的slice里面的每一个对象
    //最后需要collect函数来对迭代器应用方法
}
```

### 特殊的闭包写法

```rust
//带有记忆属性的闭包迭代
fn factorial(num: u64) -> u64 {

    (1..num).fold(1, |acc, x| acc * x)
}

```

### 关于迭代器的构造问题

```rust
fn count_collection_iterator(collection: &[HashMap<String, Progress>], value: Progress) -> usize {

    collection.into_iter().map(|map|count_iterator(map,value)).sum()//这个写法是不推荐的,因为对与引用构造into_iter不会转移所有权,所以使用iter会好一些
}

```

- 一般使用

```rust
fn count_collection_iterator(collection: &[HashMap<String, Progress>], value: Progress) -> usize {
    // `collection` is a slice of hash maps.
    // collection = [{ "variables1": Complete, "from_str": None, … },
    //               { "variables2": Complete, … }, … ]
    collection.iter().map(|map| count_iterator(map, value)).sum()
}

```

## 智能指针

### 处理栈内存大小的box

```rust
#[derive(PartialEq, Debug)]
enum List {
    Cons(i32, Box<List>),//这个是无限递归的结构,不能确定他在栈上面需要分配多少的空间
    Nil,
}
```
- 其实这里就是允许结构体上的一个字段是指针

### 处理共享的rc
- 这个好错是Rc::clone()只是复制指针没有复制数据
```rust
fn main(){
    let sun = Rc::new(Sun);
    println!("reference count = {}", Rc::strong_count(&sun)); // 1 reference
    let mercury = Planet::Mercury(Rc::clone(&sun));
    println!("reference count = {}", Rc::strong_count(&sun)); // 2 references

    drop(mercury);
    println!("reference count = {}", Rc::strong_count(&sun)); // 1 reference

    assert_eq!(Rc::strong_count(&sun), 1);
}

```

### 多线程共享数据arc
```{note}
rc作为指针还是只能服务单线程,多线程还是需要arc出手,本质都可以当作指针去使用,也就是使用提供的new和clone
```

```rust
fn main() {
    let numbers: Vec<_> = (0..100u32).collect();

    // TODO: Define `shared_numbers` by using `Arc`.
    let shared_numbers: Arc<Vec<u32>> = Arc::new(numbers);

    let mut join_handles: Vec<thread::JoinHandle<()>> = Vec::new();

    for offset in 0..8 {
        // TODO: Define `child_numbers` using `shared_numbers`.
        let child_numbers: Arc<Vec<u32>> = Arc::clone(&shared_numbers);

        let handle = thread::spawn(move || {
            let sum: u32 = child_numbers.iter().filter(|&&n| n % 8 == offset).sum();
            println!("Sum of offset {offset} is {sum}");
        });

        join_handles.push(handle);
    }

    for handle in join_handles.into_iter() {//这个只是回收线程的,线程在被spawn的那一刻起就在执行了
        handle.join().unwrap();
    }
}

```

```{important}
ARC指针只是解决了多线程冲突里面的数据计数问题,没有解决同时写的那些临界区的控制问题,所以上面的例子也没有真正去写数据
- 其实只是解决了所有权的问题,因为rust约定在move进去一个线程的时候要交接所有权
```

### 写时复制cow

```{tip}
cow和rc的区别是cow不是复制指针,他是复制数据,所以他没有共享计数,在初始化之后指针类型是Owned,有更改需求就触发复制,指针类型是Borrowed
- 由于这里构造cow的时候持有了对象的引用,所以后续不能修改对应对象,保证了cow指针指向的数据不会变化

```



```rust

fn abs_all(input: &mut Cow<[i32]>) {
    for ind in 0..input.len() {
        let value = input[ind];
        if value < 0 {
            // Clones into a vector if not already owned.
            input.to_mut()[ind] = -value;
        }
    }
}

fn main(){

    #[test]
    fn reference_mutation() {
        // Clone occurs because `input` needs to be mutated.
        let vec = vec![-1, 0, 1];
        let mut input = Cow::from(&vec);
        abs_all(&mut input);
        assert!(matches!(input, Cow::Owned(_)));
    }

    #[test]
    fn reference_no_mutation() {
        // No clone occurs because `input` doesn't need to be mutated.
        let vec = vec![0, 1, 2];
        let mut input = Cow::from(&vec);
        abs_all(&mut input);
        // TODO: Replace `todo!()` with `Cow::Owned(_)` or `Cow::Borrowed(_)`.
        assert!(matches!(input, Cow::Borrowed(_)));//遍历一次没有对数据进行操作,仅仅是读取,那么就还是Borrowed
    }
    //如果直接选择使用整个数据构造cow,那么就不会有borrow的情况
    #[test]
    fn owned_no_mutation() {
        let vec = vec![0, 1, 2];
        let mut input = Cow::from(vec);
        abs_all(&mut input);
        assert!(matches!(input, Cow::Owned(_)));
    }

    #[test]
    fn owned_mutation() {
        let vec = vec![-1, 0, 1];
        let mut input = Cow::from(vec);
        abs_all(&mut input);
        assert!(matches!(input, Cow::Owned(_)));
    }   
}
```


```{tip}
如果使用引用构造cow,那么这个时候cow指针持有原来数据的引用,根据rust的规则之后不能修改原来的数据,也就是说cow指针如果一直是`Borrowed`的状态,一定可以推断出原来的数据是没有被修改的
```

## thread线程

### 简单的创建以及解包

```rust

use std::{
    thread,
    time::{Duration, Instant},
};

fn main() {
    let mut handles = Vec::new();
    for i in 0..10 {
        let handle = thread::spawn(move || {
            let start = Instant::now();
            thread::sleep(Duration::from_millis(250));
            println!("Thread {i} done");
            start.elapsed().as_millis()
        });
        handles.push(handle);
    }

    let mut results = Vec::new();
    for handle in handles {
        results.push(handle.join().unwrap());//使用unwrap拿出数据
    }

    if results.len() != 10 {
        panic!("Oh no! Some thread isn't done yet!");
    }

    println!();
    for (i, result) in results.into_iter().enumerate() {
        println!("Thread {i} took {result}ms");
    }
}
```

### 在进程之间操作共享数据

- arc来保证每个线程都能持有一份共享的数据,mutex来保证互斥访问
```rust
use std::{sync::{Arc,Mutex}, thread, time::Duration};

struct JobStatus {
    jobs_done: u32,
}

fn main() {
    let status = Arc::new(Mutex::new(JobStatus { jobs_done: 0 }));

    let mut handles = Vec::new();
    for _ in 0..10 {
        let status_shared = Arc::clone(&status);
        let handle = thread::spawn(move || {
            thread::sleep(Duration::from_millis(250));

            let mut guard = status_shared.lock().unwrap();
            guard.jobs_done += 1;
        });
        handles.push(handle);
    }

    // Waiting for all jobs to complete.
    for handle in handles {
        handle.join().unwrap();
    }

    println!("Jobs done: {}", status.lock().unwrap().jobs_done);//这个部分能直接访问arc指针就使用原始的数据,不需要再clone一份
}

```



## lazy_static懒加载

- 正常是一个宏来控制一些变量只有在第一次用到的时候才加载,通常用于简化static变量的使用流程

```rust
lazy_static! {
    pub static ref INITPROC: Arc<ProcessControlBlock> = {
        let inode = open_file("/user/init_proc.bin", OpenFlags::RDONLY).unwrap();
        let data = inode.read_all();
        ProcessControlBlock::new(&data)
    };
}

```


- 当然如果在某个地方想要直接加载也可以使用

```rust
lazy_static::initialize(&INITPROC);//确保加载

```