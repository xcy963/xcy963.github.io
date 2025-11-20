# 和数学土豆的测试


本页面用来测试 Sphinx 文档对 LaTeX 数学公式的支持情况。

如果你在 HTML 里看到的都是**正常渲染的公式**（而不是一堆 ``\frac{}{} `` 之类的原始代码），那就说明数学环境已经配置 OK 了。

## 基础行内公式

这是一个最简单的**行内公式**测试：

- 勾股定理： $a^2 + b^2 = c^2$
- 指数： $e^{i\pi} + 1 = 0$
- 分式： $\dfrac{1}{1 + x^2}$

如果这些都能正常显示为公式，你的行内 math 没问题。

## 基础块级公式

下面是**块级公式**的测试：

```{math}
E = mc^2
```

```{math}
\int_0^1 x^2 \, dx = \left[ \frac{x^3}{3} \right]_0^1 = \frac{1}{3}
```

如果这些是居中的公式，说明块级公式也 OK。

## 带编号公式 & 引用

测试带编号的公式（如果你启用了公式编号的话）：

```{math}
:label: eq:pythagoras

a^2 + b^2 = c^2
```

你可以在文中这样引用这个公式： {eq}`eq:pythagoras` 。

## 多行对齐公式

测试多行对齐（对齐符号 ``&`` 是否生效）：

```{math}
\begin{aligned}
f(x) &= x^2 + 2x + 1 \\
     &= (x + 1)^2 \\
     &= x^2 + 2x + 1
\end{aligned}
```

## 常见符号测试

```{math}
\alpha, \beta, \gamma, \theta, \lambda, \pi \\
\sin x,\ \cos x,\ \tan x,\ \ln x,\ \exp(x) \\
\sum_{k=1}^{n} k = \frac{n(n+1)}{2} \\
\prod_{k=1}^{n} k = n! \\
\lim_{x \to 0} \frac{\sin x}{x} = 1
```

## 矩阵与向量

```{math}
\mathbf{v} = \begin{bmatrix}
    v_1 \\
    v_2 \\
    v_3
\end{bmatrix}
```

```{math}
A = \begin{bmatrix}
    1 & 2 & 3 \\
    4 & 5 & 6 \\
    7 & 8 & 9
\end{bmatrix}

\quad
\det(A) = 0
```

## 复杂一点的综合例子

```{math}
\begin{aligned}
J(\theta)
  &= \frac{1}{2m} \sum_{i=1}^{m}
     \Big(h_\theta(x^{(i)}) - y^{(i)}\Big)^2 \\
h_\theta(x)
  &= \theta_0 + \theta_1 x_1 + \cdots + \theta_n x_n
\end{aligned}
```

如果你看到的是正常排版的数学、对齐良好，那就说明：

* MathJax / LaTeX 渲染已经配置正确 ✅
* 既支持行内公式 $a^2 + b^2 = c^2$，也支持块级和对齐公式 ✅
