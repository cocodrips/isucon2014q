#!/bin/sh
base_dir=$(cd $(dirname $0)/../; pwd)
tmp_dir=${base_dir}/tmp

nginx_dir=${base_dir}/nginx
nginx_url=http://openresty.org/download/ngx_openresty-1.7.0.1.tar.gz

nginx_download(){
    mkdir -p ${tmp_dir}
    cd ${tmp_dir}
    if command -v curl > /dev/null 2>&1;then
        curl -O -L 
    else
        wget  ${nginx_url}
    fi
    zcat $(basename ${nginx_url}) | tar xf -
    cd -
}

nginx_build(){
    mkdir -p ${nginx_dir}
    cd ${tmp_dir}/$(basename ${nginx_url} .tar.gz)
    ./configure --prefix=${nginx_dir}
    make -j4
    make install
}

nginx_supervisord(){
    cat <<EOF
[program:nginx]
directory=${base_dir}
command=${nginx_dir}/nginx/sbin/nginx -p ${base_dir} -c config/nginx.conf
user=root
stdout_logfile=/tmp/isucon.nginx.log
stderr_logfile=/tmp/isucon.nginx.log
autostart=true
EOF
}

case $1 in
    nginx:all)
        nginx_download
        nginx_build
        ;;
    nginx:build)
        nginx_build
        ;;
    nginx:supervisord)
        nginx_supervisord
        ;;
    nginx:help)
        cat <<EOF
nginx:all=download+build+install
nginx:build=+build+install
nginx:supervisord=output config for supervisord
EOF
esac
