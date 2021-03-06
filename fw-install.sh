#!/bin/bash

# -----------------------------------------------------------------------------
# Get arguments from Vagrantfile

www_port=$1
web_serv=$2
extraStf=$3

# -----------------------------------------------------------------------------
# Setup packages mostly with apt, but also from cpan

apt-get update

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

# Perl libraries and other required tools
apt-get install -y libalgorithm-diff-perl libapache-htpasswd-perl libarchive-tar-perl libarchive-zip-perl libauthen-sasl-perl libcgi-session-perl libcrypt-passwdmd5-perl libcss-minifier-perl libdevel-symdump-perl libdigest-md5-perl libdigest-sha-perl libencode-perl liberror-perl libfcgi-perl libfile-copy-recursive-perl libfile-path-perl libfile-remove-perl libfile-spec-perl libfile-temp-perl libhtml-parser-perl libhtml-tidy-perl libhtml-tree-perl libimage-magick-perl libio-socket-ip-perl libio-socket-ssl-perl libjavascript-minifier-perl libjson-perl liblocale-maketext-perl liblocale-msgfmt-perl libmime-base64-perl libsocket-perl liburi-perl libversion-perl rcs perltidy libhtml-entities-numbered-perl libhtml-treebuilder-xpath-perl git libtext-diff-perl

# Cpan package installer and some packages, not available through Ubuntu packages
apt-get install -y cpanminus
cpanm --sudo --skip-installed \
	Lingua::EN::Sentence \
	Mozilla::CA

# cpan modules not really required
#  Crypt::Eksblowfish::Bcrypt	Only for bcrypt support on passwords
#  Win32::Console		Only for Windows

# -----------------------------------------------------------------------------
# Set up web server, Apache or Nginx

echo "web_serv : $web_serv"
if [ "$web_serv" == "nginx" ]
then
	# Nginx
	apt-get install -y nginx
	service nginx stop

	# start file fw-prod.conf 
	cat <<"EOF" >> /etc/nginx/sites-available/fw-prod.conf
server {

	listen	80;
	server_name localhost;

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

	# Enable site
	rm /etc/nginx/sites-enabled/default
	ln -s /etc/nginx/sites-available/fw-prod.conf /etc/nginx/sites-enabled/fw-prod.conf
	service nginx start

	# give www-data a shell that way we can 'sudo -i -u www-data' later
	chsh -s /bin/bash www-data

	# -----------------------------------------------------------------------------
	# Setup FCGI

	# start file /etc/init.d/fw-prod 
	cat <<"EOF" > /etc/init.d/fw-prod
#!/bin/sh
### BEGIN INIT INFO
# Provides:		fw-prod
# Required-Start:	$syslog $remote_fs $network
# Required-Stop:	$syslog $remote_fs $network
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
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
	then log_end_msg 1
	else log_end_msg 0
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
	then log_end_msg 0
	else log_end_msg 1
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
else
	# Apache + fastcgi
	cat <<"EOF" >> /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu trusty multiverse
deb http://archive.ubuntu.com/ubuntu trusty-updates multiverse
deb http://security.ubuntu.com/ubuntu trusty-security multiverse
EOF
	aptitude update
	aptitude -y install apache2 libapache2-mod-fastcgi
	a2enmod rewrite 
	service apache stop
	rm /etc/apache2/sites-available/000-default.conf
	rm /etc/apache2/sites-available/default-ssl.conf
	# start file 000-default.conf
	cat <<"EOF" > /etc/apache2/sites-available/fw-prod.conf
# Autogenerated httpd.conf file for Foswiki.
# Generated at http://foswiki.org/Support/ApacheConfigGenerator?vhost=;port=;dir=/var/www/fw-prod/core;symlink=on;pathurl=/;shorterurls=enabled;engine=FastCGI;fastcgimodule=fastcgi;fcgidreqlen=;apver=2;confighost=;configip=;configuser=;loginmanager=Template;htpath=;errordocument=UserRegistration;errorcustom=;phpinstalled=None;blockpubhtml=;blocktrashpub=;controlattach=;blockspiders=;foswikiversion=1.2;apacheversion=2.4;timeout=;ssl=;sslcert=/etc/ssl/apache2/yourservercert.pem;sslchain=/etc/ssl/apache2/sub.class1.server.ca.pem;sslkey=/etc/ssl/apache2/yourservercertkey.pem

# For Foswiki version 1.2,  Apache 2.4

# The Alias defines a url that points to the root of the Foswiki installation.
# The first parameter will be part of the URL to your installation e.g.
# http://my.co.uk/foswiki/bin/view/...
# The second parameter must point to the physical path on your disc.

Alias /bin/configure "/var/www/fw-prod/core/bin/configure"
Alias /bin "/var/www/fw-prod/core/bin/foswiki.fcgi"

# The following Alias is used to access files in the pub directory (attachments etc)
# It must come _after_ the ScriptAlias.
# If short URLs are enabled, and any other local directories or files need to be accessed directly, they
# must also be specified in an Alias statement, and must not conflict with a web name.

Alias /pub "/var/www/fw-prod/core/pub"
Alias /robots.txt "/var/www/fw-prod/core/robots.txt"

#  Rewriting is required for Short URLs, and Attachment redirecting to viewfile
RewriteEngine    on
#RewriteLog "/var/log/apache/rewrite.log"
#RewriteLogLevel 0

# short urls
Alias / "/var/www/fw-prod/core/bin/foswiki.fcgi/"
RewriteRule ^/+bin/+view/+(.*) /$1 [L,NE,R]
RewriteRule ^/+bin/+view$ / [L,NE,R]

# This enables access to the documents in the Foswiki root directory

<Directory "/var/www/fw-prod/core">
    <RequireAll>
        Require all granted
        Require not env blockAccess
    </RequireAll>
</Directory>

<IfModule mod_fastcgi.c>
    # Commenting the next setting makes foswiki to be a dynamic server, loaded on demand.
    # Adjust the number of servers to your needs
    FastCgiServer "/var/www/fw-prod/core/bin/foswiki.fcgi" -processes 3

    # Running an external server on the same machine:
    #FastCgiExternalServer "/var/www/fw-prod/core/bin/foswiki.fcgi" -socket /path/to/foswiki.sock

    # Or at another machine:
    #FastCgiExternalServer "/var/www/fw-prod/core/bin/foswiki.fcgi" -host example.com:8080

    # Refer to details at http://www.fastcgi.com/mod_fastcgi/docs/mod_fastcgi.html
</IfModule>

# This specifies the options on the Foswiki scripts directory. The ExecCGI
# and SetHandler tell apache that it contains scripts. "Allow from all"
# lets any IP address access this URL.
# Note:  If you use SELinux, you also have to "Allow httpd cgi support" in your SELinux policies

<Directory "/var/www/fw-prod/core/bin">
    AllowOverride None

    <RequireAll>
        Require all granted
        Require not env blockAccess
    </RequireAll>

    Options +ExecCGI  +FollowSymLinks
    SetHandler cgi-script
    <Files "foswiki.fcgi">
        SetHandler fastcgi-script
    </Files>

    # Password file for Foswiki users
    AuthUserFile "/var/www/fw-prod/core/data/.htpasswd"
    AuthName 'Enter your WikiName: (First name and last name, no space, no dots, capitalized, e.g. JohnSmith). Cancel to register if you do not have one.'
    AuthType Basic

    # File to return on access control error (e.g. wrong password)
    ErrorDocument 401 /System/UserRegistration

</Directory>

# This sets the options on the pub directory, which contains attachments and
# other files like CSS stylesheets and icons. AllowOverride None stops a
# user installing a .htaccess file that overrides these options.
# Note that files in pub are *not* protected by Foswiki Access Controls,
# so if you want to control access to files attached to topics you need to
# block access to the specific directories same way as the ApacheConfigGenerator
# blocks access to the pub directory of the Trash web
<Directory "/var/www/fw-prod/core/pub">
    Options None
    Options +FollowSymLinks
    AllowOverride None

    <RequireAll>
        Require all granted
        Require not env blockAccess
    </RequireAll>
    ErrorDocument 404 /bin/viewfile

   # This line will redefine the mime type for the most common types of scripts
    AddType text/plain .shtml .php .php3 .phtml .phtm .pl .py .cgi
   #
   # add an Expires header that is sufficiently in the future that the browser does not even ask if its uptodate
   # reducing the load on the server significantly
   # IF you can, you should enable this - it _will_ improve your Foswiki experience, even if you set it to under one day.
   # you may need to enable expires_module in your main apache config
   #LoadModule expires_module libexec/httpd/mod_expires.so
   #AddModule mod_expires.c
   #<ifmodule mod_expires.c>
   #  <filesmatch "\.(jpe?g|gif|png|css(\.gz)?|js(\.gz)?|ico)$">
   #       ExpiresActive on
   #       ExpiresDefault "access plus 11 days"
   #   </filesmatch>
   #</ifmodule>
   #
   # Serve pre-compressed versions of .js and .css files, if they exist
   # Some browsers do not handle this correctly, which is why it is disabled by default
   # <FilesMatch "\.(js|css)$">
   #         RewriteEngine on
   #         RewriteCond %{HTTP:Accept-encoding} gzip
   #         RewriteCond %{REQUEST_FILENAME}.gz -f
   #         RewriteRule ^(.*)$ %{REQUEST_URI}.gz [L,QSA]
   # </FilesMatch>
   # <FilesMatch "\.(js|css)\?.*$">
   #         RewriteEngine on
   #         RewriteCond %{HTTP:Accept-encoding} gzip
   #         RewriteCond %{REQUEST_FILENAME}.gz -f
   #         RewriteRule ^([^?]*)\?(.*)$ $1.gz?$2 [L]
   # </FilesMatch>
   # <FilesMatch "\.js\.gz(\?.*)?$">
   #         AddEncoding x-gzip .gz
   #         AddType application/x-javascript .gz
   # </FilesMatch>
   # <FilesMatch "\.css\.gz(\?.*)?$">
   #         AddEncoding x-gzip .gz
   #         AddType text/css .gz
   # </FilesMatch>

</Directory>

# Security note: All other directories should be set so
# that they are *not* visible as URLs, so we set them as =deny from all=.
<Directory "/var/www/fw-prod/core/data">
    Require all denied
</Directory>

<Directory "/var/www/fw-prod/core/templates">
    Require all denied
</Directory>

<Directory "/var/www/fw-prod/core/lib">
    Require all denied
</Directory>

<Directory "/var/www/fw-prod/core/locale">
    Require all denied
</Directory>

<Directory "/var/www/fw-prod/core/tools">
    Require all denied
</Directory>

<Directory "/var/www/fw-prod/core/working">
    Require all denied
</Directory>

# We set an environment variable called blockAccess.
#
# Setting a BrowserMatchNoCase to ^$ is important. It prevents Foswiki from
# including its own topics as URLs and also prevents other Foswikis from
# doing the same. This is important to prevent the most obvious
# Denial of Service attacks.
#
# You can expand this by adding more BrowserMatchNoCase statements to
# block evil browser agents trying to crawl your Foswiki
#
# Example:
# BrowserMatchNoCase ^SiteSucker blockAccess
# BrowserMatchNoCase ^$ blockAccess

BrowserMatchNoCase ^$ blockAccess

EOF
	# end file fw-prod.conf

	# Enable site and restart server
	a2dissite 000-default.conf
	a2ensite fw-prod
fi

# -----------------------------------------------------------------------------
# Setup web site folders

mkdir --parents /var/www/fw-prod

# Give www-data passwordless sudo rights
cat <<EOF > /etc/sudoers.d/www-data
www-data ALL=(ALL:ALL) NOPASSWD: ALL
EOF

# Create usual .config files for www-data, plus set up some useful env variables, also for root
# (www-data is already set with /var/www as it's home directory)

cp -rvt /var/www `find /etc/skel -name '.*'`
cat <<EOF >> /var/www/.bashrc
# Create some useful fw_* ENVironment variables
fw_http='/etc/nginx/sites-available/fw-prod.conf'
fw_init='/etc/init.d/fw-prod'
fw_httplog='/var/log/nginx/fw-prod.log'
export fw_http fw_init fw_httplog
EOF

cat <<EOF >> /home/vagrant/.bashrc
# Create some useful fw_* ENVironment variables
alias l='ls -la'
alias c='clear'
EOF

cat <<EOF > /home/vagrant/.inputrc
set editing-mode vi
EOF

chown -R www-data:www-data /var/www/
mkdir /var/log/www
touch /var/log/www/fw-prod.log
chown -R www-data:www-data /var/log/www/

# -----------------------------------------------------------------------------
# Get FW distro from repo

cd /var/www
git clone https://github.com/foswiki/distro.git fw-prod

chown -R www-data:www-data fw-prod
cd /var/www/fw-prod/core
sudo -u www-data perl -T pseudo-install.pl developer
sudo -u www-data perl -T pseudo-install.pl FastCGIEngineContrib

# Bootstrap configure
  # -set {DefaultUrlHost}="http://localhost:$www_port" \
sudo -u www-data perl tools/configure \
	-noprompt \
	-set {DefaultUrlHost}="http://localhost" \
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

# -----------------------------------------------------------------------------
# enable and start fcgi for nginx / start apache after FastCGIEngineContrib install

if [ "$web_serv" == "nginx" ]; then
	service fw-prod start
	update-rc.d fw-prod defaults
else
	service apache2 restart
fi

# -----------------------------------------------------------------------------
# add some extra stuff for demonstration purpose

if [ $extraStf -eq 0 ]
then exit 0
echo "No extra stuff asked, end of VM configuration, enjoy Foswiki at http://localhost:$www_port"; exit 0;
fi

cd /var/www/fw-prod/core
# sudo -u www-data perl -T pseudo-install.pl NatSkin NatSkinPlugin Solr ClassificationPlugin 
sudo -u www-data perl -T pseudo-install.pl CopyContrib

echo "Some extra stuff installed as requested (...). End of VM configuration, enjoy Foswiki at http://localhost:$www_port"; exit 0;

# Hopefully http://localhost:$www_port will now bring up the foswiki Main/WebHome topic

