#!/bin/bash
if [ ! -f /etc/dnsmasq.d/webshots.conf ] ; then
  sudo sh -c "echo 'server=/webshots.com/66.119.43.59' > /etc/dnsmasq.d/webshots.conf"
  sudo /etc/init.d/dnsmasq restart
fi

