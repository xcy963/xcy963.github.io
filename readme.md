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