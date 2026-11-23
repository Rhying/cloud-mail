#!/usr/bin/env bash
# 手动同步上游（替代已删除的 GitHub Actions「自动同步上游」工作流）
#
# 用法：在仓库任意位置执行
#     bash scripts/sync-upstream.sh
#
# 做的事：
#   1. 只 fetch 上游 maillab/cloud-mail（对上游永远只读）
#   2. 用 git merge --squash -X ours 把上游内容并入工作区，冲突一律保留 fork 版本
#   3. 保护 mail-worker/wrangler.toml 的 ${D1_DATABASE_ID} / ${KV_NAMESPACE_ID} 占位，
#      这是「CF 更新部署后 d1/kv 绑定丢失需要重新绑定」的解决方案本体
#   4. 用 git reset --soft upstream/main 把历史重建成「上游 + 1 条提交」
#   5. force-with-lease 推送到自己的 fork
set -euo pipefail

UPSTREAM_URL="https://github.com/maillab/cloud-mail.git"

cd "$(git rev-parse --show-toplevel)"

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$UPSTREAM_URL"
git fetch upstream main --no-tags
git fetch origin main --no-tags

if git merge-base --is-ancestor upstream/main HEAD; then
  echo "已包含上游全部提交（$(git rev-parse --short upstream/main)），无需同步。"
  exit 0
fi

BEFORE=$(git rev-parse HEAD)
echo "发现上游新提交 $(git rev-parse --short upstream/main)，开始同步..."

# 合并内容（不产生 merge commit，冲突保留本地）
git merge --squash -X ours upstream/main</dev/null || true

# 护栏：wrangler.toml 是 fork 的关键定制，上游一改就回滚，避免绑定占位被写死或注释
if git diff --quiet "$BEFORE" -- mail-worker/wrangler.toml; then
  :
else
  echo "上游改动了 wrangler.toml，回滚到 fork 版本（保护 D1/KV 绑定占位）"
  git checkout "$BEFORE" -- mail-worker/wrangler.toml
fi

if ! grep -q 'D1_DATABASE_ID' mail-worker/wrangler.toml \
   || ! grep -q 'KV_NAMESPACE_ID' mail-worker/wrangler.toml; then
  echo "错误：wrangler.toml 丢失 D1/KV 占位，已中止（未推送）" >&2
  exit 1
fi

git add -A

# 重建历史：HEAD 直接挂到 upstream/main，索引保留合并后内容 → 非上游提交始终只有一条
git reset --soft upstream/main
git commit --allow-empty \
  -m "chore(sync): 同步上游 $(git rev-parse --short upstream/main) 并保留 fork 定制" \
  -m "冲突一律保留 fork 版本；wrangler.toml 的 D1/KV 绑定占位受保护。"

git push --force-with-lease origin main
echo "同步完成：$(git log --oneline -1)"
