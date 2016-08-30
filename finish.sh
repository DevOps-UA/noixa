#!/bin/bash

if [ $USER = 'root' ]; then

  yum -q check-update > /dev/null 2>&1
  if [ $? = 100 ]; then
    yum -y -q update > /dev/null 2>&1
  fi

  if [ ! "`rpm -q kernel --queryformat '%{installtime} %{version}-%{release}.%{arch}\n' | sort -n -k1 | tail -1 | cut -d ' ' -f 2`" = "`uname -r`" ]; then 
    reboot; 
  fi
  
  which ansible > /dev/null 2>&1
  if [ $? != 0 ]; then 
    yum -y install epel-release > /dev/null 2>&1
    yum -y install git python-pip gcc python-devel libffi-devel openssl-devel > /dev/null 2>&1
    pip install --upgrade pip setuptools > /dev/null 2>&1
    pip install ansible > /dev/null 2>&1
  fi

  getent passwd axion > /dev/null 2>&1
  if [ $? != 0 ]; then
    adduser axion
    echo "axion ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/axion
    mkdir ~axion/.ssh && chmod -R 0700 ~axion
    cp ~/.ssh/authorized_keys ~axion/.ssh/.
    chown -R axion:axion ~axion
  else
    exit 8
  fi

else

  cd ~
  
  if [ ! -d rcs ]; then
    mkdir rcs
  fi
  
  cd rcs
  
  if [ ! -d noixa ]; then
    git clone https://github.com/zaxion/noixa.git && cd noixa
    git remote set-url origin git@github.com:zaxion/noixa.git
  else
    cd noixa
    git remote set-url origin https://github.com/zaxion/noixa.git
    git pull
    git remote set-url origin git@github.com:zaxion/noixa.git
  fi

  export ANSIBLE_HOST_KEY_CHECKING=false
  export ANSIBLE_ROOT=$HOME/rcs/noixa/ansible
  
  if [ -f ~/.vault_password ] ; then
    export ANSIBLE_VAULT_PASSWORD_FILE=$HOME/.vault_password
    ansible-playbook ansible/site.yml
  else
    ansible-playbook --ask-vault-pass ansible/site.yml
  fi

  docker top dropbox > /dev/null 2>&1
  if [ $? = 1 ]; then
    docker run -d --restart=always --name=dropbox -e DBOX_UID=1000 -e DBOX_GID=1000 -v ~/dropbox:/dbox/Dropbox janeczku/dropbox
  fi

fi
