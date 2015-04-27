# FoswikiVagrantNginx

Version 0.3
===========

Project renamed from FoswikiVagrantNginx to FoswikiVagrant. We can now choose the web server between apache and nginx.

Folder name is now : Hostname__webport_sshport_webserv, with defaults of : webport: 8080 - sshport:  2220 - webserv: nginx

Vagrantfile :
   * web_serv option, nginx is the default
   * less comment for better readability
   * box name is now exactly the folder name (no longer timestamped)

fw-install.sh :
   * 2 parms received : www port and web server choice
   * one apt-get is faster than multiple ones


Version 0.2
===========
The process has been slimmed down with only two files required. They are created inside the shell script which also allows me to parameterize certain elements.
 
I also now take the directory name containing the vagrantfile as parameters as follows:
 
Hostname__webport_sshport
OR
Hostname    with defaults of 8080 and 2220 (that is the directory name is the hostname)
 
For example, I have Foswiki-09__8089_2229. It's an important help when creating multiple VMs as I am doing. In addition it means that each terminal reports the Hostname so I do not get lost.

So to summarize :
   * git clone https://github.com/Jlevens/FoswikiVagrantNginx
   * mv FoswikiVagrantNginx testfw__8081_2221
   * cd testfw__8081_2221
   * vagrant up

Note that Vagrant will also open is own ssh port in addition to your. It will be 2222 by default.

In addition to the default configuration, the following is provided :
   * a regular test user : log in as TestUser password TestUser

Version 0.1
===========

Vanilla Foswiki install from master github repo using Nginx as Webserver

Tested with VirtualBox on Windows as host, *should* also work on a linux host.

You'll need to install the following two items, both are one-click type installs &mdash; very easy.
   * https://www.virtualbox.org/wiki/Downloads
   * https://www.vagrantup.com/downloads.html

Clone this repo into a directory then run 'vagrant up' from within that directory, that's all it needs.
   * https://www.virtualbox.org/wiki/Downloads &mdash; version 4.3.20 or later
   * https://www.vagrantup.com/downloads.html &mdash; version 1.7.2 or later

Earlier versions of virtualbox & vagrant *may* work, but the further back you are the greater the risk of failure.

Clone this repo into a directory then run 'vagrant up' from within that directory, that's all it needs.

Then try http://localhost:8080 from a host browser and up should come your Foswiki site. You can login as admin with pw vagrant.
  
Inspired by https://github.com/Babar/foswiki-vagrant which I used for some time.

However, I had difficulties using the Foswiki build tools in the Windows host. So I decided to start from scratch, in part to learn and understand the process better. Chose to start developing with shell scripts as recommended by Vagrant documentation.

There is the potential a move to chef, puppet, ansible (or whatever provisioners Vagrant supports) as my knowledge improves or other contributors get involved. It's also possible to stick with shell scripts if it turns out to be good enough.
   1. ssh onto the with vagrant as user and pw.
   2. sudo -i -u www-data    &mdash; work as the user www-data this is deliberate: it is also the web-user
   3. Home directory of www-data is /var/www
   4. cd fw-prod      &mdash; this is where the Foswiki Production code is kept. In practice it's a misnomer this is a dev build at the moment. In the future a build suitable for Production use with matching Test; QA environments could be provided.
   5. ll  &mdash; see the Foswiki plugins provided and core.
