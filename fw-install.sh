#!/bin/bash

# Get arguments from Vagrantfile
www_port=$1
web_serv=$2

# Update all packages
apt-get update

# get cpan package installer and some packages
apt-get install -y cpanminus
cpanm --sudo --skip-installed \
   HTML::Entities \
   HTML::Entities::Numbered \
   HTML::TreeBuilder \
   Lingua::EN::Sentence \
   Mozilla::CA \
   URI::Escape \
   Crypt::Eksblowfish::Bcrypt \
   Win32::Console

# cpanm POSIX   N/A core perl

# cpan modules not really required
#  Crypt::Eksblowfish::Bcrypt                Only for bcrypt support on passwords
#  Win32::Console                            Only for Windows

# Required for legacy RCS stores moving to PFS now as default

apt-get install -y rcs libdigest-sha-perl libhtml-entities-numbered-perl perltidy

# As scanned from DEPENDENCIES files of distro

# This block is generally core perl modules (some exceptions) so no need to install
# apt-get install -y libb-deparse-perl
# apt-get install -y libcarp-perl
# apt-get install -y libcgi-perl
# apt-get install -y libconfig-perl
# apt-get install -y libcwd-perl
# apt-get install -y libdata-dumper-perl
# apt-get install -y libexporter-perl
# apt-get install -y libfile-basename-perl
# apt-get install -y libfile-copy-perl
# apt-get install -y libfile-find-perl
# apt-get install -y libfile-glob-perl
# apt-get install -y libfilehandle-perl
# apt-get install -y libfindbin-perl
# apt-get install -y libgetopt-long-perl
# apt-get install -y libi18n-langinfo-perl
# apt-get install -y libio-file-perl
# apt-get install -y liblocale-country-perl
# apt-get install -y liblocale-language-perl
# apt-get install -y libnet-smtp-perl
# apt-get install -y libpod-usage-perl
# apt-get install -y libsymbol-perl
# apt-get install -y libuniversal-perl

# Extra perl libraries required
apt-get install -y libalgorithm-diff-perl libapache-htpasswd-perl libarchive-tar-perl libarchive-zip-perl libauthen-sasl-perl libcgi-session-perl libcrypt-passwdmd5-perl libcss-minifier-perl libdevel-symdump-perl libdigest-md5-perl libdigest-sha-perl libencode-perl liberror-perl libfcgi-perl libfile-copy-recursive-perl libfile-path-perl libfile-remove-perl libfile-spec-perl libfile-temp-perl libhtml-parser-perl libhtml-tidy-perl libhtml-tree-perl libimage-magick-perl libio-socket-ip-perl libio-socket-ssl-perl libjavascript-minifier-perl libjson-perl liblocale-maketext-perl liblocale-msgfmt-perl libmime-base64-perl libsocket-perl liburi-perl libversion-perl

# Needed by git hooks
apt-get install -y git libtext-diff-perl

# Set up web server
echo "web_serv : $web_serv"
if [ "$web_serv" == "apache" ]
then
	apt-get install -y apache2
else
	apt-get install -y nginx

	# start file fw-prod.conf 
	cat <<EOF > /etc/nginx/sites-available/fw-prod.conf
server {
    server_name  localhost:$1;
EOF
	# Append the rest without shell $vars, so we do not need any escapes
	cat <<"EOF" >> /etc/nginx/sites-available/fw-prod.conf

    error_log /var/log/nginx/fw-prod.log debug;
    set $fw_root "/var/www/fw-prod/core";
    root $fw_root;

    location /pub/ {
	try_files $uri =404;
	limit_except GET POST { deny all; }
    }
    location / {
	deny all;
    }
    location = / {
	   gzip off;
	   include fastcgi_params;
	   fastcgi_pass             unix:/var/run/www/fw-prod.sock;
	   fastcgi_split_path_info  (/.*+)(/.*+);
	   fastcgi_param            SCRIPT_FILENAME $fw_root/bin/view;
	   fastcgi_param            PATH_INFO       $fastcgi_script_name$fastcgi_path_info;
	   fastcgi_param            SCRIPT_NAME     view;
    }
    location ~ ^/[A-Z][A-Za-z0-9]*?/? {
	   gzip off;
	   include fastcgi_params;
	   fastcgi_pass             unix:/var/run/www/fw-prod.sock;
	   fastcgi_split_path_info  (/.*+)(/.*+);
	   fastcgi_param            SCRIPT_FILENAME $fw_root/bin/view;
	   fastcgi_param            PATH_INFO       $fastcgi_script_name$fastcgi_path_info;
	   fastcgi_param            SCRIPT_NAME     view;
    }
    location ~ ^/(?!pub\/)([a-z]++)(\/|\?|\;|\&|\#|$) {
	   gzip off;
	   include fastcgi_params;
	   fastcgi_pass             unix:/var/run/www/fw-prod.sock;
	   fastcgi_split_path_info  (/\w+)(.*);
	   fastcgi_param            SCRIPT_FILENAME $fw_root/bin$fastcgi_script_name;
	   fastcgi_param            PATH_INFO       $fastcgi_path_info;
	   fastcgi_param            SCRIPT_NAME     $fastcgi_script_name;
    }

    # if ($http_user_agent ~ ^SiteSucker|^iGetter|^larbin|^LeechGet|^RealDownload|^Teleport|^Webwhacker|^WebDevil|^Webzip|^Attache|^SiteSnagger|^WX_mail|^EmailCollecto$
    #     rewrite .* /404.html break;
    # }
}
EOF
	# end file fw-prod.conf 

fi

# give www-data a shell that way we can 'sudo -i -u www-data' later
chsh -s /bin/bash www-data

# start file /etc/init.d/fw-prod 
cat <<"EOF" > /etc/init.d/fw-prod
#!/bin/sh
### BEGIN INIT INFO
# Provides:          fw-prod
# Required-Start:    $syslog $remote_fs $network
# Required-Stop:     $syslog $remote_fs $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start the Foswiki backend server.
### END INIT INFO

DESC="Foswiki Production Connector"
NAME=fw-prod

PATH=/sbin:/bin:/usr/sbin:/usr/bin
USER=www-data
GRPOUP=www-data

FOSWIKI_ROOT=/var/www/fw-prod/core

mkdir -p /var/run/www
chown www-data:www-data /var/run/www

FOSWIKI_FCGI=foswiki.fcgi
FOSWIKI_BIND=/var/run/www/$NAME.sock
FOSWIKI_CHILDREN=1
FOSWIKI_PIDFILE=/var/run/www/$NAME.pid
FOSWIKI_TRACE=0

# Include defaults if available
if [ -f /etc/default/$NAME ] ; then
    . /etc/default/$NAME
fi

FOSWIKI_DAEMON=$FOSWIKI_ROOT/bin/$FOSWIKI_FCGI
FOSWIKI_DAEMON_OPTS="-n $FOSWIKI_CHILDREN -l $FOSWIKI_BIND -p $FOSWIKI_PIDFILE -d"

start() {
        log_daemon_msg "Starting $DESC" $NAME
        :> $FOSWIKI_PIDFILE
        echo PIDi=$$
        chown $USER:$GROUP $FOSWIKI_PIDFILE
        chmod 777 $FOSWIKI_PIDFILE
        if ! start-stop-daemon --start --oknodo --quiet \
            --chuid $USER:$GROUP \
            --chdir $FOSWIKI_ROOT/bin \
            --pidfile $FOSWIKI_PIDFILE -m \
            --exec $FOSWIKI_DAEMON -- $FOSWIKI_DAEMON_OPTS
        then
            log_end_msg 1
        else
            log_end_msg 0
        fi
}

stop() {
        log_daemon_msg "Stopping $DESC" $NAME
        if start-stop-daemon --stop --retry 30 --oknodo --quiet --pidfile $FOSWIKI_PIDFILE
        then
            rm -f $FOSWIKI_PIDFILE
            log_end_msg 0
        else
            log_end_msg 1
        fi
}

reload() {
        log_daemon_msg "Reloading $DESC" $NAME
        if start-stop-daemon --stop --signal HUP --oknodo --quiet --pidfile $FOSWIKI_PIDFILE
        then
            log_end_msg 0
        else
            log_end_msg 1
        fi
}

status() {
        status_of_proc -p "$FOSWIKI_PIDFILE" "$FOSWIKI_DAEMON" $NAME
}

. /lib/lsb/init-functions

case "$1" in
  start)
    start
    ;;
  stop)
    stop
    ;;
  reload)
    reload
    ;;
  restart)
    stop
    start
    ;;
  status)
    status
    ;;
  *)
    echo "Usage: $NAME {start|stop|restart|reload|status}"
    exit 1
    ;;
esac
EOF
# end file /etc/init.d/fw-prod 

chown root:root /etc/init.d/fw-prod
chmod 755 /etc/init.d/fw-prod

mkdir --parents /var/www/fw-prod

# Give www-data passwordless sudo rights
cat <<EOF > /etc/sudoers.d/www-data
www-data ALL=(ALL:ALL) NOPASSWD: ALL
EOF

# Create usual .config files for www-data, plus set up some useful env variables
# (www-data is already set with /var/www as it's home directory)

cp -rvt /var/www `find /etc/skel -name '.*'`
cat <<EOF >> /var/www/.bashrc
# Create some useful fw_* ENVironment variables
fw_http='/etc/nginx/sites-available/fw-prod.conf'
fw_init='/etc/init.d/fw-prod'
fw_httplog='/var/log/nginx/fw-prod.log'
export fw_http fw_init fw_httplog
EOF

chown -R www-data:www-data /var/www/
# MM chown www-data:www-data /etc/nginx/sites-available/fw-prod.conf
mkdir /var/log/www
touch /var/log/www/fw-prod.log
chown -R  www-data:www-data /var/log/www/

# MM service nginx stop
# MM rm /etc/nginx/sites-enabled/default
# MM ln -s /etc/nginx/sites-available/fw-prod.conf /etc/nginx/sites-enabled/fw-prod.conf
# MM service nginx start

# Get FW distro from repo
cd /var/www
git clone https://github.com/foswiki/distro.git fw-prod

chown -R www-data:www-data fw-prod
cd /var/www/fw-prod/core
sudo -u www-data perl -T pseudo-install.pl developer
sudo -u www-data perl -T pseudo-install.pl FastCGIEngineContrib

# Bootstrap configure
sudo -u www-data perl tools/configure \
  -noprompt \
  -set {DefaultUrlHost}="http://localhost:$1" \
  -set {ScriptUrlPath}='' \
  -set {ScriptUrlPaths}{view}='' \
  -set {PubUrlPath}='/pub' \
  -set {Password}='vagrant' \
  -set {ScriptDir}='/var/www/fw-prod/core/bin' \
  -set {ScriptSuffix}='' \
  -set {DataDir}='/var/www/fw-prod/core/data' \
  -set {PubDir}='/var/www/fw-prod/core/pub' \
  -set {TemplateDir}='/var/www/fw-prod/core/templates' \
  -set {LocalesDir}='/var/www/fw-prod/core/locale' \
  -set {WorkingDir}='/var/www/fw-prod/core/working' \
  -set {ToolsDir}='/var/www/fw-prod/core/tools' \
  -set {Store}{Implementation}='Foswiki::Store::PlainFile' \
  -set {Store}{SearchAlgorithm}='Foswiki::Store::SearchAlgorithms::PurePerl' \
  -set {SafeEnvPath}='/bin:/usr/bin' \
  -save

update-rc.d fw-prod defaults
service fw-prod start

# Hopefully http://localhost:$1 will now bring up the foswiki Main/WebHome topic

