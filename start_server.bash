#!bin/bash
set -e

DOCS_DIR="/home/hitcrt/rust_learning/sphinx_doc/docs"
BUILD_DIR="$DOCS_DIR/build"

cd "$DOCS_DIR"

# 如果带了 -d 参数，就删除 build 后退出
if [ "$1" = "-d" ]; then
    echo "Removing $BUILD_DIR ..."
    rm -rf "$BUILD_DIR"
    echo "Done."
    exit 0
fi

# 如果需要 conda 初始化（按你自己环境调整路径）
source ~/anaconda3/etc/profile.d/conda.sh
# conda init
conda activate phinx
sphinx-autobuild source/ build/html/