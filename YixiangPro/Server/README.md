# 艺祥签服务端 v2

Python 3.8+ 标准库 + SQLite，无第三方依赖。包含客户端配置、用户注册/登录、设备绑定、软件源、卡密、时间锁、IPA 临时分发、UDID 登记、管理后台。

## 一键部署（CentOS 7 + 宝塔）

1. 宝塔安装 Python 3.8+（软件商店 → Python 项目管理器）。
2. 上传本目录到服务器，例如 `/www/wwwroot/yixiang-server-src`。
3. 执行：

```bash
cd /www/wwwroot/yixiang-server-src
sudo bash deploy.sh
```

脚本会安装到 `/www/wwwroot/yixiang-server`，创建 systemd 服务 `yixiang.service`，监听 `127.0.0.1:8091`，数据在 `/www/wwwroot/yixiang-server/data/yixiang.db`。

4. 在宝塔站点 `sign.yixsc.cn` 的反向代理中加入 `nginx-yixiang.conf` 的配置，然后重载 Nginx。
5. 打开 `https://sign.yixsc.cn/admin`，默认账号 `admin`，密码 `yixiang2026`。首次部署务必修改密码。

## 常用命令

```bash
systemctl status yixiang
systemctl restart yixiang
journalctl -u yixiang -n 100 --no-pager
# 备份数据库
sqlite3 /www/wwwroot/yixiang-server/data/yixiang.db ".backup /www/backup/yixiang-$(date +%F).db"
```

## 配置接口

`GET https://sign.yixsc.cn/api/client/config`

带上 `Authorization: Bearer <token>` 与 `X-Device-ID` 可返回该用户已解锁的软件源与账号授权状态。

## 管理后台

- `/admin` 仪表盘
- `/admin/users` 用户、设备、授权到期
- `/admin/sources` 默认软件源、卡密开关、开放时间
- `/admin/cards` 批量生成卡密、绑定软件源、设备上限
- `/admin/settings` 品牌、功能开关、注册策略、全局时间锁
- `/admin/installs` 临时安装包记录

## 修改/忘记管理员密码

登录后台后可在 `/admin/settings` 底部“修改管理员密码”直接改密。忘记密码时，停止服务并删除 admin 用户，重启会按 `YIXIANG_ADMIN_PASSWORD`（默认 `yixiang2026`）重新初始化：

```bash
sudo systemctl stop yixiang
sqlite3 /www/wwwroot/yixiang-server/data/yixiang.db "DELETE FROM users WHERE username='admin';"
sudo systemctl start yixiang
```

## 重要说明

- 服务端只临时保存**已签名 IPA**用于 itms-services 分发，默认 24 小时清理，不保存 p12 和描述文件。
- 卡密、时间锁、默认软件源均由服务端下发，客户端刷新配置后生效。
- 生产环境请配置 HTTPS，并限制数据库文件权限。

## 数据库

服务端首次启动会自动创建 `data/yixiang.db`，表结构见 `schema.sql`。核心表：

- `users`：注册用户、角色、状态、授权到期
- `sessions`：登录令牌
- `devices`：设备绑定（X-Device-ID / UDID）
- `sources`：默认软件源、卡密开关、开放时间
- `cards`：卡密、绑定源、天数、设备上限
- `redemptions`：兑换记录
- `installs`：临时分发的已签名 IPA
- `settings`：品牌、公告、功能开关、全局时间锁
- `logs`：管理操作日志

后台 `/admin/users` 可直接启用/禁用用户、修改授权到期时间；`/admin/sources` 管理默认源；`/admin/cards` 生成和解锁卡密；`/admin/settings` 控制时间锁、注册开放、安装需登录、品牌与公告。
