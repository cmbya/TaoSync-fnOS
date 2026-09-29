# TaoSync-fnOS

TaoSync 的 fnOS x86 原生自动构建仓库模板。

- 上游：`dr34m-cn/taosync`
- 架构：x86 / amd64
- Docker：不使用
- 自动检查：每天一次
- 发布方式：GitHub Pre-release

## 自动更新逻辑

每天检查上游最新正式 Release，FPK 的版本与上游版本一致。同一个上游版本不覆盖已发布的 FPK。

## 手动指定版本

Actions 的 `Run workflow` 可以输入 `v0.4.0` 或 `0.4.0`。

## 上游版本与旧包迁移

新 FPK 的 manifest、文件名和 Release tag 直接使用上游版本 `0.4.0`，不再添加封装修订号。同一个上游版本只发布一次，不能静默替换同版本 FPK。

FnDepot 先前索引的版本为 `0.4.0-native1`。已安装的旧包可能因版本号比较或安装来源无法自动升级；切换版本规则需要在设备上单独验证和迁移。
