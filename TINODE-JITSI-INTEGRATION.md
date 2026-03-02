# Tinode 与 Jitsi 集成文档（必选依赖）

本文档为 MOP 项目**音视频与屏幕共享**的必选依赖，约定 Tinode 与 Jitsi 的职责划分、房间信令、房间命名、昵称入会及部署与客户端接入方式。**未完成本文档并评审通过前，不得上线音视频/屏幕共享功能。**

与项目规约的对应关系：ARCHITECTURE.md 第 2.4 节、第 8 节；.cursorrules 配置策略·音视频依赖。

---

## 1. 职责划分

| 组件 | 职责 | 说明 |
|------|------|------|
| **Tinode（api）** | 信令与房间管理 | 房间创建/加入/离开的**信令**经 Tinode 通道（WebSocket/消息）；会话、邀请入会、房间成员列表等由 Tinode 或与 api 协同维护。 |
| **Jitsi（jit）** | 媒体传输 | 音视频流、屏幕共享流走 **Jitsi 规范**（WebRTC）；Jitsi 仅负责媒体，不负责业务身份与好友关系。 |

原则：**信令走 Tinode，媒体走 Jitsi**。客户端先通过 Tinode 完成“创建/加入房间”的信令与鉴权，再连接 Jitsi 房间进行音视频/屏幕共享。

---

## 2. 域名与部署

- **Jitsi 自建域名**：`jit.sdkdns.top`（与 ARCHITECTURE 第 7 节一致）。
- **部署方式**：Docker / Docker Compose，与 api、web、admin 同属部署范围；Jitsi 与 api 无强启动依赖，可在 api 就绪后部署或并行部署。
- **证书**：与四域一致，自申请 SSL 证书，兼容 TLS 1.2/1.3；Jitsi 服务需配置有效 HTTPS。

---

## 3. 房间命名规则

- 房间名须**全局唯一**，且与 Tinode 侧会话或群组对应，便于信令与媒体一致。
- **推荐格式**（由实现二选一或兼容）：
  - **方案 A**：`mop_{topic_id}`，其中 `topic_id` 为 Tinode 的 topic（如 grp 或 p2p 会话 id）。
  - **方案 B**：`mop_{room_uuid}`，其中 `room_uuid` 由 api 在创建会话/房间时分配并写入 Tinode 消息或会话 meta。
- 房间名仅允许字母、数字、下划线，长度由 Jitsi 与实现约定（建议 ≤128 字符）。禁止在房间名中携带未脱敏用户信息。

---

## 4. 房间创建与加入信令（经 Tinode）

- **创建房间**：由发起方（或服务端）在 Tinode 侧创建会话或写入“房间”资源，并生成唯一 **room_name**（见第 3 节）；通过 Tinode 消息或预设协议将 `room_name`、可选 `room_options`（如仅音频、允许屏幕共享）下发给参与方。
- **加入房间**：参与者通过 Tinode 收到“邀请入会”或“房间已创建”信令，信令中至少包含：
  - `room_name`：对应 Jitsi 房间名；
  - `jit_domain`：Jitsi 域名（如 `jit.sdkdns.top`），用于客户端拼接 Jitsi Meet URL。
- 客户端收到信令后，**不再向用户弹窗输入姓名**，直接使用当前账户**昵称**作为 Jitsi 显示名入会（见第 5 节）。
- **离开/结束房间**：通过 Tinode 发送离开或结束房间信令；客户端同时离开 Jitsi 房间并释放媒体。

信令具体格式（**消息 type、JSON 键名**）**以 Tinode 为准**，遵循 Tinode 消息与扩展规范；业务语义与 PROTOCOL.md 第 8 节一致，须包含 room_name、jit_domain，可选 display_name、room_options，及创建/加入/离开行为。

---

## 5. 昵称入会（必选）

- 用户进入视频通话/屏幕共享房间时，**必须使用当前账户的昵称**作为房间内显示名直接加入，**不得再次弹窗或输入姓名**。
- **昵称来源**：来自 MOP 账户体系（api 的 User.nickname），与 Tinode 展示名一致；客户端在加入 Jitsi 房间时，将当前用户的 nickname 作为 Jitsi 的 **displayName** 传入。
- 若 Tinode 或 api 在信令中下发 `display_name`，客户端应优先使用该字段（须与当前用户昵称一致）；否则客户端使用本地已缓存的当前用户昵称。

与 .cursorrules、ARCHITECTURE 第 9 节“音视频入会”一致。

---

## 6. 客户端接入 Jitsi

- **Web**：通过 Jitsi Meet iframe 或 Jitsi Meet API 嵌入； meeting URL 形如：  
  `https://jit.sdkdns.top/房间名`  
  通过 URL 参数或 API 传入 **displayName**（当前用户昵称），关闭 Jitsi 默认的“输入姓名”弹窗（若实现支持）。
- **Flutter / 移动端**：通过 **Jitsi Meet SDK** 或 **WebView 内嵌 Meet** 加入同一 meeting URL；入会时传入 **displayName = 当前用户昵称**，不二次询问姓名。
- **屏幕共享**：按 Jitsi 规范在会议中发起屏幕共享；权限与提示由各平台按系统能力处理。

客户端须使用 **HTTPS** 访问 `jit.sdkdns.top`，且不向用户暴露“API/Host”等术语；用户仅感知“进入会议/屏幕共享”。

---

## 7. 安全与隐私

- Jitsi 房间名不包含手机号、UID 等敏感信息；仅使用第 3 节约定的匿名化 room_name。
- 媒体流经 Jitsi 服务器；若需端到端加密，按 Jitsi 与项目安全策略另行约定。
- 入会鉴权：通过 Tinode 信令与 api 的 token 保证“仅授权用户收到入会信令”；Jitsi 侧若支持 token/auth，由实现与 jit 部署配置一致。

---

## 8. 与 MOP 其他文档的交叉引用

| 内容 | 引用 |
|------|------|
| 四域与 jit 用途 | ARCHITECTURE.md 第 7、8 节 |
| 昵称入会、无二次输入 | .cursorrules 音视频入会；ARCHITECTURE 第 9 节 |
| 部署顺序（api 优先，jit 可随后） | ARCHITECTURE 第 8 节 |
| 开发阶段 ⑥ 音视频 Jitsi | ARCHITECTURE 第 10 节 |

---

## 9. 评审与发布

- 实现须满足：**信令经 Tinode、房间命名统一、昵称入会且无二次输入、客户端与 jit 域名/HTTPS 正确**。
- 完成实现后进行**集成评审**，通过后方可发布音视频/屏幕共享能力。
- 信令字段与 api 接口的最终定义，可在 PROTOCOL.md 或 api 文档中增补，本文档保持与之一致。
