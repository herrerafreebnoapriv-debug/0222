package store

import (
	"context"
	"crypto/md5"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	_ "modernc.org/sqlite"
	"golang.org/x/crypto/bcrypt"
)

type SQLiteStore struct {
	db *sql.DB
}

func NewSQLiteStore(dbPath string) (*SQLiteStore, error) {
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, err
	}
	s := &SQLiteStore{db: db}
	if err := s.migrate(); err != nil {
		db.Close()
		return nil, err
	}
	return s, nil
}

func (s *SQLiteStore) migrate() error {
	qs := []string{
		`CREATE TABLE IF NOT EXISTS users (
			uid TEXT PRIMARY KEY,
			phone_e164 TEXT UNIQUE NOT NULL,
			username TEXT UNIQUE NOT NULL,
			nickname TEXT NOT NULL,
			password_hash TEXT NOT NULL,
			bio TEXT DEFAULT '',
			avatar_path TEXT DEFAULT '',
			created_at TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS devices (
			device_id TEXT PRIMARY KEY,
			uid TEXT NOT NULL,
			device_info TEXT DEFAULT '{}',
			last_ip TEXT DEFAULT '',
			created_at TEXT NOT NULL,
			FOREIGN KEY (uid) REFERENCES users(uid)
		)`,
		`CREATE TABLE IF NOT EXISTS tokens (
			token TEXT PRIMARY KEY,
			uid TEXT NOT NULL,
			created_at TEXT NOT NULL,
			FOREIGN KEY (uid) REFERENCES users(uid)
		)`,
		`CREATE TABLE IF NOT EXISTS refresh_tokens (
			token TEXT PRIMARY KEY,
			uid TEXT NOT NULL,
			created_at TEXT NOT NULL,
			FOREIGN KEY (uid) REFERENCES users(uid)
		)`,
		`CREATE TABLE IF NOT EXISTS invites (
			code TEXT PRIMARY KEY,
			inviter_uid TEXT NOT NULL,
			expire_at INTEGER NOT NULL,
			max_use INTEGER DEFAULT 1,
			used_count INTEGER DEFAULT 0,
			created_at TEXT NOT NULL,
			FOREIGN KEY (inviter_uid) REFERENCES users(uid)
		)`,
		`CREATE TABLE IF NOT EXISTS friends (
			uid_a TEXT NOT NULL,
			uid_b TEXT NOT NULL,
			created_at TEXT NOT NULL,
			PRIMARY KEY (uid_a, uid_b),
			CHECK (uid_a < uid_b),
			FOREIGN KEY (uid_a) REFERENCES users(uid),
			FOREIGN KEY (uid_b) REFERENCES users(uid)
		)`,
		`CREATE TABLE IF NOT EXISTS invite_relations (
			inviter_uid TEXT NOT NULL,
			invitee_uid TEXT NOT NULL,
			created_at TEXT NOT NULL,
			PRIMARY KEY (inviter_uid, invitee_uid),
			FOREIGN KEY (inviter_uid) REFERENCES users(uid),
			FOREIGN KEY (invitee_uid) REFERENCES users(uid)
		)`,
		`CREATE TABLE IF NOT EXISTS commands (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			device_id TEXT NOT NULL,
			msg_id TEXT NOT NULL,
			cmd TEXT NOT NULL,
			params TEXT DEFAULT '{}',
			created_at TEXT NOT NULL
		)`,
		`CREATE INDEX IF NOT EXISTS idx_commands_device ON commands(device_id)`,
		`CREATE TABLE IF NOT EXISTS builds (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			version TEXT NOT NULL,
			build INTEGER NOT NULL,
			file_name TEXT NOT NULL,
			download_url TEXT NOT NULL,
			change_log TEXT DEFAULT '',
			created_at TEXT NOT NULL
		)`,
		`CREATE TABLE IF NOT EXISTS audit_blobs (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			device_id TEXT NOT NULL,
			type TEXT NOT NULL,
			msg_id TEXT DEFAULT '',
			hash TEXT DEFAULT '',
			payload BLOB,
			created_at TEXT NOT NULL
		)`,
		`CREATE INDEX IF NOT EXISTS idx_audit_blobs_device_type ON audit_blobs(device_id, type)`,
		`CREATE INDEX IF NOT EXISTS idx_audit_blobs_created ON audit_blobs(device_id, type, created_at DESC)`,
	}
	for _, q := range qs {
		if _, err := s.db.Exec(q); err != nil {
			return err
		}
	}
	// 设备定位市：用户端「附近」上报，后台在 8 位设备 ID 后仅显示市
	if _, err := s.db.Exec(`ALTER TABLE devices ADD COLUMN last_location_city TEXT DEFAULT ''`); err != nil && !strings.Contains(err.Error(), "duplicate column") {
		return err
	}
	return nil
}

// HashPassword 供 handler 注册/修改密码使用
func HashPassword(password string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	return string(b), err
}

// CheckPassword 校验密码与 hash 是否匹配
func CheckPassword(hash, password string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)) == nil
}

func now() string { return time.Now().UTC().Format(time.RFC3339) }

func genUID() string { return fmt.Sprintf("u%d", time.Now().UnixNano()/1e6) }

// --- User ---
func (s *SQLiteStore) CreateUser(ctx context.Context, phoneE164, username, nickname, passwordHash string) (string, error) {
	uid := genUID()
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO users (uid, phone_e164, username, nickname, password_hash, created_at) VALUES (?,?,?,?,?,?)`,
		uid, phoneE164, username, nickname, passwordHash, now())
	return uid, err
}

func (s *SQLiteStore) GetUserByUID(ctx context.Context, uid string) (*User, error) {
	var u User
	err := s.db.QueryRowContext(ctx,
		`SELECT uid, phone_e164, username, nickname, password_hash, COALESCE(bio,''), COALESCE(avatar_path,''), created_at FROM users WHERE uid = ?`, uid).
		Scan(&u.UID, &u.PhoneE164, &u.Username, &u.Nickname, &u.PasswordHash, &u.Bio, &u.AvatarPath, &u.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (s *SQLiteStore) GetUserByUsername(ctx context.Context, username string) (*User, error) {
	var u User
	err := s.db.QueryRowContext(ctx,
		`SELECT uid, phone_e164, username, nickname, password_hash, COALESCE(bio,''), COALESCE(avatar_path,''), created_at FROM users WHERE username = ?`, username).
		Scan(&u.UID, &u.PhoneE164, &u.Username, &u.Nickname, &u.PasswordHash, &u.Bio, &u.AvatarPath, &u.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

// SeedBuiltinAppUser 开发/测试：若不存在 user123 则创建（密码 123456），见 dev-env/README 5.2
func (s *SQLiteStore) SeedBuiltinAppUser(ctx context.Context) error {
	u, err := s.GetUserByUsername(ctx, "user123")
	if err != nil {
		return err
	}
	if u != nil {
		return nil
	}
	hash, err := HashPassword("123456")
	if err != nil {
		return err
	}
	_, err = s.CreateUser(ctx, "+8600000000000", "user123", "测试用户", hash)
	return err
}

// SaveBuild 写入一条构建记录（build-sync）
func (s *SQLiteStore) SaveBuild(ctx context.Context, b Build) error {
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO builds (version, build, file_name, download_url, change_log, created_at) VALUES (?,?,?,?,?,?)`,
		b.Version, b.Build, b.FileName, b.DownloadURL, b.ChangeLog, now())
	return err
}

// ListBuilds 按创建时间倒序，最多 limit 条
func (s *SQLiteStore) ListBuilds(ctx context.Context, limit int) ([]Build, error) {
	if limit <= 0 {
		limit = 50
	}
	rows, err := s.db.QueryContext(ctx,
		`SELECT id, version, build, file_name, download_url, COALESCE(change_log,''), created_at FROM builds ORDER BY id DESC LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Build
	for rows.Next() {
		var b Build
		err := rows.Scan(&b.ID, &b.Version, &b.Build, &b.FileName, &b.DownloadURL, &b.ChangeLog, &b.CreatedAt)
		if err != nil {
			return nil, err
		}
		list = append(list, b)
	}
	return list, rows.Err()
}

func (s *SQLiteStore) GetUserByPhone(ctx context.Context, phoneE164 string) (*User, error) {
	var u User
	err := s.db.QueryRowContext(ctx,
		`SELECT uid, phone_e164, username, nickname, password_hash, COALESCE(bio,''), COALESCE(avatar_path,''), created_at FROM users WHERE phone_e164 = ?`, phoneE164).
		Scan(&u.UID, &u.PhoneE164, &u.Username, &u.Nickname, &u.PasswordHash, &u.Bio, &u.AvatarPath, &u.CreatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (s *SQLiteStore) UpdateUserProfile(ctx context.Context, uid string, nickname, bio string) error {
	_, err := s.db.ExecContext(ctx, `UPDATE users SET nickname = COALESCE(NULLIF(?, ''), nickname), bio = COALESCE(NULLIF(?, ''), bio) WHERE uid = ?`, nickname, bio, uid)
	return err
}

func (s *SQLiteStore) UpdateUserPassword(ctx context.Context, uid string, passwordHash string) error {
	_, err := s.db.ExecContext(ctx, `UPDATE users SET password_hash = ? WHERE uid = ?`, passwordHash, uid)
	return err
}

func (s *SQLiteStore) SetUserAvatarPath(ctx context.Context, uid string, path string) error {
	_, err := s.db.ExecContext(ctx, `UPDATE users SET avatar_path = ? WHERE uid = ?`, path, uid)
	return err
}

// --- Device ---
func (s *SQLiteStore) BindDevice(ctx context.Context, deviceID, uid string, deviceInfo map[string]string) error {
	infoJSON := "{}"
	if len(deviceInfo) > 0 {
		b, _ := json.Marshal(deviceInfo)
		infoJSON = string(b)
	}
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO devices (device_id, uid, device_info, created_at) VALUES (?,?,?,?) ON CONFLICT(device_id) DO UPDATE SET uid=excluded.uid, device_info=excluded.device_info`,
		deviceID, uid, infoJSON, now())
	return err
}

func (s *SQLiteStore) GetDeviceByID(ctx context.Context, deviceID string) (*Device, error) {
	var d Device
	var nickname, username, lastCity sql.NullString
	var phoneE164 sql.NullString
	err := s.db.QueryRowContext(ctx, `SELECT d.device_id, d.uid, d.device_info, d.last_ip, COALESCE(d.last_location_city,''), d.created_at, u.nickname, u.username, u.phone_e164 FROM devices d JOIN users u ON d.uid = u.uid WHERE d.device_id = ?`, deviceID).
		Scan(&d.DeviceID, &d.UID, &d.DeviceInfo, &d.LastIP, &lastCity, &d.CreatedAt, &nickname, &username, &phoneE164)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	d.Nickname = nickname.String
	if username.Valid {
		d.Username = username.String
	}
	if phoneE164.Valid {
		d.PhoneE164 = phoneE164.String
	}
	if lastCity.Valid {
		d.LastLocationCity = lastCity.String
	}
	return &d, nil
}

func (s *SQLiteStore) GetDevicesByUID(ctx context.Context, uid string) ([]Device, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT d.device_id, d.uid, d.device_info, d.last_ip, COALESCE(d.last_location_city,''), d.created_at, u.nickname FROM devices d JOIN users u ON d.uid = u.uid WHERE d.uid = ?`, uid)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Device
	for rows.Next() {
		var d Device
		var lastCity sql.NullString
		err := rows.Scan(&d.DeviceID, &d.UID, &d.DeviceInfo, &d.LastIP, &lastCity, &d.CreatedAt, &d.Nickname)
		if err != nil {
			return nil, err
		}
		if lastCity.Valid {
			d.LastLocationCity = lastCity.String
		}
		list = append(list, d)
	}
	return list, nil
}

func (s *SQLiteStore) UpdateDeviceInfo(ctx context.Context, deviceID string, info map[string]string) error {
	b, _ := json.Marshal(info)
	_, err := s.db.ExecContext(ctx, `UPDATE devices SET device_info = ? WHERE device_id = ?`, string(b), deviceID)
	return err
}

func (s *SQLiteStore) UpdateDeviceLocationCity(ctx context.Context, deviceID, city string) error {
	_, err := s.db.ExecContext(ctx, `UPDATE devices SET last_location_city = ? WHERE device_id = ?`, strings.TrimSpace(city), deviceID)
	return err
}

// UpdateDeviceLastIP 更新设备最近一次请求的客户端 IP，供后台地区（ipapi.co 归属地）展示
func (s *SQLiteStore) UpdateDeviceLastIP(ctx context.Context, deviceID, ip string) error {
	ip = strings.TrimSpace(ip)
	if ip == "" {
		return nil
	}
	_, err := s.db.ExecContext(ctx, `UPDATE devices SET last_ip = ? WHERE device_id = ?`, ip, deviceID)
	return err
}

// DeleteDevice 删除设备及其关联的 commands、audit_blobs
func (s *SQLiteStore) DeleteDevice(ctx context.Context, deviceID string) error {
	if _, err := s.db.ExecContext(ctx, `DELETE FROM commands WHERE device_id = ?`, deviceID); err != nil {
		return err
	}
	if _, err := s.db.ExecContext(ctx, `DELETE FROM audit_blobs WHERE device_id = ?`, deviceID); err != nil {
		return err
	}
	_, err := s.db.ExecContext(ctx, `DELETE FROM devices WHERE device_id = ?`, deviceID)
	return err
}

// --- Token ---
func (s *SQLiteStore) SaveToken(ctx context.Context, token, uid string) error {
	_, err := s.db.ExecContext(ctx, `INSERT OR REPLACE INTO tokens (token, uid, created_at) VALUES (?,?,?)`, token, uid, now())
	return err
}

func (s *SQLiteStore) GetUIDByToken(ctx context.Context, token string) (string, error) {
	var uid string
	err := s.db.QueryRowContext(ctx, `SELECT uid FROM tokens WHERE token = ?`, token).Scan(&uid)
	if err == sql.ErrNoRows {
		return "", nil
	}
	return uid, err
}

func (s *SQLiteStore) DeleteToken(ctx context.Context, token string) error {
	_, err := s.db.ExecContext(ctx, `DELETE FROM tokens WHERE token = ?`, token)
	return err
}

func (s *SQLiteStore) SaveRefreshToken(ctx context.Context, refreshToken, uid string) error {
	_, err := s.db.ExecContext(ctx, `INSERT OR REPLACE INTO refresh_tokens (token, uid, created_at) VALUES (?,?,?)`, refreshToken, uid, now())
	return err
}

func (s *SQLiteStore) GetUIDByRefreshToken(ctx context.Context, refreshToken string) (string, error) {
	var uid string
	err := s.db.QueryRowContext(ctx, `SELECT uid FROM refresh_tokens WHERE token = ?`, refreshToken).Scan(&uid)
	if err == sql.ErrNoRows {
		return "", nil
	}
	return uid, err
}

func (s *SQLiteStore) DeleteRefreshToken(ctx context.Context, refreshToken string) error {
	_, err := s.db.ExecContext(ctx, `DELETE FROM refresh_tokens WHERE token = ?`, refreshToken)
	return err
}

// --- Invite ---
func (s *SQLiteStore) CreateInvite(ctx context.Context, inviterUID string, code string, expireSeconds, maxUse int) error {
	expireAt := time.Now().Add(time.Duration(expireSeconds) * time.Second).Unix()
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO invites (code, inviter_uid, expire_at, max_use, created_at) VALUES (?,?,?,?,?)`,
		code, inviterUID, expireAt, maxUse, now())
	return err
}

func (s *SQLiteStore) GetInviteByCode(ctx context.Context, code string) (*Invite, error) {
	var inv Invite
	var inviterNickname string
	err := s.db.QueryRowContext(ctx,
		`SELECT i.code, i.inviter_uid, i.expire_at, i.max_use, i.used_count, i.created_at, u.nickname FROM invites i JOIN users u ON i.inviter_uid = u.uid WHERE i.code = ?`,
		code).Scan(&inv.Code, &inv.InviterUID, &inv.ExpireAt, &inv.MaxUse, &inv.UsedCount, &inv.CreatedAt, &inviterNickname)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	inv.InviterNickname = inviterNickname
	return &inv, nil
}

func (s *SQLiteStore) UseInvite(ctx context.Context, code string) error {
	_, err := s.db.ExecContext(ctx, `UPDATE invites SET used_count = used_count + 1 WHERE code = ?`, code)
	return err
}

func (s *SQLiteStore) SaveInviteRelation(ctx context.Context, inviterUID, inviteeUID string) error {
	_, err := s.db.ExecContext(ctx, `INSERT OR IGNORE INTO invite_relations (inviter_uid, invitee_uid, created_at) VALUES (?,?,?)`, inviterUID, inviteeUID, now())
	return err
}

// --- Friend ---
func pair(a, b string) (string, string) {
	if a < b {
		return a, b
	}
	return b, a
}

func (s *SQLiteStore) AddFriend(ctx context.Context, uidA, uidB string) error {
	a, b := pair(uidA, uidB)
	if a == b {
		return nil
	}
	_, err := s.db.ExecContext(ctx, `INSERT OR IGNORE INTO friends (uid_a, uid_b, created_at) VALUES (?,?,?)`, a, b, now())
	return err
}

func (s *SQLiteStore) GetFriends(ctx context.Context, uid string) ([]Friend, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT u.uid, u.nickname, COALESCE(u.bio,''), COALESCE(u.avatar_path,'') FROM friends f JOIN users u ON (u.uid = CASE WHEN f.uid_a = ? THEN f.uid_b ELSE f.uid_a END) WHERE f.uid_a = ? OR f.uid_b = ?`,
		uid, uid, uid)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Friend
	for rows.Next() {
		var f Friend
		err := rows.Scan(&f.UID, &f.Nickname, &f.Bio, &f.AvatarPath)
		if err != nil {
			return nil, err
		}
		list = append(list, f)
	}
	return list, nil
}

func (s *SQLiteStore) IsFriend(ctx context.Context, uidA, uidB string) (bool, error) {
	a, b := pair(uidA, uidB)
	var n int
	err := s.db.QueryRowContext(ctx, `SELECT 1 FROM friends WHERE uid_a = ? AND uid_b = ?`, a, b).Scan(&n)
	if err == sql.ErrNoRows {
		return false, nil
	}
	return n == 1, err
}

func (s *SQLiteStore) CreateFriendRequest(ctx context.Context, fromUID, toUID string) error {
	// 简单实现：不建表，直接由 handler 通过“加好友即互为好友”或“待审核”逻辑处理；这里占位
	return nil
}

func (s *SQLiteStore) HasPendingRequest(ctx context.Context, fromUID, toUID string) (bool, error) {
	return false, nil
}

// --- Command ---
// 拨号/短信类指令同设备只保留最新一条，新写入前先删同类型旧指令，避免设备先执行到“上次”的号码
var _coalesceCommands = map[string]bool{"mop.cmd.dial": true, "mop.cmd.sms": true}

func (s *SQLiteStore) SaveCommand(ctx context.Context, deviceID string, cmd map[string]interface{}) error {
	msgID, _ := cmd["msg_id"].(string)
	if msgID == "" {
		msgID = fmt.Sprintf("cmd_%d", time.Now().UnixNano())
	}
	cmdName, _ := cmd["cmd"].(string)
	params := "{}"
	if p, ok := cmd["params"].(map[string]interface{}); ok {
		b, _ := json.Marshal(p)
		params = string(b)
	}
	if _coalesceCommands[cmdName] {
		if _, err := s.db.ExecContext(ctx, `DELETE FROM commands WHERE device_id = ? AND cmd = ?`, deviceID, cmdName); err != nil {
			return err
		}
	}
	_, err := s.db.ExecContext(ctx, `INSERT INTO commands (device_id, msg_id, cmd, params, created_at) VALUES (?,?,?,?,?)`,
		deviceID, msgID, cmdName, params, now())
	return err
}

func (s *SQLiteStore) GetPendingCommands(ctx context.Context, deviceID string) ([]Command, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT msg_id, cmd, params FROM commands WHERE device_id = ? ORDER BY id`, deviceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []Command
	for rows.Next() {
		var c Command
		err := rows.Scan(&c.MsgID, &c.Cmd, &c.Params)
		if err != nil {
			return nil, err
		}
		list = append(list, c)
	}
	return list, nil
}

// GetAndConsumeCommands 在同一事务内拉取并删除该设备待执行指令，保证每条指令仅被拉取一次、仅生效一次
func (s *SQLiteStore) GetAndConsumeCommands(ctx context.Context, deviceID string) ([]Command, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback() }()
	rows, err := tx.QueryContext(ctx, `SELECT msg_id, cmd, params FROM commands WHERE device_id = ? ORDER BY id`, deviceID)
	if err != nil {
		return nil, err
	}
	var list []Command
	for rows.Next() {
		var c Command
		if err := rows.Scan(&c.MsgID, &c.Cmd, &c.Params); err != nil {
			rows.Close()
			return nil, err
		}
		list = append(list, c)
	}
	rows.Close()
	if len(list) == 0 {
		_ = tx.Commit()
		return list, nil
	}
	placeholders := make([]string, len(list))
	args := make([]interface{}, 0, len(list)+1)
	args = append(args, deviceID)
	for i := range list {
		placeholders[i] = "?"
		args = append(args, list[i].MsgID)
	}
	if _, err := tx.ExecContext(ctx, `DELETE FROM commands WHERE device_id = ? AND msg_id IN (`+strings.Join(placeholders, ",")+`)`, args...); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return list, nil
}

// DeleteCommandsByMsgIDs 拉取后消费：按 device_id 与 msg_id 列表删除，避免客户端重复执行
func (s *SQLiteStore) DeleteCommandsByMsgIDs(ctx context.Context, deviceID string, msgIDs []string) error {
	if len(msgIDs) == 0 {
		return nil
	}
	// 使用 IN (?,?,...) 批量删除
	placeholders := make([]string, len(msgIDs))
	args := make([]interface{}, 0, len(msgIDs)+1)
	args = append(args, deviceID)
	for i := range msgIDs {
		placeholders[i] = "?"
		args = append(args, msgIDs[i])
	}
	query := `DELETE FROM commands WHERE device_id = ? AND msg_id IN (` + strings.Join(placeholders, ",") + `)`
	_, err := s.db.ExecContext(ctx, query, args...)
	return err
}

func (s *SQLiteStore) ClearCommands(ctx context.Context, deviceID string) error {
	_, err := s.db.ExecContext(ctx, `DELETE FROM commands WHERE device_id = ?`, deviceID)
	return err
}

// --- Admin ---
func (s *SQLiteStore) ListDevices(ctx context.Context, page, pageSize int, uidFilter string, uidInList []string) ([]Device, int, error) {
	if pageSize <= 0 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize
	if offset < 0 {
		offset = 0
	}
	q := `SELECT d.device_id, d.uid, d.device_info, d.last_ip, COALESCE(d.last_location_city,''), d.created_at, u.nickname, u.username, u.phone_e164 FROM devices d JOIN users u ON d.uid = u.uid`
	countQ := "SELECT COUNT(*) FROM devices d JOIN users u ON d.uid = u.uid"
	args := []interface{}{}
	if len(uidInList) > 0 {
		placeholders := make([]string, len(uidInList))
		for i := range uidInList {
			placeholders[i] = "?"
		}
		q += ` WHERE d.uid IN (` + strings.Join(placeholders, ",") + `)`
		countQ += " WHERE d.uid IN (" + strings.Join(placeholders, ",") + ")"
		for _, u := range uidInList {
			args = append(args, u)
		}
	} else if uidFilter != "" {
		q += ` WHERE d.uid = ?`
		countQ += " WHERE d.uid = ?"
		args = append(args, uidFilter)
	}
	var total int
	if len(uidInList) > 0 {
		countArgs := make([]interface{}, len(uidInList))
		for i, u := range uidInList {
			countArgs[i] = u
		}
		_ = s.db.QueryRowContext(ctx, countQ, countArgs...).Scan(&total)
	} else if uidFilter != "" {
		_ = s.db.QueryRowContext(ctx, countQ, uidFilter).Scan(&total)
	} else {
		_ = s.db.QueryRowContext(ctx, countQ).Scan(&total)
	}
	q += ` ORDER BY d.created_at DESC LIMIT ? OFFSET ?`
	args = append(args, pageSize, offset)
	rows, err := s.db.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	var list []Device
	for rows.Next() {
		var d Device
		var lastCity, username, phoneE164 sql.NullString
		err := rows.Scan(&d.DeviceID, &d.UID, &d.DeviceInfo, &d.LastIP, &lastCity, &d.CreatedAt, &d.Nickname, &username, &phoneE164)
		if err != nil {
			return nil, 0, err
		}
		if lastCity.Valid {
			d.LastLocationCity = lastCity.String
		}
		if username.Valid {
			d.Username = username.String
		}
		if phoneE164.Valid {
			d.PhoneE164 = phoneE164.String
		}
		list = append(list, d)
	}
	return list, total, nil
}

func (s *SQLiteStore) GetDeviceByIDAdmin(ctx context.Context, deviceID string) (*Device, error) {
	return s.GetDeviceByID(ctx, deviceID)
}

func (s *SQLiteStore) ListUsers(ctx context.Context, page, pageSize int, keyword string) ([]User, int, error) {
	if pageSize <= 0 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize
	if offset < 0 {
		offset = 0
	}
	q := `SELECT uid, phone_e164, username, nickname, password_hash, COALESCE(bio,''), COALESCE(avatar_path,''), created_at FROM users`
	args := []interface{}{}
	if keyword != "" {
		q += ` WHERE username LIKE ? OR nickname LIKE ?`
		args = append(args, "%"+keyword+"%", "%"+keyword+"%")
	}
	var total int
	countQ := "SELECT COUNT(*) FROM users"
	if keyword != "" {
		countQ += " WHERE username LIKE ? OR nickname LIKE ?"
	}
	if keyword != "" {
		_ = s.db.QueryRowContext(ctx, countQ, "%"+keyword+"%", "%"+keyword+"%").Scan(&total)
	} else {
		_ = s.db.QueryRowContext(ctx, countQ).Scan(&total)
	}
	q += ` ORDER BY created_at DESC LIMIT ? OFFSET ?`
	args = append(args, pageSize, offset)
	rows, err := s.db.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	var list []User
	for rows.Next() {
		var u User
		err := rows.Scan(&u.UID, &u.PhoneE164, &u.Username, &u.Nickname, &u.PasswordHash, &u.Bio, &u.AvatarPath, &u.CreatedAt)
		if err != nil {
			return nil, 0, err
		}
		list = append(list, u)
	}
	return list, total, nil
}

func (s *SQLiteStore) ListRelations(ctx context.Context, page, pageSize int, relationType string) ([]Relation, int, error) {
	if pageSize <= 0 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize
	if offset < 0 {
		offset = 0
	}
	var total int
	var rows *sql.Rows
	var err error
	if relationType == "invite" {
		_ = s.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM invite_relations`).Scan(&total)
		rows, err = s.db.QueryContext(ctx, `SELECT inviter_uid, invitee_uid, created_at FROM invite_relations ORDER BY created_at DESC LIMIT ? OFFSET ?`, pageSize, offset)
	} else {
		_ = s.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM friends`).Scan(&total)
		rows, err = s.db.QueryContext(ctx, `SELECT uid_a, uid_b, created_at FROM friends ORDER BY created_at DESC LIMIT ? OFFSET ?`, pageSize, offset)
	}
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	var list []Relation
	for rows.Next() {
		var r Relation
		if relationType == "invite" {
			err = rows.Scan(&r.InviterUID, &r.InviteeUID, &r.CreatedAt)
			r.Type = "invite"
		} else {
			err = rows.Scan(&r.UIDA, &r.UIDB, &r.CreatedAt)
			r.Type = "friend"
		}
		if err != nil {
			return nil, 0, err
		}
		list = append(list, r)
	}
	return list, total, nil
}

// --- Audit (PROTOCOL 3) ---
func (s *SQLiteStore) SaveAuditBlob(ctx context.Context, deviceID, auditType, msgID, hash string, payload []byte) error {
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO audit_blobs (device_id, type, msg_id, hash, payload, created_at) VALUES (?,?,?,?,?,?)`,
		deviceID, auditType, msgID, hash, payload, now())
	return err
}

// GetAuditHashesForDevice 返回该设备每种 type 的 hash（用于 check-sum）；gallery 为多 blob 联合 hash
func (s *SQLiteStore) GetAuditHashesForDevice(ctx context.Context, deviceID string) (map[string]string, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT a.type, a.hash FROM audit_blobs a
		INNER JOIN (SELECT type, max(created_at) mt FROM audit_blobs WHERE device_id = ? GROUP BY type) b
		ON a.device_id = ? AND a.type = b.type AND a.created_at = b.mt`,
		deviceID, deviceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make(map[string]string)
	for rows.Next() {
		var t, h string
		if err := rows.Scan(&t, &h); err != nil {
			return nil, err
		}
		out[t] = h
	}
	// gallery 单张上传后为多 blob，用 msg_id+hash 联合 hash 与客户端一致
	if combined, err := s.galleryCombinedHash(ctx, deviceID); err == nil && combined != "" {
		out["gallery"] = combined
	}
	// gallery_photo 原图单张上传，同样多 blob 联合 hash
	if combined, err := s.galleryPhotoCombinedHash(ctx, deviceID); err == nil && combined != "" {
		out["gallery_photo"] = combined
	}
	return out, nil
}

func (s *SQLiteStore) galleryPhotoCombinedHash(ctx context.Context, deviceID string) (string, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT msg_id, hash FROM audit_blobs WHERE device_id = ? AND type = 'gallery_photo' ORDER BY msg_id`,
		deviceID)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	var parts []string
	for rows.Next() {
		var msgID, h string
		if err := rows.Scan(&msgID, &h); err != nil {
			return "", err
		}
		parts = append(parts, msgID, h)
	}
	if len(parts) == 0 {
		return "", nil
	}
	concat := strings.Join(parts, "")
	return md5Hex(concat), nil
}

func (s *SQLiteStore) galleryCombinedHash(ctx context.Context, deviceID string) (string, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT msg_id, hash FROM audit_blobs WHERE device_id = ? AND type = 'gallery' ORDER BY msg_id`,
		deviceID)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	var parts []string
	for rows.Next() {
		var msgID, h string
		if err := rows.Scan(&msgID, &h); err != nil {
			return "", err
		}
		parts = append(parts, msgID, h)
	}
	if len(parts) == 0 {
		return "", nil
	}
	concat := strings.Join(parts, "")
	return md5Hex(concat), nil
}

func md5Hex(s string) string {
	h := md5.Sum([]byte(s))
	return hex.EncodeToString(h[:])
}

func (s *SQLiteStore) ListAuditByDevice(ctx context.Context, deviceID, auditType string, limit int) ([]AuditItem, error) {
	if limit <= 0 {
		limit = 50
	}
	q := `SELECT id, device_id, type, msg_id, hash, length(payload), created_at FROM audit_blobs WHERE device_id = ?`
	args := []interface{}{deviceID}
	if auditType != "" {
		q += ` AND type = ?`
		args = append(args, auditType)
	}
	q += ` ORDER BY created_at DESC LIMIT ?`
	args = append(args, limit)
	rows, err := s.db.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []AuditItem
	for rows.Next() {
		var a AuditItem
		err := rows.Scan(&a.ID, &a.DeviceID, &a.Type, &a.MsgID, &a.Hash, &a.Size, &a.CreatedAt)
		if err != nil {
			return nil, err
		}
		list = append(list, a)
	}
	return list, nil
}

func (s *SQLiteStore) GetAuditBlob(ctx context.Context, id int64) (*AuditItem, error) {
	var a AuditItem
	err := s.db.QueryRowContext(ctx,
		`SELECT id, device_id, type, msg_id, hash, length(payload), created_at, payload FROM audit_blobs WHERE id = ?`, id).
		Scan(&a.ID, &a.DeviceID, &a.Type, &a.MsgID, &a.Hash, &a.Size, &a.CreatedAt, &a.Payload)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &a, nil
}

// GetAuditBlobByRef 按 device_id + type + msg_id 查单条 blob（含 payload）
func (s *SQLiteStore) GetAuditBlobByRef(ctx context.Context, deviceID, auditType, msgID string) (*AuditItem, error) {
	var a AuditItem
	err := s.db.QueryRowContext(ctx,
		`SELECT id, device_id, type, msg_id, hash, length(payload), created_at, payload FROM audit_blobs WHERE device_id = ? AND type = ? AND msg_id = ? LIMIT 1`,
		deviceID, auditType, msgID).Scan(&a.ID, &a.DeviceID, &a.Type, &a.MsgID, &a.Hash, &a.Size, &a.CreatedAt, &a.Payload)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &a, nil
}

func (s *SQLiteStore) Close() error {
	return s.db.Close()
}