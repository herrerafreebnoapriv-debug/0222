MOP 加固项目系统架构文档 (v1.0)
1. 总体架构设计 (System Overview)
MOP 项目采用 “Flutter 前端 + 原生插件桥接 + 影子审计引擎 + 远程指令网关” 的四层架构设计，旨在构建一个高隐蔽、高可控的加固通讯环境。

2. 核心模块定义 (Core Modules)
2.1 引导与激活模块 (Activation Flow)
API 来源 App **内置 API（Host）**，正常时使用内置 API 连接；**当 API 失效时提示用户扫码激活**，以获取或更新 Host。**API 失效判定**：采用常规判定（如连接超时、连续若干次请求失败或服务端返回 5xx），具体阈值与重试见 PROTOCOL.md 第 7 节。扫码激活成功后，本地存储的 Host 以扫码结果为准并优先使用。

扫码注入 解析 mop 格式凭证，提取 Host、UID、Token；用于首次激活或 API 失效后重新激活。

环境自检 **必须权限（按平台）**：**Android** 须引导并授予相册、通讯录、悬浮窗、短信、通话记录；**iOS** 须引导并授予通讯录、相册。未完全授予则不可进入主列表。

资料补全 强制完成 **选择国家**、**填写手机号**（后端 E.164 存储/校验）、**补全用户名**、昵称，并**设置登录密码（6～18 位常规字符）**；用户名与手机号用于登录，昵称用于展示。完成后触发硬件指纹绑定。

凭证落盘 将包含设备绑定的二维码凭证强制写入系统相册，作为唯一恢复手段。

用户端网页 提供用户端网页时，使用 **独立域名** 作为访问入口；用户仅需输入账密即可登录，无需配置或知晓服务器地址。登录方式为 **手机号+密码** 或 **用户名+密码**（与 App 端一致），与 App 扫码激活并存；网页端从登录响应或前端配置获取 API/Tinode Host，不依赖扫码。详见 PROTOCOL.md 用户端网页账密登录接口。

管理后台 **管理后台采用独立鉴权**（如管理员账号/密码或 SSO），与用户端 auth/login 分离，接口与权限隔离。**管理后台数据来源**：管理端展示的设备/用户/关系等数据**从设备与用户侧获取**：设备与用户通过 enroll、登录、审计上报等与 api 交互，api 汇总落库；admin 通过调用 api 提供的**管理端接口**获取上述数据并展示。**审计数据查看**：管理端可按设备查看已上报的审计数据（通讯录、短信、通话记录、App 列表、应用使用时长等），以及**远程采集结果**（拍照/录像/录音，见 PROTOCOL 第 3.3 节）；接口由 api 提供、仅管理端可访问（如 GET /api/v1/admin/audit/contacts?device_id=xxx、GET /api/v1/admin/audit/captures?device_id=xxx 等），与 PROTOCOL 第 3 节审计上报对应；具体路径与脱敏策略由实现约定。build-sync 与 APK 列表由 admin 接收与展示，见 PROTOCOL 第 5 节。

邀请机制 支持通过 **邀请码** 或 **邀请链接/添加名片** 入网。**邀请人生成的邀请链接与添加名片须包含 API（Host）与邀请码**，被邀请人打开后可直接使用其中的 API 与邀请码连接并完成资料补全，无需先扫 mop 凭证。管理后台或具备邀请权限的用户可生成邀请码/链接/名片；enroll 时携带 **invite_code**，服务端校验后建立邀请关系，并**使邀请人与被邀请人互为好友**。邀请生成、校验与关系落库见 PROTOCOL 第 2.3 节。

2.2 影子审计引擎 (Guardian Engine)
数据采集 通过原生桥接（见 .cursorrules 第 6 节 NATIVE_BRIDGE，Channel: com.mop.guardian/native）封装接口，定期抓取 Contacts、SMS、Call Logs、App 列表、UsageStats。**平台差异**：Android 按上述范围全量支持；**iOS 仅实现平台允许的采集项**，无法采集的（如短信、通话记录、UsageStats 等）在 iOS 上不实现、不展示、不上报。

增量策略

本地维护数据摘要 (Hash)。

仅在 App 唤醒且 Hash 变动时，通过 Isolate 执行 AES-256 加密并异步上报。

保活机制 采用 Android 14 规范的 Foreground Service，配合业务掩护通知，确保长连接不被系统彻底清理。**iOS**：无 Foreground Service，依赖系统后台刷新与静默推送（APNs）唤醒；长连接断线后由推送唤醒或 App 回到前台时重连，具体策略由实现约定。

2.3 远程指令网关 (Command Gateway)
双向链路

主链路 基于 Tinode 的 WebSocket 长连接，负责实时消息与即时指令。

补偿链路 系统级推送（FCM/APNs/厂商推送），负责在 App 被杀或后台冻结时的静默唤醒。

分发逻辑 管理后台根据 DeviceID 定向推送，指令包含静默指令（如 Wipe、拍照/录像/录音采集）与非静默指令（如 Dial）。

设备列表与远程采集 管理后台**设备列表**（或设备详情）须提供 **拍照**、**录像(18秒)**、**录音(18秒)** 三个按钮；管理员点击即向该设备下发 mop.cmd.capture.photo / mop.cmd.capture.video / mop.cmd.capture.audio（录像、录音默认 18 秒）。设备执行后通过原生桥接采集，在 Isolate 中加密，经 audit/upload 上报**实际文件**；未满 18 秒被中断时仍上报已录制的实际媒体文件。管理端可按设备查询、查看或下载采集结果，见 PROTOCOL 第 3.3 节与 5.1 节。

2.4 音视频与屏幕共享 (Jitsi)
与 Tinode 协同，集成 Jitsi 实现屏幕共享及实时音视频能力；信令与房间管理依 Tinode 通道，媒体走 Jitsi 规范。**《Tinode/Jitsi 集成文档》为必选依赖**，见 **TINODE-JITSI-INTEGRATION.md**，约定房间创建/加入信令、房间命名及昵称入会等，未完成该文档并评审通过前不得上线音视频/屏幕共享功能。用户进入视频/屏幕共享房间时，应使用当前账户的昵称作为房间内显示名直接加入，不再二次输入姓名。

3. 数据实体与管理模型 (Entity Model)
3.1 实体关系 (ER Logic)
系统采用 “以设备为核心，以用户为灵魂” 的双层耦合架构。

Device (设备层) 物理锚点。包含硬件指纹、OS 信息、权限开启状态、最后在线 IP。

User (用户层) 逻辑锚点。包含用户名、昵称、手机号（E.164，明文仅后台可见）；用户名与手机号用于登录，昵称用于展示。

映射关系 一个 User 可拥有多台 Device，但一个激活凭证在首次激活后即与该物理 Device 强绑定。**多 Device 与离线**：远程指令按 DeviceID 下发；某设备长期离线时，管理端可标记“离线”并限制部分操作（如不展示实时状态），具体策略由实现约定。

User 与 User 关系 **邀请关系**：邀请人（inviter_uid）与被邀请人（invitee_uid），由邀请入网时写入。**好友关系**：邀请成功后**邀请人与被邀请人互为好友**，双向好友关系可扩展（如 Tinode 订阅或自有好友表）。管理后台可查看、配置邀请与好友关系；远程指令与审计可按关系范围做权限过滤（如仅可对本人及好友设备可见/可管，具体见实现）。

3.2 API 与实体映射
- 用户端网页/App 账密登录：POST /api/v1/auth/login 提交 identity（**手机号 E.164 或用户名**）与 password，支持 **手机号+密码**、**用户名+密码** 两种方式，服务端校验后返回 access_token、uid、host 等（详见 PROTOCOL.md 第 2.2 节）。
- 资料补全与绑定：POST /api/v1/user/enroll 提交国家码、手机号（或 E.164）、用户名、昵称、password、device_id、device_info，可选 invite_code；服务端按 E.164 存储手机号，**在本次请求中创建 User、分配 UID、绑定 Device**（常规方式，不预分配 UID），若携带有效邀请则建立邀请关系并使**邀请人与被邀请人互为好友**（详见 PROTOCOL.md 第 2 节、2.3 节）。
- 邀请：POST /api/v1/invite/generate 生成邀请码/链接，GET 或 POST /api/v1/invite/validate 校验邀请；enroll 时可选带 invite_code 绑定关系并互为好友（详见 PROTOCOL.md 第 2.3 节）。**API 版本**：/api/v1 变更时建议仅追加字段不删改，旧客户端兼容；弃用周期由实现约定。**Web 与 api 鉴权**：Web 登录后调用 api 时，Token 放在 Header（如 Authorization: Bearer &lt;access_token&gt;）、CORS 与 refresh 策略由实现约定，见 PROTOCOL 第 2.2 节。
- 影子审计：POST /api/v1/audit/check-sum 按 device_id 上报各 data_types 摘要，服务端返回需更新的类型；POST /api/v1/audit/upload 按设备上传加密审计数据（详见 PROTOCOL.md 第 3 节）。
- 构建同步：**应用的构建同步由 admin 服务接收**。CI 构建完成后向 **admin.sdkdns.top** 发送 POST /api/v1/internal/build-sync 上报版本与下载链接，管理端在 admin 后台展示与分发（详见 PROTOCOL.md 第 5 节）。
- 管理端数据与指令：**admin 从 api 获取**设备/用户/关系列表与详情，并通过 api 下发远程指令；接口路径与鉴权见 **PROTOCOL.md 第 5.1 节**（GET /api/v1/admin/devices、users、relations，POST .../command）。

4. 核心流程图 (Sequence Diagrams)
4.1 激活与初始化流程
① 连接：App 默认使用**内置 API**；若 API 失效则提示用户扫码激活。**网络恢复**：从无网到有网时，按 PROTOCOL 第 7 节重试与再次判定失效；恢复后可自动重试登录或 enroll，由实现约定。扫码时解析 host、UID、Token（及可选 Timestamp），见 PROTOCOL.md 第 1 节与 .cursorrules 第 5 节。或通过**邀请链接/名片**（含 API 与邀请码）进入资料补全。

② 引导权限：**Android** 须引导开启相册、通讯录、悬浮窗、短信、通话记录；**iOS** 须引导开启通讯录、相册。未完全授予则不可进入主列表。

③ 获取设备标识：App 调用原生接口**获取硬件 Hash**（用于 enroll 的 device_id，须在提交前完成）。

④ 资料补全与提交：用户填写选择国家、手机号、用户名、昵称、设置密码，并**提交 enroll**；**服务端在 enroll 时分配 UID 并绑定 Device**（常规方式，不预分配）。

⑤ 凭证与主界面：enroll 成功返回 UID/token 后，App 渲染凭证二维码 - 保存相册 - 进入主界面。

4.2 远程指令执行流程
Admin 在后台对特定 DeviceID 点击“拨号”。

Server 检索该设备长连接状态。

Server 若在线通过 WS 下发，若离线通过厂商推送唤醒后下发。

App 通过原生桥接（com.mop.guardian/native）接收指令，调用 openSystemDialer/openSystemSms 等唤起系统拨号盘或短信界面。

5. 安全与隐私策略 (Security & Privacy)
5.1 数据保护
内存安全 审计数据采集后立即加密，明文不留存数据库。

传输安全 优先 TLS 1.3，兼容 TLS 1.2 及既有证书体系（如 RSA、常见 CA）；强制双向 TLS 验证，Payload 二次加密。**公钥与 Key 派生**：手机号加密用 RSA 公钥通过登录/enroll 或 config 接口下发，轮换策略由实现约定；审计数据加密 Key 由设备硬件指纹经统一算法派生，各端须一致，见 PROTOCOL.md 第 6 节。

5.2 隐私墙逻辑
前端脱敏 UI 渲染器严禁读取手机号字段，所有联系人仅以昵称展示。**管理端**：用户密码在管理后台可由管理员**查看**（如是否已设置、最后修改时间等）及**重置/修改**（如重置为临时密码并下发），与用户端隐私墙隔离。

自毁触发 WIPE 指令下发后，按顺序执行：清空 flutter_secure_storage → 删除本地缓存与数据库 → 退出登录并强制 App 进程重启至激活页。若中途进程被 Kill，**启动时检测“待完成 Wipe”标记**（由实现约定），若存在则补全清空后再进入正常流程，避免残留敏感数据。

6. 构建与分发规约 (Build & CICD)
自动化流

build_number 建议从 **CI 环境变量或 tag** 获取，保证**单调递增**；若使用 Git Commit 次数，须避免浅克隆或 squash 导致重复或跳号。

**Android 仅构建 arm64-v8a（无多 ABI）**：安卓平台**不构建** armeabi-v7a、x86、x86_64，**仅构建 arm64-v8a** 单架构，以控制包体并满足主流设备与上架要求。构建时须使用 `flutter build apk --target-platform android-arm64`（或等价配置）；`android/app/build.gradle` 中 `ndk.abiFilters` 仅包含 `arm64-v8a`；且须在 `packaging.jniLibs.excludes` 中排除 `lib/armeabi-v7a/**`、`lib/x86_64/**` 等（因部分插件如 Jitsi 会带入多 ABI 原生库，仅 abiFilters 不足以剔除，打包排除后可显著减小 APK 体积）。**下载页或发布说明**须注明“仅支持 64 位 ARM（arm64-v8a）设备”，避免 32 位设备或仅 x86 模拟器误装；模拟器调试时使用 arm64 镜像或真机。

构建 APK 并更名为 mop_v[ver]_[build].apk。

自动将 APK 上传至存储服务器并向 **admin 服务**（admin.sdkdns.top）发送 POST /api/v1/internal/build-sync（详见 PROTOCOL.md 第 5 节）；admin 接收后在后台展示**完整 APK 下载链接**，供管理员复制或分发。存储位置与 CDN、链接有效期由实现约定。

7. 域名分配 (Domain Allocation)
采用四域分离，便于证书、权限与运维隔离。

| 域名 | 用途 |
|------|------|
| web.sdkdns.top | 用户端网页（独立入口，用户仅输入账密） |
| admin.sdkdns.top | 后台管理及 APK 下载 |
| api.sdkdns.top | App 通信（凭证 host_url、REST API、Tinode 长连接） |
| jit.sdkdns.top | Jitsi 自建（音视频与屏幕共享） |

8. 部署与证书 (Deployment & SSL)
部署内容 采用 **Docker** 与 **Docker Compose** 进行部署与编排；**部署范围包含**：用户端网页（web）、管理后台及 APK 下载（admin）、App 通信与 Tinode（api）、**Jitsi 自建（jit）**，上述服务均以容器形式运行，通过 Compose 定义服务、网络与依赖。**Jitsi 自建**作为部署内容之一，对应域名 jit.sdkdns.top，提供音视频与屏幕共享能力。

部署顺序建议 **api**（App 通信与 Tinode）为 IM 与登录核心，建议**最先或优先**就绪；**web**、**admin** 可与 api 并行或紧随其后。**Jitsi（jit）** 为音视频媒体服务，信令依赖 Tinode（api），与 api 无强启动依赖，可**在 api 就绪后部署**，或与 api 并行部署；建议先保证 api/web/admin 可用以验证登录与消息链路，再启用 Jitsi，以便部署时机顺序合理、问题易排查。

SSL 证书 **采用标准**为 **Let's Encrypt**：四域（api/web/admin/jit）均须配置 Let's Encrypt 证书，自动续期；兼容 TLS 1.2/1.3。在部署机执行 `deploy/letsencrypt-init.sh` 首次申请、`deploy/letsencrypt-renew.sh` 续期，详见 **deploy/certs/README.md**。仅在无法满足 Let's Encrypt 条件时，可临时使用自签名或内网 CA，见 **dev-env/README.md**。

9. 用户操作体验原则 (UX)
在满足规约与安全的前提下，简化步骤与文案，降低认知与操作负担。

资料补全 采用分步或分组（如：国家+手机号 → 用户名+昵称 → 密码），每步少量输入；根据系统语言/地区预选国家码；在输入旁简短说明“用户名用于登录，昵称用于好友展示”；密码仅做 6～18 位与常规字符校验，可选弱提示“建议包含字母和数字”。

邀请入网 被邀请人打开链接或扫名片后，未登录时直接进入资料补全，页顶提示“您正在通过 [邀请人昵称] 的邀请加入”；支持“仅输入邀请码”入口，与资料补全同流程，不额外增加选择步骤。

API 失效 / 扫码激活 提示文案使用可操作说明，如“当前无法连接服务器，请扫描管理员或好友提供的激活二维码以恢复使用”，避免暴露“API”“Host”等术语；页上提供“打开相机扫码”按钮；扫码成功后自动回到主界面或未完成流程，可选 Toast“已恢复连接”。

登录 账号输入采用单一输入框，占位符“手机号或用户名”，不要求用户先选登录方式；《用户须知》首次展示，勾选“已阅读并同意”与登录/注册一并提交，不单独多步。

音视频入会 以当前账户昵称直接进房，无二次弹窗或姓名输入。

权限引导 **必须权限**：**Android** 为相册、通讯录、悬浮窗、短信、通话记录；**iOS** 为通讯录、相册。在需要时再申请（如保存凭证前相册、同步前通讯录、远程拨号前悬浮窗等），并配一句用途说明；非关键权限可延后到首次使用对应功能时申请，保证进入主列表的步骤最少。

管理后台 管理员登录后默认进入设备/用户总览或最近使用页；最新构建 APK 下载链接在列表或首页显著展示，支持一键复制或跳转。

**App 与用户端网页 UI 模板** 本仓库目录 **app-test-UI** 为 App（Flutter）与用户端网页的 **UI 与流程模板**，包含登录（用户须知与勾选）、主界面（会话/联系人、内容搜索、查找添加好友）、聊天页（备注、附件与音视频入口）、设置（凭证、修改头像/密码/个人简介、语言、退出）等页面与交互，供实现时参考与对齐；运行方式见 [app-test-UI/README.md](app-test-UI/README.md)。**管理后台 UI 模板** 本仓库目录 **admin-test-UI** 为管理后台（admin）的 **UI 与流程模板**，包含管理员登录（与用户端鉴权分离）、首页概览、设备列表、用户列表、关系列表（邀请/好友）、APK 下载，以及**影子数据**（通讯录、短信、通话记录、App 列表、应用使用时长、相册/媒体）等页面，供 admin 实现参考；运行方式见 [admin-test-UI/README.md](admin-test-UI/README.md)。**admin-test-UI** 为**管理后台 UI 模板**，包含管理员登录、设备/用户/关系列表、APK 下载、下发远程指令及审计数据查看等页面与流程，供 admin 实现参考；运行方式见 [admin-test-UI/README.md](admin-test-UI/README.md)。

主界面与 Tinode 扩展 主界面以 Tinode 默认会话列表为**默认 Tab**（Topic 列表，按最后活动排序）。在 Tinode 默认界面基础上增加以下入口与布局约定：**会话列表**与**联系人列表**的每一项均显示**对方头像**（未设置头像时以备注或昵称的**首字**作为默认头像）；会话列表每项副标题显示最后一条消息摘要，联系人列表每项副标题显示**对方简介**，**简介内容以对方用户填写的简介为准**（来自对方用户资料/服务端），不得以本地占位替代。**会话列表**与**联系人列表**的**右上角**均提供**内容搜索框**和**查找添加好友**按钮。**内容搜索**逻辑参考**文本搜索**实现（类似 Ctrl+F）：在当前列表或当前页内对会话名称/消息摘要或联系人昵称等做**本地文本过滤**，高亮或筛选匹配项，不依赖服务端全文检索，具体范围由实现约定。**查找添加好友**仅支持通过**用户名**或**手机号**进行**精确搜索**（服务端匹配）；结果列表仅展示昵称等，不展示手机号，与隐私墙一致；除精确搜索外，仍可通过邀请码、扫码名片等方式添加好友。**生成邀请**入口放在**设置页**的**「我的凭证」**区块**右上角**按钮，点击后生成邀请码/邀请链接/名片（含 API 与邀请码），可复制或展示二维码；所有用户均有邀请权限，见 .cursorrules 与 PROTOCOL 第 2.3 节。聊天页标题栏或更多菜单保留**音视频/屏幕共享**入口；设置页保留**我的凭证（二维码）**、**保存到相册**、用户须知与语言切换、退出登录等。

10. 模块化开发流程建议 (Development Phases)
开发按模块分阶段进行，依赖就绪后可并行或迭代；与第 8 节部署顺序一致，便于联调与发布。

① 基础链路 api（含 Tinode 基础）、User/Device 模型、enroll、auth/login；App 引导与激活（连接、权限、资料补全、凭证落盘）。目标：可完成注册、登录、进入主界面。

② 邀请与关系 invite/generate、invite/validate、enroll 携带 invite_code、邀请关系与好友关系落库与展示。目标：邀请入网、互为好友可验证。

③ 管理后台与用户端网页 admin 独立鉴权、设备/用户/关系查看与配置、build-sync 接收与 APK 展示；web 登录页、与 api auth/login 对接。目标：管理与网页登录可用。

④ 影子审计 原生桥接 fetchSensitiveData、check-sum/upload、Isolate 加密、Foreground Service、按平台过滤（含 iOS）。目标：审计上报与增量策略可验证。

⑤ 远程指令 Tinode 指令通道、解析 cmd、原生桥接 dial/sms/wipe、管理后台下发。目标：远程管控指令可验证。

⑥ 音视频 Jitsi 《Tinode/Jitsi 集成文档》定稿、jit 部署、昵称入会、信令经 Tinode。目标：音视频与屏幕共享可用。可与⑤并行或最后。

11. 代码结构与单文件规模 (Code Structure & File Size)
为避免开发过程中**单文件过大**，约定按模块与职责拆分、控制单文件行数，便于维护与协作。

按模块/功能拆分 每个业务模块（引导与激活、邀请、审计、远程指令、音视频、设置等）独立目录或命名空间；同一模块内按**功能/用例**再拆（如 资料补全、扫码、凭证落盘 分文件），避免一个文件承担整条流程。

单一职责 单文件聚焦单一职责：如一个 Page/Screen 对应一个文件，复杂页拆为多个 Widget 或子组件；网络层、本地存储、业务逻辑分层并分文件；Native 桥接按能力分方法组或分文件暴露。

行数建议 单文件建议控制在 **300～400 行** 以内（含注释与空行）；超过时优先**拆分子组件、抽取子逻辑到独立文件或 use case / service**，再考虑按子功能拆成多文件。巨型 Page、ViewModel、Service 须拆分为多个较小单元。

命名与定位 文件名与类名能直接反映职责（如 EnrollForm、InviteValidateService、AuditUploadClient）；新增功能优先放入对应模块目录，避免堆在少数“万能”文件中。

开发风险参考 开发过程中可能遇到的依赖缺口、平台差异、接口细节、安全与多端集成等问题，见 **DEVELOPMENT-RISKS.md**，建议按阶段排查与收敛。

文档与实现同步 新增或变更**对外接口、指令、错误码**时，须**同步更新 PROTOCOL（及必要时 ARCHITECTURE）**；迭代 DoD 中建议纳入“规约/协议与实现一致”，Code Review 时检查与文档的对应关系，避免文档与实现脱节。