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

# 主机名前缀
hostname_prefix=`hostname |awk -F "." '{print $1}'`

#安装zabbix
zabbix_install() {
wget https://repo.zabbix.com/zabbix/3.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_3.4-1+bionic_all.deb
dpkg -i zabbix-release_3.4-1+bionic_all.deb
apt update
apt install zabbix-agent -y
cd /etc/zabbix/
if [  ! -f zabbix_agentd.conf.bak ];then
sudo cp zabbix_agentd.conf zabbix_agentd.conf.bak
fi
#cp /nfs/yunwei/zabbix/zabbix_agentd.conf zabbix_agentd.conf
zabbix_cluster_view="
	1) Linux dubai.aliyun\n
	2) Linux hongkong.aliyun \n
	3) Linux jakarta.aliyun \n
	4) Linux frankfurt.aws \n
	5) Linux saopaulo.aws \n
	6) Linux tokyo.aws \n
	7) Linux hochiminh.cmi \n
	8) Linux bangkok.huawei \n
	9) Linux hongkong.huawei \n
	10) Linux hanoi.vinahost \n
	11) Linux hochiminh.vnpt \n
	12) Linux frankfurt.zenlayer \n
	13) Linux hongkong.zenlayer \n
	14) Linux mumbai.zenlayer \n
	15) Linux saopaulo.zenlayer \n
	16) Linux shenzhen.aliyun \n
	17) Linux virginia.aws \n
	18) Linux mexico.huawei \n
	19) Linux singapore.huawei \n
	20) Linux hanoi.vinahost \n
	21) Linux singapore.aws \n
	22) Linux miami.zenlayer \n
	23) Linux moscow.zenlayer \n
	24) Linux taiwan.zenlayer \n
	25) Linux mumbai.aliyun \n
	26) Linux frankfurt.aliyun \n
"
zabbix_cluster_list=("" "Linux dubai.aliyun" "Linux hongkong.aliyun" "Linux jakarta.aliyun" "Linux frankfurt.aws" "Linux saopaulo.aws" "Linux tokyo.aws" "Linux hochiminh.cmi" "Linux bangkok.huawei" "Linux hongkong.huawei" "Linux hanoi.vinahost" "Linux hochiminh.vnpt" "Linux frankfurt.zenlayer" "Linux hongkong.zenlayer" "Linux mumbai.zenlayer" "Linux saopaulo.zenlayer" "Linux shenzhen.aliyun" "Linux virginia.aws" "Linux mexico.huawei" "Linux singapore.huawei" "Linux hanoi.vinahost" "Linux singapore.aws" "Linux miami.zenlayer" "Linux moscow.zenlayer" "Linux taiwan.zenlayer" "Linux mumbai.aliyun" "Linux frankfurt.aliyun")
echo_green $zabbix_cluster_view
read -p "请输入zabbix本集群对应的序列号: (e.g. 7)" zabbix_cluster_index
#echo ${zabbix_cluster_list[$zabbix_cluster_index]}

sed -i "/^# HostMetadata=/s/# HostMetadata/HostMetadata/" zabbix_agentd.conf
sed -i "/^HostMetadata/s/=.*/=${zabbix_cluster_list[$zabbix_cluster_index]}/" zabbix_agentd.conf
#sed -i "N;168 a HostMetadata=${zabbix_cluster_list[$zabbix_cluster_index]}"  zabbix_agentd.conf
sed -i "/^Hostname/s/=.*/=${hostname_prefix}/" zabbix_agentd.conf
sed -i "/^Server/s/=.*/=monitor.livenono.com/" zabbix_agentd.conf
sed -i "/^# Timeout/s/# Timeout=.*/Timeout=15/" zabbix_agentd.conf
sed -i "/^# AllowRoot/s/# AllowRoot=.*/AllowRoot=1/" zabbix_agentd.conf

systemctl enable zabbix-agent.service
systemctl restart zabbix-agent.service
}


ganglia_install() {
apt install ganglia-monitor -y
cd /etc/ganglia/  && sudo mv gmond.conf gmond.conf.bak
sudo cp /nfs/yunwei/ganglia/gmond.conf gmond.conf

ganglia_cluster_view="\
	1)live.SaoPaulo.aws \n
	2)live.SaoPaulo.zenlayer \n
	3)live.frankfurt.aws \n
	4)live.frankfurt.zenlayer \n
	5)live.hanoi.vinahost \n
	6)live.hochiminh.vnpt \n
	7)live.hongkong.aliyun \n
	8)live.hongkong.huawei \n
	9)live.hongkong.zenlayer \n
	10)live.idc3d.id \n
	11)live.miami.zenlayer \n
	12)live.mumbai.aws \n
	13)live.mumbai.zenlayer \n
	14)live.singapore.aws \n
	15)live.singapore.huawei \n
	16)live.taiwan.zenlayer \n
	17)live.virginia.aws \n
	18)live.mumbai.aliyun \n
	19)live.frankfurt.aliyun \n
"
ganglia_cluster_list=("" "live.SaoPaulo.aws" "live.SaoPaulo.zenlayer" "live.frankfurt.aws" "live.frankfurt.zenlayer" "live.hanoi.vinahost" "live.hochiminh.vnpt" "live.hongkong.aliyun" "live.hongkong.huawei" "live.hongkong.zenlayer" "live.idc3d.id" "live.miami.zenlayer" "live.mumbai.aws" "live.mumbai.zenlayer" "live.singapore.aws" "live.singapore.huawei" "live.taiwan.zenlayer" "live.virginia.aws" "live.mumbai.aliyun" "live.frankfurt.aliyun")
echo_green $ganglia_cluster_view
read -p "请输入ganglia本集群对应的序列号:（e.g. 7） " ganglia_cluster_index
#echo ${ganglia_cluster_list[$ganglia_cluster_index]}

sed -i "/^  name/s/=.*/= \"${ganglia_cluster_list[$ganglia_cluster_index]}\"/" gmond.conf
sed -i "/^  location/s/=.*/= \"${ganglia_cluster_list[$ganglia_cluster_index]}\"/" gmond.conf
sed -i "s/send_metadata_interval =.*/send_metadata_interval = 60/" gmond.conf
sed -i "s/owner =.*/owner = \"ganglia\"/" gmond.conf
sed -i "s/mcast/# mcast/" gmond.conf
read -p "请输入ganglia集群的监控端服务名字全称(如：zl-mia-live1.livenono.com): " ganglia_server
sed -i "/^  host /s/=.*/= ${ganglia_server}/" gmond.conf

systemctl enable ganglia-monitor.service
systemctl restart ganglia-monitor.service
}

snmp_install(){
apt install snmpd -y
cd /etc/snmp/ && sudo mv snmpd.conf snmpd.conf-bak
cp /nfs/yunwei/snmp/snmpd.conf ./
systemctl enable snmpd.service
systemctl restart snmpd
echo "snmp...."
}

result(){
echo_yellow "zabbix/ganglia/snmp已经安装完成，修改的信息如下:"
echo_red "zabbix:"
echo_green `grep "^HostMetadata\|^Hostname\|^Server\|^Timeout\|^AllowRoot" /etc/zabbix/zabbix_agentd.conf`
echo_red "ganglia:"
echo_green `grep "^  name\|  location\|  host\|  owner " /etc/ganglia/gmond.conf`
}

start_all(){
zabbix_install
ganglia_install
snmp_install
result
}

start_all
