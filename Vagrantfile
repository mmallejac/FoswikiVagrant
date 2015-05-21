
# Fixed settings
box = 'ubuntu/trusty64'
ram = '1024'

# Split the folder name to get the other settings
vmName = File.basename(File.expand_path(File.dirname(__FILE__)))
if match = vmName.match(/(.*?)__(.*?)_(.*)_(.*)_(.*)/)
    hostName, www_port, ssh_port, web_serv, extraStf = match.captures
else
    hostName = vmName
    www_port = 8080
    ssh_port = 2220
    web_serv = "nginx"
    extraStf = 0
end

# Provision virtual machine
# finally call config shell script
VAGRANTFILE_API_VERSION = "2"
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box = box
  config.vm.hostname = hostName

  config.vm.network "forwarded_port", guest: 80, host: www_port
  config.vm.network "forwarded_port", guest: 22, host: ssh_port

  config.vm.provider "virtualbox" do |vb|
    vb.name = vmName
    vb.memory = ram
  end

  config.vm.provision "shell" do |s|
    s.path = "fw-install.sh"
    s.args = "#{www_port} #{web_serv} #{extraStf}"
  end

end
