# 🪟开发bash
```{note}
尝试使用bash直接加载测例里面的脚本,大工程
```

## 启动的时候运行的进程

- 启动之后fork了一个线程,这个线程一直执行终端脚本(其实应该执行exec的,之后再分离好了,现在先把终端的debug做好)
- 首先先介绍下终端检测的几个特殊字符(都是ascii码)
```rust
const LF: u8 = 0x0au8;//line feed就是'\n'光标到下一行
const CR: u8 = 0x0du8;//Carriage Return 是'\r'一般是回到当前行首,
const DL: u8 = 0x7fu8;//删除建退格“Backspace
const BS: u8 = 0x08u8;//有些c风格这个是删除“Backspace
```