#!/bin/bash

echo_red() {
  echo -e "\033[1;31m$*\033[0m" | sed -e "s/^/  /"
}
echo_green() {
  echo -e "\033[32m$*\033[0m" | sed -e "s/^/  /"
}
echo_yellow() {
  echo -e "\033[33m$*\033[0m" | sed -e "s/^/  /"
}
echo_purple() {
  echo -e "\033[1;35m$*\033[0m" | sed -e "s/^/  /"
}
grep_v() {
  grep -Ev '^[[:space:]]*#|^[[:space:]]*$' $*
}


user_add() {
if  [ ! -n "$home" ] ;then
read -p "请输入你希望创建的用户的家目录(eg: home1): " home
fi
# 添加业务用户
useradd -s /bin/bash -m -d /$home/nonolive nonolive
useradd -s /bin/bash -m -d /$home/golang golang
useradd -s /bin/bash -m -d /$home/mongodb mongodb
useradd -s /bin/bash -m -d /$home/consul consul

mkdir -m 700 /$home/nonolive/.ssh && \
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCaMf1tLp85OONep6E6bJrG1ci2xoqWqr0Z41qaDRq+9RUcN3DbkjDE13UfqezESStYyNRehc5j2bWsUWUqke5Y86PQAb5n4t0ALEjRrHC+acJMJhEsL7Zydh4TRjsR3pGqnu0g8eyUMIO99mbJJ41XxD5SgreyoyGxivPQq6YcFHVRFjXNdbPwcCcnuaqCXy0oIly15zBV8r30hwsuVcTeGxfjwY0Poq4OUHWxbtzSEtWe+w3bb46PINU5i/sJ5gXGs+GA+p7veC2WQj5aitKudEeE7B54d7DXlYwbp6Nh6AdxeDvVEf8hhCzMMuFtND8m0TAdbpp9wXGg9AC5+slL aws-ap-nonolive.pem" > /$home/nonolive/.ssh/authorized_keys && \
chmod 600 /$home/nonolive/.ssh/authorized_keys && \
chown nonolive.nonolive -R /$home/nonolive/.ssh/

mkdir -m 700 /$home/golang/.ssh && \
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDf3T5bYlGc+wzfEQ2jdVj/HZfY/sDNfYW/tdXX0y90mEBNnXgCwFaqEJKgF7sOjnITq0T3khi4jvOkVT2MNEFnJE69zlDjNlvcDzDOTBj95e2UY5SA5/Sunvv/SLWWfSzB5u0X5uBTcbajo56x11+jxNgAc4bsIxA/fwW9HoZKGX6YAJ3QhweObvfb75bnqc/AX9oqNv9DvgeJXZGhlaNG4kN4V5RtsUS8lHoksdZG/di6pqaJT9vjT2sRGA/IzjuJWEoJ1KD+BTzvftR2CohGbbmDPTw0W4i6hIKEG5QiGX3GNv4JBA5w/2t/DHHWbQAJw8X3KQLywLNN/adWW3Sb aws-ap-golang.pem" > /$home/golang/.ssh/authorized_keys && \
chmod 600 /$home/golang/.ssh/authorized_keys && \
chown golang.golang -R /$home/golang/.ssh/

echo_green "nonolive/golang/mongodb/consul用户已经创建成功"
echo_green "nonolive/golang用户的公钥已经添加成功"
}

tengine_install(){
if  [ ! -n "$home" ] ;then
read -p "修改tengine配置中日志的根目录为(e.g.: home1): " home
fi
if [ ! -d "/usr/local/nginx/" ];then
cd /usr/local/ && tar xf /nfs/pkgs/tengine_v2.3_tyolive1_ubuntu18.04.tar.gz 
else
echo_yellow "/usr/local/nginx/文件夹已经存在"
fi
useradd --system --home /usr/local/nginx --shell /bin/false nginx  
mkdir -p /$home/logs/tengine && chown nginx.nginx /$home/logs/tengine 
ldconfig 
cp /nfs/yunwei/tengine/default.conf /usr/local/nginx/conf.d/ 
cp /nfs/yunwei/tengine/enable_nginx_status.params /usr/local/nginx/conf.d/ 
cp /nfs/yunwei/tengine/tengine.service /lib/systemd/system/ 
# 修改dns
sed -i "/^    resolver/s/resolver.*/resolver 127.0.0.53 ipv6=off;/" /usr/local/nginx/conf/nginx.conf
# 如果家目录是属于home,则修改tengine日志的home路径
if [ $home == "home" ];then
	sed -i "s/home1/home/" /usr/local/nginx/conf/nginx.conf
	sed -i "s/home1/home/" /usr/local/nginx/conf.d/default.conf
elif [ $home == "home1" ];then
	sed -i "s/home1/home1/" /usr/local/nginx/conf/nginx.conf
	sed -i "s/home1/home1/" /usr/local/nginx/conf.d/default.conf
fi
mkdir -p /home/tengine/cache && sudo chown nginx. /home/tengine/cache 
mkdir -p /dev/shm/tengine/cache && sudo chown nginx. /dev/shm/tengine/cache 
cd /usr/local/nginx/sbin && ./nginx -m
systemctl daemon-reload
systemctl enable tengine.service
systemctl start tengine.service
systemctl status tengine.service
echo_green "Tengine已经启动..."
## 添加rc.local
sed -i '/exit 0/d' /etc/rc.local
echo "
# for srs hls
mkdir -p /dev/shm/hls && chown nonolive.nonolive /dev/shm/hls

# for nginx
sleep 10
mkdir -p /dev/shm/tengine/cache && chown nginx.root /dev/shm/tengine/cache && systemctl restart tengine
exit 0 
" >> /etc/rc.local
}

speedtest_install(){
#php7.2 config 
apt install -y apache2 php libapache2-mod-php
cd /etc/php/7.2/apache2/ && sudo mv php.ini{,.bak}
cp /nfs/yunwei/apache2/php.ini /etc/php/7.2/apache2/


#apache2 config 
cd /etc/apache2/  && sudo mv apache2.conf{,.bak}
cp /nfs/yunwei/apache2/apache2.conf /etc/apache2/
cd /etc/apache2/sites-enabled/ && sudo mv 000-default.conf{,.bak}
cp /nfs/yunwei/apache2/speedtest.conf /etc/apache2/sites-enabled/
sed -i "/^Listen 80$/s/80/8080/" /etc/apache2/ports.conf
sed -i "10s/ServerName.*/ServerName $hostname/" /etc/apache2/sites-enabled/speedtest.conf
sed -i "18s/ServerName.*/ServerName $speedtest_hostname/" /etc/apache2/sites-enabled/speedtest.conf
cd /var/www/ && tar xf /nfs/yunwei/speedtest.tar.gz
/lib/systemd/systemd-sysv-install enable apache2
systemctl restart  apache2.service

#nginx config
cd /usr/local/nginx/conf.d/
cp /nfs/yunwei/tengine/virtual_speedtest.conf .
cp /nfs/yunwei/tengine/proxy_pass_keepalive.params .
cp /nfs/yunwei/tengine/enable_gzip.params .
sed -i "s/server_name.*/server_name $speedtest_hostname;/" /usr/local/nginx/conf.d/virtual_speedtest.conf
/usr/local/nginx/sbin/nginx -t && /usr/local/nginx/sbin/nginx -s reload
echo_green "Speedtest已经启动..."
echo_green "请打开浏览器测试...."
}

filebeat_install(){
dpkg -l | grep filebeat
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list
sudo apt update && sudo apt install filebeat
cp /nfs/yunwei/elk/filebeat.yml /etc/filebeat/filebeat.yml
systemctl enable filebeat
systemctl start filebeat
systemctl status filebeat
}


hostname=`hostname`
speedtest_hostname_prefix=`hostname |awk -F "-live" '{print $1}'`
#speedtest_hostname_prefix=`hostname |awk -F "-live" '{print $1}'| awk -F "-" '{print $2}'`
speedtest_hostname="${speedtest_hostname_prefix}.speedtest.nonolive.com"
#$1

if [[ $1 == "--help" || $1 == "" ]];then
echo_green  "\
Usage: ./initial-service.sh [OPTION]
OPTION as below:
  user_add   		-添加业务账号
  tengine_install 	-安装tengine服务
  speedtest_install	-安装speedtest工具
  filebeat_install	-安装filebeat插件"
else 
$1
fi

