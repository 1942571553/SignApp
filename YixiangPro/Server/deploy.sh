#!/usr/bin/env bash
set -e
# 艺祥签服务端一键部署（CentOS 7 / 宝塔，root 执行）
# 用法：bash deploy.sh
# 可选环境变量：YIXIANG_BASE_URL / YIXIANG_PORT / YIXIANG_ADMIN_PASSWORD

APP_DIR="/www/wwwroot/yixiang-server"
SERVICE="/etc/systemd/system/yixiang.service"
PORT="${YIXIANG_PORT:-8091}"
BASE_URL="${YIXIANG_BASE_URL:-https://sign.yixsc.cn}"
ADMIN_PASSWORD="${YIXIANG_ADMIN_PASSWORD:-yixiang2026}"

if [ "$(id -u)" != "0" ]; then
  echo "请用 root 执行：sudo bash deploy.sh"
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "未找到 python3，请先在宝塔【软件商店 → Python 项目管理器】安装 Python 3.8+"
  exit 1
fi

PYTHON_BIN="$(command -v python3)"
PYVER=$(python3 -c 'import sys; print(sys.version_info[0]*100+sys.version_info[1])')
if [ "$PYVER" -lt 308 ]; then
  echo "Python 版本过低（$(python3 --version)），需要 3.8+"
  echo "宝塔：软件商店 → Python 项目管理器 → 安装 Python 3.8+，或 yum install python38"
  exit 1
fi

mkdir -p "$APP_DIR/data/installs" "$APP_DIR/data/uploads" "$APP_DIR/data/tmp"
cp server.py "$APP_DIR/server.py"
cp schema.sql "$APP_DIR/schema.sql"
chown -R www:www "$APP_DIR"
chmod 755 "$APP_DIR" "$APP_DIR/server.py"
chmod -R 775 "$APP_DIR/data"

if [ ! -f "$APP_DIR/secret.txt" ]; then
  head -c 32 /dev/urandom | base64 | tr -d '\n' > "$APP_DIR/secret.txt"
fi
chown www:www "$APP_DIR/secret.txt"
chmod 600 "$APP_DIR/secret.txt"

cat > "$SERVICE" <<UNIT
[Unit]
Description=Yixiang Sign Server
After=network.target

[Service]
Type=simple
User=www
Group=www
WorkingDirectory=$APP_DIR
Environment=YIXIANG_HOST=127.0.0.1
Environment=YIXIANG_PORT=$PORT
Environment=YIXIANG_BASE_URL=$BASE_URL
Environment=YIXIANG_DATA=$APP_DIR/data
Environment=YIXIANG_DB=$APP_DIR/data/yixiang.db
Environment=YIXIANG_ADMIN_PASSWORD=$ADMIN_PASSWORD
ExecStart=$PYTHON_BIN $APP_DIR/server.py
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable yixiang
systemctl restart yixiang
sleep 2
systemctl --no-pager status yixiang | head -15 || true

echo ""
echo "服务端已启动：127.0.0.1:$PORT"
echo "管理后台：$BASE_URL/admin"
echo "默认管理员：admin / $ADMIN_PASSWORD"
echo "请确认 Nginx 已把 $BASE_URL 反代到 127.0.0.1:$PORT，并设置 client_max_body_size 900m"
