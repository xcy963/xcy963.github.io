# 💻 vscode小技巧

## 使用`alt +shitft`,点两下鼠标
```{note}
注意不要按鼠标中键,在一个地方点一下在按住(不要松开)`alt +shitft`,然后再再第二个地方点一下
```

```{image} ../_static/img/测试使用/vscode演示.gif
:width: 600px
:align: center
:alt: 替代文本
```

## codex更新之后使用vscode的远程插件连接的会有网络问题

```{note}
相当构思,猜测是插件在容器内部加了什么验证的
解决办法是给插件的终端加上代理
```

- 在容器的root目录下面的`.bashrc`里面加上clash的代理
```bash
export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897 all_proxy=socks5://127.0.0.1:7897
#容器里面不好打开可以使用vscode左上角那个文件
```
