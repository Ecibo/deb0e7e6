#!/bin/bash

check_kernel_version(){
	kernel_ver=(`uname -r | grep -o -e ^[0-9]*.[0-9]*.[0-9]* | tr . "\n"`)
	test_ver=(`echo $1 | tr . "\n"`)
	for order in 0 1 2; do
		if [ "${test_ver[$order]}" = "" ]; then
			return 0
		fi;
		if [ ${kernel_ver[$order]} -lt ${test_ver[$order]} ]; then
			return 1
		fi
		if [ ${kernel_ver[$order]} -gt ${test_ver[$order]} ]; then
			return 0
		fi
	done
	return 0
}

grep -q -E ^www-data: /etc/group || groupadd -g 33 www-data
grep -q -E ^www-data: /etc/passwd || useradd -u 33 -d /var/www -g www-data -s /usr/sbin/nologin www-data

cd `dirname $(readlink -f $0)`

install nginx /usr/local/bin/
cp nginx.service /etc/systemd/system/

if [ ! -e /etc/nginx ]; then
	echo "Copy config files."
	test -e /etc/nginx || mkdir /etc/nginx
	cp -r config/* /etc/nginx
fi

mkdir -p /var/www/htdocs
chmod -R 0755 /var/www
chown -R www-data:www-data /var/www/htdocs
cp -r html/* /var/www/htdocs

if ! check_kernel_version 3.8.0; then
	echo "Config for old kernel support."
	setcap CAP_NET_BIND_SERVICE+eip /usr/local/bin/nginx
	sed -i "s/^CapabilityBoundingSet=/;\0/" /etc/systemd/system/nginx.service
	sed -i "s/^AmbientCapabilities=/;\0/" /etc/systemd/system/nginx.service
fi

systemctl daemon-reload
systemctl enable nginx

echo "Type 'systemctl start nginx' to start service."
echo "You may need to stop Apache/Nginx or other web service first."
