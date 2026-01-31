# 📐1svd分解

```{note}
前言:实对称矩阵可以被写成$A^{T} * A$的形式,那么一般的矩阵有没有类似的性质呢?
- 如果矩阵不是方阵,也会有类似的性质吗?
```

下面给出**奇异值分解(SVD)**的严格证明. 为了统一表述,先证明一般矩阵的情形,再单独说明方阵的结论.

---

## 一般矩阵

设 $A \in \mathbb{R}^{m\times n}$.

### 定理(奇异值分解)
存在正交矩阵 $U\in\mathbb{R}^{m\times m}$, $V\in\mathbb{R}^{n\times n}$ 以及对角矩阵
$$
\Sigma=\operatorname{diag}(\sigma_1,\dots,\sigma_r,0,\dots,0)\in\mathbb{R}^{m\times n}
$$
使得
$$
A=U\Sigma V^T,
$$
其中 $\sigma_1\ge \sigma_2\ge\cdots\ge\sigma_r>0$ 为 $A$ 的奇异值, $r=\operatorname{rank}(A)$.

### 证明
**步骤 1: 考察 $A^T A$.**
$A^T A$ 是 $n\times n$ 实对称半正定矩阵,因此由谱定理,存在正交矩阵 $V=[v_1,\dots,v_n]$ 与非负特征值 $\lambda_1\ge\cdots\ge\lambda_n\ge 0$ 使得
$$
A^T A = V\operatorname{diag}(\lambda_1,\dots,\lambda_n)V^T.
$$
令
$$
\sigma_i=\sqrt{\lambda_i}\ (i=1,\dots,n).
$$
将 $\sigma_i>0$ 的指标记为 $i=1,\dots,r$, 则 $r=\operatorname{rank}(A)$.

**步骤 2: 构造 $U$ 的前 $r$ 列.**
对 $i=1,\dots,r$ 定义
$$
 u_i = \frac{1}{\sigma_i} A v_i.
$$
则
$$
\|u_i\|^2 = \frac{1}{\sigma_i^2} v_i^T A^T A v_i = \frac{1}{\sigma_i^2}\lambda_i = 1,
$$
且当 $i\ne j$ 时
$$
 u_i^T u_j = \frac{1}{\sigma_i\sigma_j} v_i^T A^T A v_j
 = \frac{1}{\sigma_i\sigma_j} v_i^T (\lambda_j v_j)=0.
$$
因此 $u_1,\dots,u_r$ 是一组正交单位向量.

**步骤 3: 扩充为 $\mathbb{R}^m$ 的正交基.**
取 $u_{r+1},\dots,u_m$ 使得 $U=[u_1,\dots,u_m]$ 为 $m\times m$ 正交矩阵.

**步骤 4: 验证分解.**
定义
$$
\Sigma=\begin{pmatrix}
\operatorname{diag}(\sigma_1,\dots,\sigma_r)&0\\
0&0
\end{pmatrix}\in\mathbb{R}^{m\times n}.
$$
对 $i\le r$ 有 $A v_i = \sigma_i u_i$, 对 $i>r$ 有 $\lambda_i=0$ 从而 $A v_i=0$.
因此
$$
A V = U\Sigma.
$$
右乘 $V^T$ 得到
$$
A = U\Sigma V^T.
$$
证毕.

### 备注
- $A^T A$ 的特征值就是 $A$ 的奇异值平方.
- $\operatorname{rank}(A)=r$ 等于非零奇异值的个数.
- 也可从 $A A^T$ 出发得到等价构造,此时 $U$ 的列向量是 $A A^T$ 的特征向量.

---

## 一般方矩阵

当 $A\in\mathbb{R}^{n\times n}$ 时,上面的构造仍然成立,得到
$$
A=U\Sigma V^T,
$$
其中 $U,V$ 均为 $n\times n$ 正交矩阵, $\Sigma$ 为对角矩阵.

进一步地,若 $A$ 可逆,则所有奇异值 $\sigma_i>0$,从而
$$
A=U\Sigma V^T,\qquad \Sigma=\operatorname{diag}(\sigma_1,\dots,\sigma_n).
$$
这说明任意实方阵都可以写成“正交矩阵 × 对角矩阵 × 正交矩阵”的形式,与实对称矩阵的正交对角化相比,这里允许左右乘不同的正交矩阵.

```{note}
如果你还需要进一步的结论(例如极分解 $A=QH$, 或与 $A^T A$ 的关系 $A^T A = V\Sigma^2 V^T$ 的推导细节),告诉我我可以补充到这一节里.
```
