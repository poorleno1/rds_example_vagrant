# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
	config.vm.define "dc1" do |dc1|
		dc1.vm.box = "jarekole/2019_gui"
		dc1.vm.synced_folder ".", "/vagrant", disabled: true
		dc1.vm.provider "hyperv" do |h|
		    h.enable_virtualization_extensions = true
			h.linked_clone = true
			h.vmname = "dc1"
		end
		#dc1.vm.provision "shell", path: "scripts/rename-to-dc1.ps1", privileged: false
		#dc1.vm.provision "reload"
		dc1.vm.provision "shell", path: "scripts/provision.ps1", privileged: true
		dc1.vm.provision "reload"
		dc1.vm.provision "shell", path: "scripts/provision.ps1", privileged: true
	end


	config.vm.define "dc2" do |dc2|
		dc2.vm.box = "jarekole/2019_gui"
		dc2.vm.synced_folder ".", "/vagrant", disabled: true
		dc2.vm.provider "hyperv" do |h|
		    h.enable_virtualization_extensions = true
			h.linked_clone = true
			h.vmname = "dc2"
		end
		#dc2.vm.provision "shell", path: "scripts/rename-to-dc2.ps1", privileged: true
		#dc2.vm.provision "reload"
		dc2.vm.provision "shell", path: "scripts/provision-dc2.ps1", privileged: true
		#dc2.vm.provision "reload"
		#dc2.vm.provision "shell", path: "scripts/provision-dc2.ps1", privileged: true
	end
end