FROM ubuntu:latest 
MAINTAINER Anton Belov anton4@bk.ru

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive


RUN apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y && apt-get clean && \
	apt-get -y install \
	pwgen python-setuptools software-properties-common && \
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C && \
	LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php && \
	apt-get update -y && \
	apt-get -y install  \
	php5.6-fpm php5.6-mysql php-apcu-bc\
	ssmtp ca-certificates curl php5.6-curl php5.6-gd php5.6-intl php-pear php5.6-imagick \
	php5.6-imap php5.6-mbstring php5.6-geoip php5.6-mcrypt php5.6-memcache php5.6-ps php5.6-pspell php5.6-cli php5.6-dev \ 
	php5.6-recode php5.6-sqlite php5.6-tidy php5.6-xmlrpc php5.6-xsl php5.6-xdebug php5.6-soap wget pkg-config &&\
        apt-get clean && \
        rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* /download/directory

RUN apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y && apt-get clean && \
	apt-get -y install \	
	wget python python-pip python-dev libfreetype6 libfontconfig1 \
	build-essential zlib1g-dev libpcre3 libpcre3-dev unzip &&\
	apt-get clean && \
	rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* /download/directory

#ioncube
WORKDIR /tmp
RUN	wget http://downloads3.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz && \
	tar xvfz ioncube_loaders_lin_x86-64.tar.gz &&\
	rm ioncube_loaders_lin_x86-64.tar.gz &&\
	echo ioncube/ioncube_loader_lin_${PHP_VERSION}.so `php-config --extension-dir` &&\
	PHP_VERSION=$(php5.6 -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;") && \
	cp ioncube/ioncube_loader_lin_${PHP_VERSION}.so `php-config --extension-dir` && rm -rf ioncube && \
        echo zend_extension=`php-config --extension-dir`/ioncube_loader_lin_${PHP_VERSION}.so >> /etc/php/5.6/fpm/php.ini 	

#install newrelic
RUN apt-key adv --fetch-keys http://download.newrelic.com/548C16BF.gpg && \
    echo "deb http://apt.newrelic.com/debian/ newrelic non-free" > /etc/apt/sources.list.d/newrelic.list && \
    apt-get -y update && \
    apt-get -y install newrelic-php5 && \
    rm -rf /var/lib/apt/lists/*


# mcrypt enable Enabling session files
RUN  mkdir -p /tmp/sessions/ &&\
    chown www-data.www-data /tmp/sessions -Rf &&\
    sed -i -e "s:;\s*session.save_path\s*=\s*\"N;/path\":session.save_path = /tmp/sessions:g" /etc/php/5.6/fpm/php.ini

RUN wget https://github.com/alanxz/rabbitmq-c/archive/v0.7.0.tar.gz &&\
	 tar -xzvf v0.7.0.tar.gz &&\
	 cd rabbitmq-c-0.7.0/ &&\ 
	 autoreconf -i && ./configure && make && make install                 
RUN pecl install amqp-1.6.0beta3.tgz 


RUN sed -i '/daemonize /c \
daemonize = no' /etc/php/5.6/fpm/php-fpm.conf

# tweak php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" /etc/php/5.6/fpm/php.ini && \
sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" /etc/php/5.6/fpm/php.ini && \
sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 1000M/g" /etc/php/5.6/fpm/php.ini && \
sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php/5.6/fpm/php-fpm.conf && \
sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" /etc/php/5.6/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_children = 5/pm.max_children = 9/g" /etc/php/5.6/fpm/pool.d/www.conf && \
sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" /etc/php/5.6/fpm/pool.d/www.conf && \
sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" /etc/php/5.6/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" /etc/php/5.6/fpm/pool.d/www.conf && \
sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" /etc/php/5.6/fpm/pool.d/www.conf && \
echo "date.timezone = \"Europe/Moscow\"" >> /etc/php/5.6/fpm/php.ini

# fix ownership of sock file for php-fpm
RUN sed -i -e "s/;listen.mode = 0660/listen.mode = 0750/g" /etc/php/5.6/fpm/pool.d/www.conf && \
find /etc/php/5.6/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

RUN sed -i '/^listen /c \
listen = 9000' /etc/php/5.6/fpm/pool.d/www.conf
RUN rm -rf /etc/php/5.6/fpm/conf.d/20-xdebug.ini
RUN sed -i 's/^listen.allowed_clients/;listen.allowed_clients/' /etc/php/5.6/fpm/pool.d/www.conf
RUN mkdir /run/php/ && chmod 777 /run/php/

EXPOSE 9000

VOLUME ["/etc/php-fpm.d", "/var/log/php-fpm", "/var/www/magento"]

WORKDIR /var/www

ENTRYPOINT ["/usr/sbin/php-fpm5.6"]
