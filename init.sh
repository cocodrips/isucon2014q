#!/bin/sh
set -x
set -e
cd $(dirname $0)

myuser=root
mydb=isu4_qualifier
myhost=127.0.0.1
myport=3306
mysql -h ${myhost} -P ${myport} -u ${myuser} -e "DROP DATABASE IF EXISTS ${mydb}; CREATE DATABASE ${mydb}"
mysql -h ${myhost} -P ${myport} -u ${myuser} ${mydb} < sql/schema.sql
mysql -h ${myhost} -P ${myport} -u ${myuser} ${mydb} < sql/dummy_users.sql
mysql -h ${myhost} -P ${myport} -u ${myuser} ${mydb} < sql/dummy_log.sql

cat <<EOF
 'EOF' | mysql -h ${myhost} -P ${myport} -u ${myuser} -e
    CREATE INDEX user_idx_login ON users (login);
    CREATE INDEX login_log_idx_id_user_id_succeeded ON login_log (id, user_id, succeeded);
    CREATE INDEX login_log_idx_id_user_id_ip ON login_log (id, user_id, ip);
    CREATE INDEX login_log_idx_ip_id ON login_log (ip, id);
EOF
