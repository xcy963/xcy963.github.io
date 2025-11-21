# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

from sphinx.highlighting import lexers
from pygments.lexers.special import TextLexer

# 让 ```txt 也能被当成纯文本高亮，避免 Pygments 报 unknown lexer
lexers["txt"] = TextLexer()

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information
# import sphinx_rtd_theme
project = 'xcy的妙妙屋'
copyright = '2025, xcy'
author = 'xcy'
release = '1.0'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    'sphinx_rtd_theme',
    'myst_parser',
    'sphinx.ext.mathjax',
    'sphinx_multiversion', 
    
]

myst_enable_extensions = ["dollarmath", "amsmath"]

mathjax3_config = {#latex的支持
    "tex": {
        "macros": {
            "R": r"\mathbb{R}",
            "vect": [r"\mathbf{#1}", 1],
        }
    }
}


source_suffix = {
    '.rst': 'restructuredtext',
    '.md': 'markdown',
}

templates_path = ['_templates']
exclude_patterns = []

language = 'zh_CN'

# # ------- 多版本相关配置 -------

# # 把多版本侧边栏模板挂到所有页面的侧边栏
# html_sidebars = {
#     '**': [
#         'globaltoc.html',    # 全局目录（可按你喜好删改）
#         'versions.html',     # ★ 我们马上要创建的模板
#         'relations.html',
#         'searchbox.html',
#     ],
# }

# # 只包括哪些分支 / 标签，可以按你自己的 Git 习惯改
# # 例如只构建 main 分支和 vX.Y 这样的 tag：
# smv_branch_whitelist = r'^(main|master)$'
# smv_tag_whitelist = r'^v\d+\.\d+$'
# smv_remote_whitelist = r'^origin$'
# smv_latest_version = 'main'   # 或 'master'，看你仓库默认分支



# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = "sphinx_rtd_theme"
html_static_path = ['_static']
html_js_files = [
    'css/custom.js',
    'css/live2d-init.js',  # Live2D 初始化脚本（动态加载 CDN 依赖）
]

def setup(app):
    app.add_css_file('css/custom.css')  # Sphinx >= 1.8 推荐写法
