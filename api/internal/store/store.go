package store

import "context"

// Store 数据访问接口（User、Device、Invite、Friend、Command 等）
type Store interface {
	Close() error
	// User
	CreateUser(ctx context.Context, phoneE164, username, nickname, passwordHash string) (uid string, err error)
	GetUserByUID(ctx context.Context, uid string) (*User, error)
	GetUserByUsername(ctx context.Context, username string) (*User, error)
	GetUserByPhone(ctx context.Context, phoneE164 string) (*User, error)
	UpdateUserProfile(ctx context.Context, uid string, nickname, bio string) error
	UpdateUserPassword(ctx context.Context, uid string, passwordHash string) error
	SetUserAvatarPath(ctx context.Context, uid string, path string) error

	// Device
	BindDevice(ctx context.Context, deviceID, uid string, deviceInfo map[string]string) error
	GetDeviceByID(ctx context.Context, deviceID string) (*Device, error)
	GetDevicesByUID(ctx context.Context, uid string) ([]Device, error)
	UpdateDeviceInfo(ctx context.Context, deviceID string, info map[string]string) error
	UpdateDeviceLocationCity(ctx context.Context, deviceID, city string) error
	DeleteDevice(ctx context.Context, deviceID string) error

	// Token（简单内存或表：access_token -> uid）
	SaveToken(ctx context.Context, token, uid string) error
	GetUIDByToken(ctx context.Context, token string) (string, error)
	DeleteToken(ctx context.Context, token string) error
	// RefreshToken 规约 2.2：用于 POST /api/v1/auth/refresh
	SaveRefreshToken(ctx context.Context, refreshToken, uid string) error
	GetUIDByRefreshToken(ctx context.Context, refreshToken string) (string, error)
	DeleteRefreshToken(ctx context.Context, refreshToken string) error

	// Invite
	CreateInvite(ctx context.Context, inviterUID string, code string, expireSeconds, maxUse int) error
	GetInviteByCode(ctx context.Context, code string) (*Invite, error)
	UseInvite(ctx context.Context, code string) error
	SaveInviteRelation(ctx context.Context, inviterUID, inviteeUID string) error

	// Friend（双向好友表）
	AddFriend(ctx context.Context, uidA, uidB string) error
	GetFriends(ctx context.Context, uid string) ([]Friend, error)
	IsFriend(ctx context.Context, uidA, uidB string) (bool, error)
	CreateFriendRequest(ctx context.Context, fromUID, toUID string) error
	HasPendingRequest(ctx context.Context, fromUID, toUID string) (bool, error)

	// Command（待执行指令，按 device_id 查询；拉取后消费，避免重复执行）
	SaveCommand(ctx context.Context, deviceID string, cmd map[string]interface{}) error
	GetPendingCommands(ctx context.Context, deviceID string) ([]Command, error)
	// GetAndConsumeCommands 在同一事务内拉取并删除该设备待执行指令，保证每条指令仅生效一次
	GetAndConsumeCommands(ctx context.Context, deviceID string) ([]Command, error)
	DeleteCommandsByMsgIDs(ctx context.Context, deviceID string, msgIDs []string) error
	ClearCommands(ctx context.Context, deviceID string) error

	// SeedBuiltinAppUser 开发/测试：若不存在 username=user123 则创建（密码 123456），见 dev-env/README 5.2
	SeedBuiltinAppUser(ctx context.Context) error

	// Build（build-sync 写入，admin 拉取）
	SaveBuild(ctx context.Context, b Build) error
	ListBuilds(ctx context.Context, limit int) ([]Build, error)

	// Admin：列出设备、用户、关系。uidFilter 单 uid；uidInList 非空时按多 uid 筛选（keyword 查询时用）
	ListDevices(ctx context.Context, page, pageSize int, uidFilter string, uidInList []string) ([]Device, int, error)
	GetDeviceByIDAdmin(ctx context.Context, deviceID string) (*Device, error)
	ListUsers(ctx context.Context, page, pageSize int, keyword string) ([]User, int, error)
	ListRelations(ctx context.Context, page, pageSize int, relationType string) ([]Relation, int, error)

	// Audit（PROTOCOL 3）：上传落库、check-sum 需更新类型
	SaveAuditBlob(ctx context.Context, deviceID, auditType, msgID, hash string, payload []byte) error
	GetAuditHashesForDevice(ctx context.Context, deviceID string) (map[string]string, error)
	ListAuditByDevice(ctx context.Context, deviceID, auditType string, limit int) ([]AuditItem, error)
	GetAuditBlob(ctx context.Context, id int64) (*AuditItem, error)
}

// AuditItem 审计记录（列表项或单条，payload 可选返回）
type AuditItem struct {
	ID        int64
	DeviceID  string
	Type      string
	MsgID     string
	Hash      string
	Size      int
	CreatedAt string
	Payload   []byte // 仅 GetAuditBlob 或下载时填充
}

type User struct {
	UID          string
	PhoneE164    string
	Username     string
	Nickname     string
	PasswordHash string
	Bio          string
	AvatarPath   string
	CreatedAt    string
}

type Device struct {
	DeviceID         string
	UID              string
	Nickname         string
	DeviceInfo       string // JSON
	LastIP           string
	LastLocationCity string // 用户端「附近」上报的市，仅显示市
	CreatedAt        string
}

type Invite struct {
	Code           string
	InviterUID     string
	InviterNickname string
	ExpireAt       int64
	MaxUse         int
	UsedCount      int
	CreatedAt      string
}

type Friend struct {
	UID        string
	Nickname   string
	Bio        string
	AvatarPath string
}

type Command struct {
	MsgID  string
	Cmd    string
	Params string // JSON
}

type Relation struct {
	Type       string
	InviterUID string
	InviteeUID string
	UIDA       string
	UIDB       string
	CreatedAt  string
}

type Build struct {
	ID          int64
	Version     string
	Build       int
	FileName    string
	DownloadURL string
	ChangeLog   string
	CreatedAt   string
}
