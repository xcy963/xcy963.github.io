# 🦀写内核的时候收集的rust语法

```{note}
为了操作系统大赛!!!
```

## 创建数组元素,然后收集他们的指针

- 先看代码
```rust
fn to_cstr_bytes(s: &str) -> Vec<u8> {
    let mut v = s.as_bytes().to_vec();
    v.push(0); // NUL terminator
    v
}
let mut cstr_storage: Vec<Vec<u8>> = Vec::new();
cstr_storage.push(to_cstr_bytes("/glibc/busybox")); // argv[0] 通常放程序名/路径
cstr_storage.push(to_cstr_bytes("echo"));           // busybox 的 applet
cstr_storage.push(to_cstr_bytes("#### OS COMP TEST GROUP START basic-glibc ####"));
let mut argv: Vec<*const u8> = cstr_storage.iter().map(|v| v.as_ptr()).collect();
argv.push(core::ptr::null()); 
exec("/glibc/busybox", &argv);
```
- 这里`cstr_storage`是一个列表,他的元素是u8列表,我们使用迭代器,然后对每一个迭代元素施加一个lambda表达式
### 细节解析

- 1. Iterator trait
  - 如果想要对一个对象使用`.iter()`方法,那么他必须要实现这个traits
- 2. map之后其实还没有产生我们需要的数据
  - map方法作用之后返回的是一个特殊的类型`Map<Iter<_>, _>`,只有在调用`collect`的时候才会对其中的数据有真实的操作
  - 返回的元素是map的表达式返回的元素,然后封装成为`vec`
- 3. 从生命周期的角度去看这个问题
  - `"/glibc/busybox"`是`.data`段的东西,生命周期无所谓
  - `to_cstr_bytes("/glibc/busybox")`在堆上面,他的生命周期由`cstr_storage`保证
  - `cstr_storage`在堆上,他的生命周期由`argv`保证
  - 函数调用的时候所有权变化了,`argv`的生命周期由函数内的使用保证,`exec`返回的时候会`drop`argv,再`drop`上面的一系列东西
  
## 关于所有权机制
```{note}
在rust里面变量的所有权会使得一个变量进入函数的作用域之后,在函数返回的时候直接drop
- 也就是进行函数调用会默认销毁一个变量
```

- 但是我们想要函数调用不使这个变量销毁,我们可以传入这个变量的可变引用
```rust
fn process_oneline( line: &String ){}
match c {
  LF | CR => {//输入回车就开始解析输入
      println!("");//先换行不然终端的输出会很奇怪
      if !line.trim().is_empty() {//非空就开始解析
          history.push(line.clone());
          history_index = history.len();//处理这个方便使用上下键
          process_oneline(&line);    
      }
      line.clear();
      print_prompt("");
  }
}
```

## 关于迭代器

- 先看一个从slice创建迭代器的方法
```rust
let mut parts = lines[idx].split_whitespace();
parts.next(); // 把for去掉,现在指向遍历的变量,这里调用next使得指针移位
let var = match parts.next() {//解析遍历的变量
    Some(v) => v,
    None => return idx + 1,//解析到最后了就返回
};
if parts.next() != Some("in") {
    return idx + 1;//确保是in,其实应该直接报error的
}
let mut values: Vec<String> = Vec::new();
for value in parts {//使用for循环直接访问剩下的
    values.push(expand_string(value, ctx, false));
}
```

```{note}
把迭代器理解成一个指针就好,他实现了next方法,可以把指针移动到下一个目标
```

- 迭代器的其他用法
```rust
if let Some(body_start) = lines[idx + 1..]
    .iter()//创建迭代器
    .position(|l| l.trim() == "do")//返回相对坐标,传入的参数是迭代器的元素,lambda表达式的返回一定要是bool的
{//定位到do,body_start是相对坐标
}
```

## 开始busybox
### 关于bitflags
- 先看一个案例
```rust
bitflags! {
    ///  The flags argument to the open() system call is constructed by ORing together zero or more of the following values:
    pub struct OpenFlags: u32 {
        /// readyonly
        const RDONLY = 0;
        /// writeonly
        const WRONLY = 1 << 0;
        /// read and write
        const RDWR = 1 << 1;
        /// create new file
        const CREATE = 0x40;
        /// truncate file size to 0
        const TRUNC = 0x200;
        /// open directory
        const DIRECTORY = 0x10000;
    }
}
```
```{note}
`OpenFlags`要求每个成员只能使用一个二进制位,从10进制的角度看就是要求他们都是2的幂次
```
