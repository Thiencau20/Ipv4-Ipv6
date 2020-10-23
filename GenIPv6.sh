random() {
	tr </dev/urandom -dc A-Za-z0-9 | head -c5
	echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
gen64() {
	ip64() {
		echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
	}
	echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

gen_3proxy() {
    cat <<EOF
nserver 8.8.8.8
nserver 8.8.4.4
maxconn 1000
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
#setgid 65535
#setuid 65535


authcache user 60
auth strong cache

daemon

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})
$(awk -F "/" '{print "auth none\n" \
"#allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

upload_proxy() {
    local PASS=$(random)
    zip --password $PASS proxy.zip proxy.txt
    URL=$(curl --upload-file proxy.zip https://free.keep.sh)

    echo "Proxy is ready! Format IP:PORT:LOGIN:PASS"
    echo "Download zip archive from: ${URL}"
    echo "Password: ${PASS}"

}
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "usr$(random)/pass$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}

echo "Install 3Proxy"
sudo yum -y install nano && yum -y install wget && yum -y install gcc make && yum -y install net-tools && yum -y install zip && yum -y install unzip
yum -y install epel-release && yum -y install 3proxy

echo "Move 3Proxy v0.8.13"
wget - O  'https://github.com/Thiencau20/Ipv4-Ipv6/raw/main/3proxy.tar.gz'
tar -xvf 3proxy.tar.gz
rm -rf 3proxy.tar.gz
sudo chmod +x 3proxy
cp 3proxy /usr/bin/

echo "Generating IPv6"

echo "working folder = /home/proxy-installer"
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"

echo "How many proxy do you want to create? Example 500"
read COUNT

FIRST_PORT=10000
LAST_PORT=$(($FIRST_PORT + $COUNT))

gen_data >$WORKDIR/data.txt
gen_ifconfig >$WORKDIR/boot_ifconfig.sh

gen_3proxy >/etc/3proxy.cfg

bash ${WORKDIR}/boot_ifconfig.sh

gen_proxy_file_for_user

upload_proxy

echo "Set Firewall"

firewall-cmd --zone=public --add-port=10000-$LAST_PORT/tcp --permanent
firewall-cmd --reload

systemctl stop 3proxy
systemctl start 3proxy
service 3proxy status


























