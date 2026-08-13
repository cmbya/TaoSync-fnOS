# TaoSync-fnOS

TaoSync 的 fnOS x86 原生自动构建仓库模板。

- 上游：`dr34m-cn/taosync`
- 架构：x86 / amd64
- Docker：不使用
- fnOS 封装版本：读取 `PACK_REV`，初始为 `native1`
- 自动检查：每天一次
- 发布方式：GitHub Pre-release

## 自动更新逻辑

每天检查 `dr34m-cn/taosync` 的最新正式 Release。若对应 `fnos-vX.Y.Z-native1` Release 已存在就跳过；不存在则验证上游 Release 中有 `linux-StaticX-amd64.zip`，然后生成 FPK，并自动创建 Pre-release。

## 手动指定版本

Actions 的 `Run workflow` 可以输入 `v0.4.0` 或 `0.4.0`。

## 更新 fnOS 封装版本

如果以后修改了飞牛封装逻辑，只需把 `PACK_REV`：

`native1` → `native2`

然后重新运行 Actions，即可在同一个上游 TaoSync 版本下生成新的 FPK。

