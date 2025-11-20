# git小土豆



## 0. 初次使用：设置身份

```bash
# 设置用户名（显示在提交记录里）
git config --global user.name "你的名字"

# 设置邮箱（也显示在提交记录里）
git config --global user.email "你的邮箱"

# 查看当前配置
git config --list
```

---

## 1. 创建 / 获取仓库

### 1.1 在本地新建一个仓库

```bash
mkdir my-project
cd my-project
git init
```

* `git init`：在当前目录创建一个新的 Git 仓库（会生成 `.git` 目录）

### 1.2 从远程克隆一个已有仓库

```bash
git clone https://github.com/user/repo.git
# 或者
git clone git@github.com:user/repo.git
```

---

## 2. 查看当前状态

```bash
git status
```

* 查看哪些文件被修改了、哪些已经暂存、当前在哪个分支。

---

## 3. 把文件纳入版本控制

### 3.1 把新文件 / 修改过的文件加入暂存区（stage）

```bash
# 添加单个文件
git add main.cpp

# 添加当前目录所有改动
git add .

# 添加某个目录
git add src/
```

### 3.2 提交（commit）

```bash
git commit -m "写一点有意义的提交说明"
```

---

## 4. 查看历史 / 对比修改

### 4.1 查看提交历史

```bash
git log
```

常用简略版：

```bash
git log --oneline --graph --all
```

### 4.2 查看当前改动

```bash
# 工作区 vs 暂存区
git diff

# 暂存区 vs 上一次提交
git diff --cached

# 某个文件的改动
git diff path/to/file
```

---

## 5. 撤销修改（温柔版）

> 下面都是“简单可控”的撤销方式，危险的那种我先不掰开说。

### 5.1 撤销工作区里对某个文件的修改（回到最近一次提交的版本）

```bash
git restore path/to/file
```

### 5.2 把已经 git add 的文件从暂存区撤回来

```bash
git restore --staged path/to/file
```

---

## 6. 分支操作（branch）

### 6.1 查看分支

```bash
git branch        # 列出本地分支
git branch -a     # 列出本地 + 远程分支
```

### 6.2 新建分支

```bash
git branch dev          # 创建 dev 分支，但不切换过去
```

### 6.3 切换分支（推荐用 git switch）

```bash
git switch dev          # 切到 dev 分支
git switch -c dev       # 创建并切到 dev 分支（等价于 git branch dev + git switch dev）
```

> 老命令 `git checkout` 也能切分支，但现在推荐 `git switch`：

```bash
git checkout dev        # 老写法
```

### 6.4 重命名分支

```bash
git branch -M main   # 强制把当前分支改名为 main（你问的那条）
# 或者温和一点：
git branch -m main
```

---

## 7. 合并分支（merge）

场景：
你在 `dev` 分支开发完成，想把它合并回 `main`。

```bash
git switch main       # 先切回 main
git merge dev         # 把 dev 合并到 main
```

如果有冲突，Git 会提示你手动改文件，然后：

```bash
git add 改过的文件
git commit            # 完成这次 merge 提交
```

---

## 8. 暂存工作（stash）

你正在改东西，突然要临时切到别的分支，但又不想提交半成品：

```bash
git stash              # 把当前修改保存起来，工作区还原干净
git stash list         # 查看保存了哪些 stash
git stash pop          # 取出最近一次 stash 并应用，然后删除这个 stash
```

---

## 9. 远程仓库（remote）与推送 / 拉取

### 9.1 添加远程仓库

```bash
git remote add origin https://github.com/user/repo.git
# 或 SSH
git remote add origin git@github.com:user/repo.git

git remote -v      # 查看当前远程仓库
```

### 9.2 推送到远程

第一次推送：

```bash
git push -u origin main   # 把 main 推到远程 origin，并把 upstream 设好
```

以后就可以简写：

```bash
git push
```

### 9.3 从远程拉取更新

```bash
git pull           # 等价于：git fetch + git merge
```

或者分开一步步来：

```bash
git fetch          # 只把远程的更新拉到本地
git merge origin/main   # 合并远程 main 到当前分支
```

---

## 10. 标签（tag）—— 给某个版本打标记

### 10.1 创建标签

```bash
git tag v1.0.0          # 在当前提交打一个轻量标签
```

### 10.2 推送标签到远程

```bash
git push origin v1.0.0
# 推送所有标签
git push origin --tags
```

---

## 11. .gitignore —— 忽略不需要提交的文件

在仓库根目录创建 `.gitignore` 文件，例如：

```bash
# 编译产物
build/
*.o
*.out

# 临时文件
*.log
*.tmp

# VSCode 配置
.vscode/
```

Git 会自动忽略这些匹配的文件/目录。

---

## 12. 万能求助：help

随时不会写命令，可以：

```bash
git help <子命令>
git help commit
git help branch
```

或简写：

```bash
git commit -h
git branch -h
```

---

如果你愿意，我可以按你的实际使用场景（比如：常用 GitHub、还是只在本地玩；有没有多人协作）帮你再精简出一份**“每天只用到的 10 条命令版”**，给你做成一页纸小抄。
