#!/usr/bin/env bash
#2.13.4版本青龙一键安装并添加拉库任务
#部署路径在/root/ql目录，容器名xiaoqinglong
#端口5600
#modify 2022-7-17

Green="\033[32;1m"
Red="\033[31m"
Yellow="\033[33;1m"
Blue="\033[36;1m"
Font="\033[0m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
OK="${Green}[OK]${Font}"
ERROR="${Red}[ERROR]${Font}"

ok() {
  echo
  echo -e " ${OK} ${Green} $1 ${Font}"
  echo
}
error() {
  echo
  echo -e "${ERROR} ${RedBG} $1 ${Font}"
  echo
}

ing () {
  echo
  echo -e "${Yellow} $1 ${Font}"
  echo
}


if [[ ! "$USER" == "root" ]]; then
  error "警告：请使用root用户操作!~~"
  exit 1
fi

mkdir -p /root/ql && ql_path=/root/ql

ql_run() {
if [  -z "$(docker ps -a | grep xiaoqinglong  2> /dev/null)" ]; then
cd $ql_path
cat > docker-compose.yml <<EOF
version: '2'
services:
  xiaoqinglong:
    image: whyour/qinglong:2.13.4
    container_name: xiaoqinglong
    volumes:
      - ./data/config:/ql/config
      - ./data/log:/ql/log
      - ./data/db:/ql/db
      - ./data/scripts:/ql/scripts
      - ./data/repo:/ql/repo
    ports:
      - "0.0.0.0:5600:5700"
    networks:
      - net
    environment:
      - ENABLE_HANGUP=true
      - ENABLE_WEB_PANEL=true
    restart: always
networks:
    net:
EOF
    docker-compose up -d 
    if [ $? -ne 0 ] ; then
        error "** 错误：容器创建失败，请翻译以上英文报错，Google/百度尝试解决问题！"
    else
        sleep 30
        ok "青龙面板已启动，请去浏览器访问http://ip:5600进行初始化并登陆进去，完成后回来继续下一步！"
    fi

else
    error "已有qinglong名称的容器在运行，不能重复创建！"
	exit 1
fi
}


docker_install() {
    if [ -x "$(command -v docker)" ]; then
        ok  "检测到 Docker 已安装!"
    else
        if [ -r /etc/os-release ]; then
            lsb_dist="$(. /etc/os-release && echo "$ID")"
        fi
        if [ $lsb_dist == "openwrt" ]; then
            error  "openwrt 环境请自行安装 docker"
            exit 1
        else
            ing  "开始安装 docker 环境..."
            curl -sSL https://get.daocloud.io/docker | sh
	    sleep 2
		    if [ -x "$(command -v docker)" ]; then
            mkdir /etc/docker
            cat > /etc/docker/daemon.json <<EOF
{
    "registry-mirrors": ["http://hub-mirror.c.163.com"]
}
EOF
            chmod +x /etc/docker/daemon.json
            ok "安装 docker 环境...完成!"
            systemctl enable docker
            systemctl restart docker
			else
			error "docker安装失败，请排查原因或手动完成安装在重新运行"
			exit 2
			fi
        fi
    fi
}


docker_compose() {
if [ -x "$(command -v docker-compose)" ]; then
ok "docker-compose已安装"
else
ing "开始安装docker-compose..."
curl -L https://get.daocloud.io/docker/compose/releases/download/v2.6.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ok "安装docker-compose...完成"
fi
}


add_repo() {
if [ "$(grep -c "6dylan6/jdpro" $ql_path/data/config/crontab.list)" != 0 ]; then
        error "您的任务列表中已存在拉库任务，刷新浏览器去执行拉库任务吧！"
else
    ing "开始添加6dylan6/jdpro拉库任务"
    sed -i 's/RepoFileExtensions.*/RepoFileExtensions=\"js py sh ts\"/g' $ql_path/data/config/config.sh
    if [ "$(grep -c "token" $ql_path/data/config/auth.json)" != 0 ]; then
        docker exec -it xiaoqinglong /bin/bash -c "token=\$(cat /ql/config/auth.json | jq --raw-output .token) && curl -s -H 'Accept: application/json' -H \"Authorization: Bearer \$token\" -H 'Content-Type: application/json;charset=UTF-8' -H 'Accept-Language: zh-CN,zh;q=0.9' --data-binary '{\"name\":\"拉库\",\"command\":\"ql repo https://js.dayplus.xyz/https://github.com/6dylan6/jdpro.git jd_|jx_|jddj_ backUp  ^jd[^_]|USER|JD|function|sendNotify\",\"schedule\":\"45 7-23/2  * * *\"}' --compressed 'http://127.0.0.1:5700/api/crons?t=1627380635389'"
    ok "已添加拉库任务，刷新浏览器后去执行拉库任务吧!"
    else
         error "未检测到 token，请访问web完成初始化并登陆进去后,在运行一次脚本"
    fi
fi
}

ql_fix() {
  docker exec -it xiaoqinglong /bin/bash -c "grep -lr 'cdn.jsde' /ql/dist/|xargs  sed -i  's#cdn.*.net/npm/#unpkg.com/#g'"
  docker exec -it xiaoqinglong /bin/bash -c "grep -lr 'unpkg.com' /ql/dist/ | xargs -I {} sh -c \"gzip -c {} > {}.gz\""
}

ing "开始部署青龙并创建拉库任务，速度根据您的网速决定，请耐心等待....."
read -p "按任意键开始部署。。。"
docker_install
docker_compose
ql_run
ql_fix
read -p "已初在浏览器始化并登陆青龙了?，那就按任意键继续！"
add_repo
sleep 2
ok "已部署完成，2.13.4版本青龙，部署路径为/root/ql，容器名xiaoqinglong，访问地址http://ip:5600"

