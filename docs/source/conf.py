# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

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
    
    
]

myst_enable_extensions = ["dollarmath", "amsmath"]

mathjax3_config = {
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

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = "sphinx_rtd_theme"
html_static_path = ['_static']
html_js_files = ['custom.js']

def setup(app):
    app.add_css_file('custom.css')  # Sphinx >= 1.8 推荐写法
