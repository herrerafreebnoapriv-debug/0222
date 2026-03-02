# MOP 项目完整性检查

本文档用于检查项目**规约、架构、协议、开发环境与风险文档**的完整性与一致性，便于 onboarding 与迭代时查缺补漏。

---

## 1. 项目结构概览

当前仓库（0222）为 **设计与规约层**，包含文档与开发/测试环境脚本；**实现代码**（Flutter App、api、admin、web、jit 等）不在本仓库，可在其他仓库或同仓库后续目录中实现。

```
0222/
├── .cursorrules                    # 全栈规约（愿景、账户、隐私、审计、指令、二维码、原生桥接、红线）
├── ARCHITECTURE.md                 # 系统架构（四层、模块、实体、流程、部署、域名、UX、阶段、代码结构）
├── PROTOCOL.md                     # 通讯协议（凭证、enroll/auth、邀请、审计、远程指令、build-sync、加密、错误、音视频信令）
├── TINODE-JITSI-INTEGRATION.md     # Tinode/Jitsi 集成（必选依赖：信令、房间命名、昵称入会、部署）
├── DEVELOPMENT-RISKS.md            # 开发风险与已收敛说明、检查清单、方案矛盾排查结论
├── PROJECT-COMPLETENESS.md         # 本文件：完整性检查
├── README.md                       # 项目入口与文档索引
├── app-test-UI/                    # App 与用户端网页 UI 模板（登录、主界面、聊天、设置等，供实现参考）
│   └── README.md                   # 模板说明与本地运行方式
├── admin-test-UI/                  # 管理后台 UI 模板（登录、设备/用户/关系列表、APK、下发指令，供实现参考）
│   └── README.md                   # 模板说明与本地运行方式
└── dev-env/                        # 四域开发/测试环境（Ubuntu 22.04）
    ├── README.md                   # 四域联调说明
    ├── setup-env.sh                # 前置环境检测与安装
    ├── hosts.sample                # hosts 示例
    ├── docker-compose.yml         # 四域网络与占位服务
    └── certs/
        ├── README.md               # 自签名证书说明
        └── gen-certs.sh           # 证书生成脚本
```

---

## 2. 文档覆盖矩阵

| 能力/主题 | .cursorrules | ARCHITECTURE | PROTOCOL | TINODE-JITSI | DEVELOPMENT-RISKS | dev-env |
|-----------|-------------|-------------|----------|--------------|-------------------|---------|
| 愿景与技术栈 | ✓ 第1节 | ✓ 第1–2节 | — | — | — | — |
| 引导与激活、扫码、资料补全 | ✓ 第2节 | ✓ 2.1, 4.1 | ✓ 第1–2节 | — | ✓ 已收敛/清单 | — |
| 用户端网页 / 账密登录 | ✓ 第2节 | ✓ 2.1, 3.2 | ✓ 2.2 | — | ✓ | — |
| 管理后台、数据来源、build-sync、**管理端接口** | ✓ | ✓ 2.1, 3.2, 6 | ✓ 第5节、**5.1 管理端接口** | — | ✓ | — |
| 邀请与好友关系 | ✓ 第2节 | ✓ 2.1, 3.1, 3.2 | ✓ 2.3, 2.4, 2.5 | — | ✓ | — |
| 影子审计、采集、增量、保活 | ✓ 第3节 | ✓ 2.2, 3.2 | ✓ 第3节 | — | ✓ 平台差异 | — |
| 远程指令（dial/sms/wipe 等） | ✓ 第4节 | ✓ 2.3, 4.2 | ✓ 第4节 | — | ✓ | — |
| 二维码与分发、APK 命名 | ✓ 第5节 | ✓ 第6节 | ✓ 第1, 5节 | — | ✓ | — |
| 原生桥接 NATIVE_BRIDGE | ✓ 第6节 | ✓ 2.2 | — | — | ✓ | — |
| 四域、域名、部署、证书 | ✓ 第1节 | ✓ 第7–8节 | ✓ 第5–6节 | ✓ 第2节 | ✓ 四域已落实 dev-env | ✓ 全文 |
| 音视频/Jitsi、信令、昵称入会 | ✓ 第1、2节 | ✓ 2.4, 8, 9 | ✓ 第8节 | ✓ 全文 | ✓ | — |
| 安全与隐私（Wipe、脱敏、加密） | ✓ 第7节 | ✓ 第5节 | ✓ 第6节 | — | ✓ | — |
| 错误码、重试、API 失效判定 | — | ✓ 引用 PROTOCOL | ✓ 第7节 | — | ✓ | — |
| 模块化阶段、代码结构、DoD | ✓ 第7节 | ✓ 第10–11节 | — | — | ✓ 按阶段收敛 | — |
| 用户须知与再次征意、i18n | ✓ 第2节 | ✓ 第9节 | — | — | ✓ | — |

结论：**规约、架构、协议、Tinode/Jitsi 集成、风险与 dev-env 已形成闭环**。**api 管理端接口**已在 PROTOCOL 第 5.1 节约定（设备/用户/关系列表与详情、下发远程指令），见 DEVELOPMENT-RISKS「开发过程仍须关注」表。

---

## 3. 规约–协议–架构 对应关系

- **凭证格式**：.cursorrules 第5节 ↔ PROTOCOL 1.1（mop://Base64，host|uid|token|timestamp）一致。
- **enroll/auth/邀请/审计/指令/build-sync**：ARCHITECTURE 3.2 与 PROTOCOL 第2–5节一一对应；错误码与重试见 PROTOCOL 第7节，已收敛于 DEVELOPMENT-RISKS。
- **refresh**：PROTOCOL 2.2 常规方案（提供 refresh、401 时尝试一次）与 DEVELOPMENT-RISKS 方案矛盾排查结论一致。
- **device_id**：PROTOCOL 第2节常规方案（Android/iOS SHA-256）与清单一致。
- **音视频信令**：PROTOCOL 第8节、TINODE-JITSI-INTEGRATION、ARCHITECTURE 2.4 与 .cursorrules 音视频依赖一致；信令以 Tinode 为准。

---

## 4. 已知缺口与建议（实现前）

| 类别 | 事项 | 说明 |
|------|------|------|
| **已约定** | api 管理端接口 | PROTOCOL 第 5.1 节已约定：devices/users/relations 列表与详情、POST devices/:device_id/command 下发指令；鉴权为管理端 Token/API Key。 |
| **可选** | 统一错误码表 | PROTOCOL 第7节已约定 code/message 与重试；若需全量错误码表与文案，可在实现时于 PROTOCOL 或 api 文档中增补。 |
| **可选** | PROTOCOL 可读性 | 部分接口可补充完整 JSON 示例与字段类型，减少联调歧义（见 DEVELOPMENT-RISKS 第8节）。 |

其余「由实现约定」的阈值与策略（如超时秒数、重试次数、须知版本号来源等）不阻塞启动开发，可在实现阶段在 PROTOCOL 或实现文档中固定。

---

## 5. 按阶段完整性检查清单

开发按 **ARCHITECTURE 第10节** 模块化阶段推进时，可结合以下清单自检：

| 阶段 | 文档与环境 | 实现前检查 |
|------|------------|------------|
| **① 基础链路** | .cursorrules 2、ARCH 2.1/4.1、PROTOCOL 1–2、dev-env 就绪 | hosts/证书/Docker 已配置；enroll、auth/login、凭证格式与 device_id 与 PROTOCOL 一致 |
| **② 邀请与关系** | PROTOCOL 2.3–2.5、ARCH 2.1/3.1 | invite/generate、validate、enroll 带 invite_code、查找用户精确搜索（2.4）、403 与错误码与 PROTOCOL 一致 |
| **③ 管理后台与 web** | ARCH 2.1/3.2、PROTOCOL 5、build-sync | admin 鉴权独立；api 管理端接口路径与鉴权已约定或已补充到 PROTOCOL |
| **④ 影子审计** | .cursorrules 3、ARCH 2.2、PROTOCOL 3 | check-sum/upload、Isolate 加密、按平台过滤 data_types、Foreground Service |
| **⑤ 远程指令** | .cursorrules 4、ARCH 2.3、PROTOCOL 4 | Tinode 指令通道、dial/sms/wipe、原生桥接与指令集一致 |
| **⑥ 音视频 Jitsi** | TINODE-JITSI-INTEGRATION、PROTOCOL 8、ARCH 2.4/8 | 信令经 Tinode、房间命名、昵称入会、jit 域名 HTTPS；集成评审通过后再上线 |

每阶段完成后建议做一次**小范围联调与文档核对**，确保与规约一致；接口/指令/错误码变更时**同步更新 PROTOCOL**（ARCHITECTURE 第11节末）。

---

## 6. 结论

- **文档闭环**：.cursorrules、ARCHITECTURE、PROTOCOL、TINODE-JITSI-INTEGRATION、DEVELOPMENT-RISKS、dev-env 相互引用一致，**方案矛盾排查**已收敛（见 DEVELOPMENT-RISKS 末尾）。
- **环境就绪**：四域开发/测试环境（hosts、Docker 网络、自签名证书、前置检测脚本）已提供，目标环境 Ubuntu 22.04。
- **管理端接口**：已在 PROTOCOL 第 5.1 节约定；其余为可选增强或实现期约定。
- **实现代码**：本仓库为规约与设计层，App/api/admin/web/jit 实现可在本仓库子目录或独立仓库中维护，按 ARCHITECTURE 第10–11节与本文档清单推进即可。
- **可行性**：技术、依赖、平台、合规与上架、资源与节奏的详细检查与前提条件见 **FEASIBILITY.md**。
- **仓库与链接**：项目在远程机（Ubuntu 22.04）上开发，与 GitHub 仓库的链接在远程机项目根目录通过 `git remote add origin` 完成，见 **README.md**「开发环境与仓库」。
