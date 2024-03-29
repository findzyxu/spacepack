#!/usr/bin/env bash
#
# Author:       Seaton Jiang <seaton@vtrois.com>
# Github URL:   https://github.com/vtrois/spacepack
# License:      MIT
# Date:         2020-08-13

export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin

RGB_DANGER='\033[31;1m'
RGB_WAIT='\033[37;2m'
RGB_SUCCESS='\033[32m'
RGB_WARNING='\033[33;1m'
RGB_INFO='\033[36;1m'
RGB_END='\033[0m'

CHECK_CENTOS=$( cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/' )
CHECK_RAM=$( cat /proc/meminfo | grep "MemTotal" | awk -F" " '{ram=$2/1000000}{printf("%.0f",ram)}' )

LOCK=/var/log/spacepack_init_centos.log

tool_info() {
    echo -e "========================================================================================="
    echo -e "                              Init CentOS 8 for SpacePack                                "
    echo -e "          For more information please visit https://github.com/vtrois/spacepack          "
    echo -e "========================================================================================="
}

check_root(){
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RGB_DANGER}This script must be run as root!${RGB_END}"
        exit 1
    fi
}

check_lock() {
    if [ ! -f "$LOCK" ];then
        touch $LOCK
    else
        echo -e "${RGB_DANGER}Detects that the initialization is complete and does not need to be initialized any further!${RGB_END}"
        exit 1
    fi
}

check_os() {
    if [ "${CHECK_CENTOS}" != '8' ]; then
        echo -e "${RGB_DANGER}This script must be run in CentOS 8!${RGB_END}"
        exit 1
    fi
}

new_swap() {
    echo "============= swap =============" >> ${LOCK} 2>&1
    if [ "${CHECK_RAM}" -le '2' ]; then
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    dd if=/dev/zero of=/swapfile bs=1024 count=1048576 >> ${LOCK} 2>&1
    chmod 600 /swapfile >> ${LOCK} 2>&1
    mkswap /swapfile >> ${LOCK} 2>&1
    swapon /swapfile >> ${LOCK} 2>&1
    echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
    echo '# Swap' >> /etc/sysctl.conf
    echo 'vm.swappiness = 10' >> /etc/sysctl.conf
    sysctl -p >> ${LOCK} 2>&1
    sysctl -n vm.swappiness >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
    else
    echo -e "${RGB_SUCCESS}Skip, no configuration needed${RGB_END}"
    fi
}

open_bbr() {
    echo "============= bbr =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    echo "# BBR" >> /etc/sysctl.conf
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p >> ${LOCK} 2>&1
    sysctl -n net.ipv4.tcp_congestion_control >> ${LOCK} 2>&1
    lsmod | grep bbr >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

disable_software() {
    echo "============= selinux cockpit firewalld =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    setenforce 0 >> ${LOCK} 2>&1
    sed -i 's/^SELINUX=.*$/SELINUX=disabled/' /etc/selinux/config
    systemctl disable firewalld.service >> ${LOCK} 2>&1
	systemctl stop firewalld.service >> ${LOCK} 2>&1
    dnf remove cockpit -y >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

time_zone() {
    echo "============= time zone =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    rm -rf /etc/localtime >> ${LOCK} 2>&1
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime >> ${LOCK} 2>&1
    ls -ln /etc/localtime >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

custom_profile() {
    echo "============= custom profile =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    cat > /etc/profile.d/spacepack.sh << EOF
PS1="\[\e[37;40m\][\[\e[32;40m\]\u\[\e[37;40m\]@\h \[\e[35;40m\]\W\[\e[0m\]]\\\\$ "
GREP_OPTIONS="--color=auto"
alias l='ls -AFhlt'
alias grep='grep --color'
alias egrep='egrep --color'
alias fgrep='fgrep --color'
EOF
    cat /etc/profile.d/spacepack.sh >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

adjust_ulimit() {
    echo "============= adjust ulimit =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    sed -i '/^# End of file/,$d' /etc/security/limits.conf
    cat >> /etc/security/limits.conf <<EOF
# End of file
* soft core unlimited
* hard core unlimited
* soft nproc 1000000
* hard nproc 1000000
* soft nofile 1000000
* hard nofile 1000000
root soft core unlimited
root hard core unlimited
root soft nproc 1000000
root hard nproc 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF
    cat /etc/security/limits.conf >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

kernel_optimum() {
    echo "============= kernel optimum =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    [ ! -e "/etc/sysctl.conf_bak" ] && /bin/mv /etc/sysctl.conf{,_bak}
    cat > /etc/sysctl.conf << EOF
# Controls source route verification
net.ipv4.conf.default.rp_filter = 1
net.ipv4.ip_nonlocal_bind = 1
net.ipv4.ip_forward = 0

net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.promote_secondaries = 1
net.ipv4.conf.default.promote_secondaries = 1

# Controls the use of TCP syncookies
# Number of pid_max
kernel.core_uses_pid = 1
kernel.pid_max = 1000000
net.ipv4.tcp_syncookies = 1

# Controls the maximum size of a message, in bytes
# Controls the default maxmimum size of a mesage queue
# Controls the maximum shared segment size, in bytes
# Controls the maximum number of shared memory segments, in pages
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
kernel.sysrq = 1
kernel.softlockup_panic = 1
kernel.printk = 5

# TCP kernel paramater
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_rmem = 4096 87380 4194304
net.ipv4.tcp_wmem = 4096 16384 4194304
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_sack = 1

# Socket buffer
net.core.wmem_default = 8388608
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 32768
net.core.somaxconn = 65535
net.core.optmem_max = 81920

# TCP conn
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_retries1 = 3
net.ipv4.tcp_retries2 = 15

# TCP conn reuse
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 5
net.ipv4.tcp_max_tw_buckets = 7000
net.ipv4.tcp_max_orphans = 3276800
net.ipv4.tcp_synack_retries = 1

# keepalive conn
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.ip_local_port_range = 1024 65535

net.ipv6.neigh.default.gc_thresh3 = 4096
net.ipv4.neigh.default.gc_thresh3 = 4096
EOF
    sysctl -p >> ${LOCK} 2>&1
    cat /etc/sysctl.conf >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

clean_dnf() {
    echo "============= clean dnf =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    dnf autoremove -y >> ${LOCK} 2>&1
    dnf clean all -y >> ${LOCK} 2>&1
    dnf remove $(rpm -qa | grep kernel | grep -v $(uname -r)) -y >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

upgrade_dnf() {
    echo "============= upgrade dnf =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Could be a long time${RGB_END}"
    dnf update -y >> ${LOCK} 2>&1
    dnf upgrade -y >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

updatedb_optimum() {
    echo "============= updatedb optimum =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    sed -i 's,media,media /data,' /etc/updatedb.conf
    cat /etc/updatedb.conf >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

open_ipv6() {
    echo "============= open ipv6 =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    echo '# IPV6' >> /etc/sysctl.conf
    echo 'net.ipv6.conf.all.disable_ipv6=0' >> /etc/sysctl.conf
    echo 'net.ipv6.conf.default.disable_ipv6=0' >> /etc/sysctl.conf
    echo 'net.ipv6.conf.lo.disable_ipv6=0' >> /etc/sysctl.conf
    sysctl -p >> ${LOCK} 2>&1
    cat /etc/sysctl.conf >> ${LOCK} 2>&1
    echo 'DHCPV6C=yes' >> /etc/sysconfig/network-scripts/ifcfg-eth0
    echo 'IPV6INIT=yes' >> /etc/sysconfig/network-scripts/ifcfg-eth0
    systemctl restart NetworkManager.service >> ${LOCK} 2>&1
    dhclient >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

disable_cad() {
    echo "============= disable cad =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    systemctl mask ctrl-alt-del.target >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

remove_users() {
    echo "============= remove users =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    for u in adm lp sync shutdown halt mail operator games ftp cockpit-ws cockpit-wsinstance
    do
    userdel ${u} >> ${LOCK} 2>&1
    done
    cut -d : -f 1 /etc/passwd >> ${LOCK} 2>&1
    for g in adm lp mail games ftp cockpit-ws cockpit-wsinstance
    do
    groupdel ${g} >> ${LOCK} 2>&1
    done
    cat /etc/group >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

sys_permissions() {
    echo "============= sys permissions =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    chmod 644 /etc/passwd >> ${LOCK} 2>&1
    chmod 644 /etc/group >> ${LOCK} 2>&1
    chmod 000 /etc/shadow >> ${LOCK} 2>&1
    chmod 000 /etc/gshadow >> ${LOCK} 2>&1
    ls -la /etc/passwd >> ${LOCK} 2>&1
    ls -la /etc/group >> ${LOCK} 2>&1
    ls -la /etc/shadow >> ${LOCK} 2>&1
    ls -la /etc/gshadow >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

password_policy() {
    echo "============= password policy =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    sed -i 's/^PASS_MAX_DAYS.*$/PASS_MAX_DAYS   90/' /etc/login.defs
    cat /etc/login.defs >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

change_useradd() {
    echo "============= change useradd =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    sed -i 's/^INACTIVE.*$/INACTIVE=365/' /etc/default/useradd
    cat /etc/default/useradd >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

sec_ssh() {
    echo "============= sec ssh =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    sed -i 's/UseDNS.*$/UseDNS no/' /etc/ssh/sshd_config
    sed -i 's/^#LoginGraceTime.*$/LoginGraceTime 60/' /etc/ssh/sshd_config
    sed -i 's/^#PermitEmptyPasswords.*$/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    sed -i 's/^#PubkeyAuthentication.*$/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#MaxAuthTries.*$/MaxAuthTries 3/' /etc/ssh/sshd_config
    systemctl restart sshd.service >> ${LOCK} 2>&1
    cat /etc/ssh/sshd_config >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

timeout_config() {
    echo "============= timeout config =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    echo "export TMOUT=1800" >> /etc/profile.d/spacepack.sh
    cat /etc/profile.d/spacepack.sh >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

lockout_policy() {
    echo "============= lockout policy =============" >> ${LOCK} 2>&1
    echo -en "${RGB_WAIT}Configuring...${RGB_END}"
    [ ! -e "/etc/pam.d/system-auth_bak" ] && /bin/mv /etc/pam.d/system-auth{,_bak}
    cat > /etc/pam.d/system-auth << EOF
auth        required                                     pam_env.so
auth        required                                     pam_faillock.so preauth silent audit deny=3 unlock_time=300
auth        required                                     pam_faildelay.so delay=2000000
auth        [default=1 ignore=ignore success=ok]         pam_succeed_if.so uid >= 1000 quiet
auth        [default=1 ignore=ignore success=ok]         pam_localuser.so
auth        sufficient                                   pam_unix.so nullok try_first_pass
auth        [default=die]                                pam_faillock.so  authfail  audit  deny=3  unlock_time=300
auth        requisite                                    pam_succeed_if.so uid >= 1000 quiet_success
auth        sufficient                                   pam_sss.so forward_pass
auth        required                                     pam_deny.so

account     required                                     pam_unix.so
account     sufficient                                   pam_localuser.so
account     sufficient                                   pam_succeed_if.so uid < 1000 quiet
account     [default=bad success=ok user_unknown=ignore] pam_sss.so
account     required                                     pam_permit.so
account     required                                     pam_faillock.so

password    requisite                                    pam_pwquality.so try_first_pass local_users_only
password    sufficient                                   pam_unix.so sha512 shadow nullok try_first_pass use_authtok
password    sufficient                                   pam_sss.so use_authtok
password    required                                     pam_deny.so

session     optional                                     pam_keyinit.so revoke
session     required                                     pam_limits.so
-session    optional                                     pam_systemd.so
session     [success=1 default=ignore]                   pam_succeed_if.so service in crond quiet use_uid
session     required                                     pam_unix.so
session     optional                                     pam_sss.so
EOF
    [ ! -e "/etc/pam.d/password-auth_bak" ] && /bin/mv /etc/pam.d/password-auth{,_bak}
    cat > /etc/pam.d/password-auth << EOF
auth        required                                     pam_env.so
auth        required                                     pam_faillock.so preauth silent audit deny=3 unlock_time=300
auth        required                                     pam_faildelay.so delay=2000000
auth        [default=1 ignore=ignore success=ok]         pam_succeed_if.so uid >= 1000 quiet
auth        [default=1 ignore=ignore success=ok]         pam_localuser.so
auth        sufficient                                   pam_unix.so nullok try_first_pass
auth        [default=die]                                pam_faillock.so  authfail  audit  deny=3  unlock_time=300
auth        requisite                                    pam_succeed_if.so uid >= 1000 quiet_success
auth        sufficient                                   pam_sss.so forward_pass
auth        required                                     pam_deny.so

account     required                                     pam_unix.so
account     sufficient                                   pam_localuser.so
account     sufficient                                   pam_succeed_if.so uid < 1000 quiet
account     [default=bad success=ok user_unknown=ignore] pam_sss.so
account     required                                     pam_permit.so
account     required                                     pam_faillock.so

password    requisite                                    pam_pwquality.so try_first_pass local_users_only
password    sufficient                                   pam_unix.so sha512 shadow nullok try_first_pass use_authtok
password    sufficient                                   pam_sss.so use_authtok
password    required                                     pam_deny.so

session     optional                                     pam_keyinit.so revoke
session     required                                     pam_limits.so
-session    optional                                     pam_systemd.so
session     [success=1 default=ignore]                   pam_succeed_if.so service in crond quiet use_uid
session     required                                     pam_unix.so
session     optional                                     pam_sss.so
EOF
    systemctl restart sshd.service >> ${LOCK} 2>&1
    cat /etc/pam.d/etc/pam.d/system-auth >> ${LOCK} 2>&1
    cat /etc/pam.d/password-auth >> ${LOCK} 2>&1
    echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
}

qcloud_hostname() {
    TENCENTCLOUD=$( wget -qO- -t1 -T2 metadata.tencentyun.com )
    if [ ! -z "${TENCENTCLOUD}" ]; then
        OLDNAME=$( hostname )
        INSTANCEID=$( wget -qO- -t1 -T2 metadata.tencentyun.com/latest/meta-data/instance-id )
        INSTANCENAME=$( wget -qO- -t1 -T2 metadata.tencentyun.com/latest/meta-data/instance-name )
        CHECK_CN=$( echo ${INSTANCENAME} |awk '{print gensub(/[!-~]/,"","g",$0)}' )
        if [ ${CHECK_CN} ]; then
        NEWNAME=${INSTANCEID}
        else
        NEWNAME=${INSTANCENAME}
        fi
        echo "============= qcloud hostname =============" >> ${LOCK} 2>&1
        echo -en "${RGB_WAIT}Configuring...${RGB_END}"
        hostnamectl set-hostname ${NEWNAME}
        sed -i "s/${OLDNAME}/${NEWNAME}/g" /etc/hosts
        sed -i '/update_hostname/d' /etc/cloud/cloud.cfg
        cat /etc/hostname >> ${LOCK} 2>&1
        cat /etc/hosts >> ${LOCK} 2>&1
        echo -e "\r${RGB_SUCCESS}Configuration Success${RGB_END}"
    else
        echo -e "${RGB_SUCCESS}Skip, detected not Tencent Cloud CVM${RGB_END}"
    fi
}

reboot_os() {
    echo -e "\n${RGB_WARNING}Please restart the server and see if the services start up fine.${RGB_END}"
    echo -en "${RGB_WARNING}Do you want to restart OS ? [y/n]: ${RGB_END}"
    while :; do
        read REBOOT_STATUS
        if [[ ! "${REBOOT_STATUS}" =~ ^[y,n]$ ]]; then
            echo -en "${RGB_DANGER}Input error, please only input 'y' or 'n': ${RGB_END}"
        else
            break
        fi
    done
    [ "${REBOOT_STATUS}" == 'y' ] && reboot
}

main() {
    echo -e "\n${RGB_INFO}1/20 : Upgrade packages and kernel${RGB_END}"
    upgrade_dnf

    echo -e "\n${RGB_INFO}2/20 : Customize the profile (color and alias)${RGB_END}"
    custom_profile

    echo -e "\n${RGB_INFO}3/20 : Time zone adjustment${RGB_END}"
    time_zone

    echo -e "\n${RGB_INFO}4/20 : Disable selinux, cockpit and firewalld${RGB_END}"
    disable_software

    echo -e "\n${RGB_INFO}5/20 : Disable Ctrl+Alt+Del${RGB_END}"
    disable_cad

    echo -e "\n${RGB_INFO}6/20 : Kernel parameter optimization${RGB_END}"
    kernel_optimum

    echo -e "\n${RGB_INFO}7/20 : The updatedb optimization${RGB_END}"
    updatedb_optimum

    echo -e "\n${RGB_INFO}8/20 : Adding swap space${RGB_END}"
    new_swap

    echo -e "\n${RGB_INFO}9/20 : Adjustment of ulimit${RGB_END}"
    adjust_ulimit
    
    echo -e "\n${RGB_INFO}10/20 : Enable tcp bbr congestion control algorithm${RGB_END}"
    open_bbr

    echo -e "\n${RGB_INFO}11/20 : Enable IPV6${RGB_END}"
    open_ipv6

    echo -e "\n${RGB_INFO}12/20 : Remove unnecessary users and user groups from the system${RGB_END}"
    remove_users

    echo -e "\n${RGB_INFO}13/20 : System permissions for sensitive files${RGB_END}"
    sys_permissions

    echo -e "\n${RGB_INFO}14/20 : Modify Account Password Survival Policy${RGB_END}"
    password_policy

    echo -e "\n${RGB_INFO}15/20 : Maximum number of days an account is valid after password expiration strategy${RGB_END}"
    change_useradd

    echo -e "\n${RGB_INFO}16/20 : Secure configuration of SSH${RGB_END}"
    sec_ssh

    echo -e "\n${RGB_INFO}17/20 : Timeout Auto-Logout Configuration${RGB_END}"
    timeout_config

    echo -e "\n${RGB_INFO}18/20 : Configure account login failure lockout policy${RGB_END}"
    lockout_policy

    echo -e "\n${RGB_INFO}19/20 : Clean up dnf isolated packages and garbage${RGB_END}"
    clean_dnf

    echo -e "\n${RGB_INFO}20/20 : Tencent Cloud CVM change hostname and cloud init${RGB_END}"
    qcloud_hostname

    reboot_os
}

clear
tool_info
check_root
check_os
check_lock
main