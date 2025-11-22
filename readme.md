# 记录使用python-phinx

## 安装的指令

```bash
conda activate phinx                          
mkdir docs                                        
cd docs/                                          
pip install sphinx                           
pip install pyyaml
pip install typeguard
```

## 添加文档的操作
### 1. 新建页面：
- 在 docs/source/ 里创建 xxx.md（或 xxx.rst），写好内容。
- 在 docs/source/index.rst 的 .. toctree:: 下添加不带扩展名的路径，例如 getting-started。多个页面各占一行。
 
```rst
.. toctree::
   :maxdepth: 2
   :caption: 内容:

   getting-started
   another-page
```

- `如果想要添加资源`把图片等资源放到 docs/source/_static/，在 Markdown 里用相对路径引用；自定义样式写在 docs/source/_static/custom.css（已引入）。

## 本地构建加上debug

```bash
cd docs
sphinx-autobuild  source/ build/html/
sphinx-autobuild  source/ build/html/ --host 192.168.43.160 #这样可以指定ip地址
```

## 关于资源引用的说明(图片,文件)
> 在conf.py里面有`html_static_path = ['_static']`,所有sphinx只会把_static里面的东西复制过去,
> 为了方便,直接把所有资源放在这个文件夹里面,但是寻址还是相对于文件所在目录的,所以要应用资源的话得

- 图片示范
```markdown
目录
- _static
- 测试使用
   - markdown.md

<img src="../_static/img/ubuntu输入法.png" alt="img_miss" style="zoom: 50%;"/>
<!-- 使用相对于文档的地址 -->

```

> 使用sphinx语法不会有文件不搬家的情况,但是我不喜欢学

```markdown
{download}`这个是sphinx的写法 <../_static/files/matplotlibcpp.h>`
```

- 文件示范

```markdown
<a href="../_static/files/matplotlibcpp.h" download>我更喜欢html语法</a>
```

3.8kb