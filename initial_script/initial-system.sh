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


# step1: check distro. #####
if ! which lsb_release > /dev/null; then
  echo "ERROR: lsb_release not found in \$PATH" >&2
  exit 1;
fi
distro_codename=$(lsb_release --codename --short)
distro_id=$(lsb_release --id --short)
#supported_codenames="(trusty|xenial|bionic|disco)"
supported_codenames="(bionic)"
supported_ids="(Ubuntu|Debian)"
if [[ ! $distro_codename =~ $supported_codenames &&
      ! $distro_id =~ $supported_ids ]]; then
  echo -e "ERROR: The only supported distros are\n" \
    "\tUbuntu 18.04 LTS \n"
  exit 1
fi


# step2: check if the excute user is root. #####
if [ "x$(id -u)" != x0 ]; then
  echo_red "Running as non-root user."
  echo_red "You might have to enter your password one or more times for 'sudo'."
  exit 1
fi


# step3: apt install pkgs. #####
apt update && apt -y upgrade

pkgs_list="\
  lrzsz
  tmpreaper
  numactl
  redis-tools
  unzip
  libtool
  zlib1g-dev
  python2.7
  python-dev
  python-setuptools
  python-pip
  python3-pip
  build-essential
  nfs-common
  nfs-kernel-server
  mongodb-server-core
  mongodb-clients
  sysstat
  iotop
  fping
  traceroute
  tzdata
  locales
  debconf
  rsync
  dmidecode
"

packages="$(
  echo "${pkgs_list}" | \
       tr " " "\n" | \
       sort -u | sort -r -s -t: -k2 | tr "\n" " "
)"

if ! missing_packages="$(dpkg-query -W -f ' ' ${packages} 2>&1)"; then
  missing_packages="$(echo "${missing_packages}" | awk '{print $NF}')"
  not_installed=""
  unknown=""
  for p in ${missing_packages}; do
    if apt-cache show ${p} > /dev/null 2>&1; then
      not_installed="${p}\n${not_installed}"
    else
      unknown="${p}\n${unknown}"
    fi
  done
  if [ -n "${not_installed}" ]; then
    echo "WARNING: The following packages are not installed:"
    echo_yellow "${not_installed}"
  fi
  if [ -n "${unknown}" ]; then
    echo "WARNING: The following packages are unknown to your system"
    echo "(maybe missing a repo or need to 'sudo apt-get update'):"
    echo_red "${unknown}"
    exit 1
  fi
fi

query_cmd="apt-get --just-print install $(echo $packages)"
if cmd_output="$(LANGUAGE=en LANG=C $query_cmd 2>&1)"; then
  new_list=$(echo "$cmd_output" |
    sed -e '1,/The following NEW packages will be installed:/d;s/^  //;t;d' |
    sed 's/ *$//')
  upgrade_list=$(echo "$cmd_output" |
    sed -e '1,/The following packages will be upgraded:/d;s/^  //;t;d' |
    sed 's/ *$//')
  if [ -z "$new_list" ] && [ -z "$upgrade_list" ]; then
    echo_green "No missing packages, and the packages are up to date."
  else
    echo "Installing and upgrading packages: "
    echo_yellow "$new_list $upgrade_list"
    apt install -y ${new_list} ${upgrade_list}
    apt remove -y nano
  fi
  echo
fi

dpkg-reconfigure dash


# step4: 设置主机名. #####
read -p "请输入本机的主机名前缀(eg: sg-live1): " hostname_pre
hostname="$hostname_pre"".livenono.com"
hostnamectl set-hostname $hostname
echo "当前的主机名: "
echo_green "$(hostname)"


# step5: 修改系统语言LANG. #####
choosed_lang="en_US.UTF-8"
[ ! "$choosed_lang" = "$LANG" ] && dpkg-reconfigure locales
echo "当前系统语音: "
echo_green "$LANG"


# step6: 设置时区. #####
timedatectl set-timezone Asia/Shanghai
echo "当前的时区信息: "
echo_green "$(timedatectl status | sed -n "s/^.*Time zone/Time zone/p")"


# step7: 开启sysstat, 采集间隔由10分钟改为5分钟. #####
[ ! -f "/etc/default/sysstat.bak" ] && cp /etc/default/sysstat{,.bak}
#[ ! -f "/etc/cron.d/sysstat.bak" ] && cp /etc/cron.d/sysstat{,.bak}
[ -f "/etc/cron.d/sysstat.bak" ] && rm -rf /etc/cron.d/sysstat.bak
sed -i '/^ENABLED/s/false/true/' /etc/default/sysstat
sed -i '/^5-55\/10/s/^5-55\/10\(.*\)/#&\n\*\/5\1/' /etc/cron.d/sysstat
echo "当前/etc/default/sysstat: "
echo_green "$(grep_v /etc/default/sysstat)"
echo "当前/etc/cron.d/sysstat: "
echo_green "$(grep_v /etc/cron.d/sysstat)"


# step8: 修改/etc/security/limits.conf, 将open files值改为131072. #####
[ ! -f "/etc/security/limits.conf.bak" ] && cp /etc/security/limits.conf{,.bak}
limits_conf_content=$(grep_v /etc/security/limits.conf)
if ! limits_conf_nofile=$(echo "$limits_conf_content" | grep "\<nofile\>");then
  sed -i '/^# End of file/i\* - nofile 131072' /etc/security/limits.conf
  sed -i '/^# End of file/iroot - nofile 131072' /etc/security/limits.conf
fi
echo  "当前的/etc/security/limits.conf: "
echo_green "$(grep_v /etc/security/limits.conf)"


# step9: 修改/etc/sysctl.conf. #####
sysctl_conf=$(cat <<-EOF
#add by ligb on 20160429 for wuhc app monitor
net.ipv4.tcp_keepalive_time = 180
#net.ipv4.tcp_keepalive_probes = 9
#net.ipv4.tcp_keepalive_intvl = 75
  
net.ipv4.tcp_rmem = 16384 262144  8388608
net.ipv4.tcp_wmem = 16384 262144  8388608
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 8388608
net.core.wmem_max = 8388608
#net.ipv4.tcp_timestamps = 1
  
net.core.netdev_max_backlog = 10000
net.ipv4.tcp_max_syn_backlog = 8192
net.core.somaxconn = 2048
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.neigh.default.unres_qlen = 31
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
)
[ ! -f "/etc/sysctl.conf.bak" ] && cp /etc/sysctl.conf{,.bak}
sysctl_conf_path="/etc/sysctl.conf"
echo "$sysctl_conf" | while read line
do
  if [ -n "$(echo "$line" | sed 's/#//g' | sed 's/[[:space:]]//g')" ];then
    field1=$(echo "$line" | awk -F"=" '{print $1}' | sed 's/#//g' | sed 's/^[[:space:]]*//g' | sed 's/[[:space:]]*$//g')
    if cmd_output=$(grep -n "$field1" "$sysctl_conf_path");then
      line_num=$(echo "$cmd_output" |
        awk -F":" '{print $1}' |
        sed 's/[[:space:]]//g' |
        tail -n 1)
      sed -i "$line_num s/.*/$line/" "$sysctl_conf_path"
    else
      echo "$line" >> "$sysctl_conf_path"
    fi
  fi
done
echo "当前的/etc/sysctl.conf: "
echo_green "$(sysctl -p)"


# step10: 修改/etc/systemd/logind.conf. #####
sed -i '/RemoveIPC/s/.*/RemoveIPC=no/' /etc/systemd/logind.conf
systemctl restart systemd-logind.service
echo "当前的/etc/systemd/logind.conf: "
echo_green "$(grep_v /etc/systemd/logind.conf)"


# step11: 创建/etc/rc.local文件. #####
if [ ! -f "/etc/rc.local" ];then
  printf '%s\n' '#!/bin/bash' 'exit 0' > /etc/rc.local
  sudo chmod +x /etc/rc.local
fi


# step12: 修改/etc/ssh/sshd_config. #####
[ ! -f "/etc/ssh/sshd_config.bak" ] && cp /etc/ssh/sshd_config{,.bak}
sed -i '/^GSSAPI/s/^/#/' /etc/ssh/sshd_config
sed -i '/^MaxAuthTries/s/^/#/' /etc/ssh/sshd_config
sed -i '/PasswordAuthentication yes/s/.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i '/UseDNS yes/s/.*/UseDNS no/' /etc/ssh/sshd_config
[ ! -d "/root/.ssh" ] && mkdir -m 700 /root/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDiiiQenSmD0U9XUzwVkvgJRa0IkesTViSzpB3zCrQWUoscXFFc7O9Ja+q9PYR53wtGpAb1lOs1jMDVAX44E/HT2mNaGln/zRrCyXaOqGPi0Pd7auJZS3yzfF+X5cCQFcR7hfTc4CjP6B1PxD9WLLMKJwWEBJThBkeIehC+XRUB5JLf4AW4LEPp+ElIpr+NWZEGG6xWzQ3yWk9O+D8tVddmD7A3/XyFfdxI9XOeM09mCgBhwImABhgYSWBnco3sPfOGhirZnCunWQVegWXz51k5u/Okaz5LVRSDRLpnBFIeeINHpQ9TIIL7kIR7kBlZnOcyVV/i4Ar2KG6n4AMDFIt5 aws-ap-root.pem" >/root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
systemctl restart sshd.service
echo "当前的/etc/ssh/sshd_config: "
echo_green "$(grep_v /etc/ssh/sshd_config)"

# step13: 修改/etc/resolv.conf. #####
mechine_vendor=$(dmidecode -s bios-vendor)
supported_vendor="(Amazon EC2)"
cron_resolv_path="/etc/cron.d/resolv"
[ ! -f "/etc/resolv.conf.bak" ] && cp /etc/resolv.conf{,.bak}
if [[ $mechine_vendor =~ $supported_vendor ]];then
  ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
cat > /opt/update_resolv_conf.sh <<-EOF
#!/bin/bash
printf '%s\n' 'options timeout:2 attempts:1' | sudo tee -a /etc/resolv.conf
EOF
  chmod 755 /opt/update_resolv_conf.sh
  echo '@reboot root /opt/update_resolv_conf.sh' > $cron_resolv_path
else
  [ -L "/etc/resolv.conf" ] && \
  rm -rf /etc/resolv.conf
  cp /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf && \
  echo "options timeout:2 attempts:1" >> /etc/resolv.conf
fi
echo "当前的/etc/resolv.conf: "
echo_green "$(ls -l /etc/resolv.conf)"
echo_green "$(grep_v /etc/resolv.conf)"


# step14: 修改/etc/sudoers.d/nonolive. #####
[ ! -f "/etc/sudoers.d/nonolive" ] && \
echo 'nonolive ALL=(ALL) NOPASSWD: /bin/su, !/bin/su -, !/bin/su - root, /usr/sbin/tcpdump' > /etc/sudoers.d/nonolive && \
chmod 400 /etc/sudoers.d/nonolive


# 将/home/nfs共享给本集群的机器. #####
#nfs_dir="/home/nfs"
#ip_net="$(ip address show |grep "\<inet\>" |awk '{print $2}' |grep -vE "^127\." |grep -E "^10\.|^172\.|^192\.")"
#if [ -f "/etc/exports" ] && [ "$(cat /etc/exports | wc -l)" -eq 0 ];then
#  echo "$nfs_dir" "$ip_net"'(rw,no_root_squash)'
#fi

echo 
echo "提示: "
echo_purple "1.请格式化另一块磁盘，并挂载分区."
echo_purple "2.请添加hostname到/etc/hosts."
echo_purple "3.请修改dns解析."
echo_purple "4.请设置nfs."

