#!/bin/bash

if [ -z "${DO_TOKEN+set}" ]; then
  echo '$DO_TOKEN is not set'
  exit 1
else
  export DIGITALOCEAN_ACCESS_TOKEN=$DO_TOKEN
fi

if [ -z "${DO_DOMAIN+set}" ]; then
  echo '$DO_DOMAIN is not set'
  exit 1
fi

PWD_DIR=$PWD
DO_DIR=do-work-$RANDOM

mkdir $DO_DIR && cd $DO_DIR

function finish {
  cd ..
  rm -rf $DO_DIR
}

trap finish EXIT

if [ ! `which doctl 2> /dev/null` ] ; then
  curl -sL https://github.com/digitalocean/doctl/releases/download/v1.4.0/doctl-1.4.0-linux-amd64.tar.gz  | tar xz
  chmod a+x doctl
fi

ssh-keygen -q -b 4096 -N '' -t rsa -f $DO_DOMAIN -C root@$DO_DOMAIN

./doctl compute ssh-key list --no-header | grep $DO_DOMAIN > /dev/null 2>&1
if [ $? = 0 ]; then
  ./doctl compute ssh-key delete `./doctl compute ssh-key list --no-header | grep $DO_DOMAIN | cut -f1`
fi

./doctl compute droplet list --no-header | grep $DO_DOMAIN > /dev/null 2>&1
if [ $? = 0 ]; then
  ./doctl compute droplet delete `./doctl compute droplet list --no-header | grep $DO_DOMAIN | cut -f1`
fi

./doctl compute domain list --no-header | grep $DO_DOMAIN > /dev/null 2>&1
if [ $? = 0 ]; then
  ./doctl compute domain delete `./doctl compute domain list --no-header | grep $DO_DOMAIN | cut -f1`
fi 

./doctl compute droplet create $DO_DOMAIN --image centos-7-x64 --region tor1 --size 512mb --wait --ssh-keys `./doctl -v compute ssh-key import $DO_DOMAIN --public-key-file $DO_DOMAIN.pub --format ID --no-header` 2>&1 > /dev/null

./doctl compute domain create $DO_DOMAIN --ip-address `./doctl compute droplet list --format PublicIPv4 --no-header` 2>&1 > /dev/null

set +e
while [ true ]; do
  until [ $ROOT_RESULT = 8 ]; do
    sleep 20
    $(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $DO_DOMAIN root@`./doctl compute droplet list --format Name,PublicIPv4 --no-header | grep $DO_DOMAIN | cut -f2` "curl -sL https://goo.gl/guza4n | bash")
    ROOT_RESULT=$?
  done

  echo '#@*#@* curl -sL https://goo.gl/guza4n | bash #@*#@*'

  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $DO_DOMAIN axion@`./doctl compute droplet list --format Name,PublicIPv4 --no-header | grep $DO_DOMAIN | cut -f2`

  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $DO_DOMAIN axion@`./doctl compute droplet list --format Name,PublicIPv4 --no-header | grep $DO_DOMAIN | cut -f2`

  ./doctl compute ssh-key list --no-header | grep $DO_DOMAIN > /dev/null 2>&1
  if [ $? = 0 ]; then
    ./doctl compute ssh-key delete `./doctl compute ssh-key list --no-header | grep $DO_DOMAIN | cut -f1`
  fi

  exit 4
done
