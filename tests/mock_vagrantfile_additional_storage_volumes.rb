# -*- mode: ruby -*-
# vi: set ft=ruby :

def get_mac(oui="28:b7:ad")
  "Generate a MAC address"
  nic = (1..3).map{"%0.2x"%rand(256)}.join(":")
  return "#{oui}:#{nic}"
end

cwd = Dir.pwd.split("/").last
username = ENV['USER']
domain_prefix = "#{username}_#{cwd}"
domain_uuid = "688c29aa-e657-5d27-b4bb-d745aad2812e"

Vagrant.require_version ">= 2.1.0"
Vagrant.configure("2") do |config|

  config.vm.define "sw01" do |node|
    guest_name = "sw01"
    node.vm.box = "arista/veos"
    node.vm.synced_folder ".", "/vagrant", id: "vagrant-root", disabled: true

    node.ssh.insert_key = false

    node.vm.provider :libvirt do |domain|
      domain.default_prefix = "#{domain_prefix}"
      domain.cpus = 2
      domain.memory = 2048
      domain.disk_bus = "ide"
      domain.nic_adapter_count = 2
      domain.storage :file, :path => "#{username}-#{guest_name}-volume1.qcow2", :size => "10000", :type => "qcow2", :bus => "ide", :device => "hdb", :allow_existing => true
      domain.storage :file, :path => "#{username}-#{guest_name}-volume2.img", :size => "10000", :type => "raw", :bus => "ide", :device => "hdc", :allow_existing => true
    end
    add_volumes = [
      "virsh vol-create-as default #{username}-#{guest_name}-volume1.qcow2 10000",
      "sleep 1",
      "virsh vol-upload --pool default #{username}-#{guest_name}-volume1.qcow2 /fake/location/volume1.qcow2",
      "sleep 1",
      "virsh vol-create-as default #{username}-#{guest_name}-volume2.img 10000",
      "sleep 1",
      "virsh vol-upload --pool default #{username}-#{guest_name}-volume2.img /fake/location/volume2.img",
      "sleep 1"
    ]
    add_volumes.each do |i|
      node.trigger.before :up do |trigger|
        trigger.name = "add-volumes"
        trigger.info = "Adding Volumes"
        trigger.run = {inline: i}
      end
    end

    delete_volumes = [
      "virsh vol-delete #{username}-#{guest_name}-volume1.qcow2 default",
      "virsh vol-delete #{username}-#{guest_name}-volume2.img default"
    ]
    delete_volumes.each do |i|
      node.trigger.after :destroy do |trigger|
        trigger.name = "remove-volumes"
        trigger.info = "Removing Volumes"
        trigger.run = {inline: i}
      end
    end

    node.vm.network :private_network,
      # sw01-eth1 <--> sw02-eth1
      :mac => "#{get_mac()}",
      :libvirt__tunnel_type => "udp",
      :libvirt__tunnel_local_ip => "127.255.255.1",
      :libvirt__tunnel_local_port => 10001,
      :libvirt__tunnel_ip => "127.255.255.2",
      :libvirt__tunnel_port => 10001,
      :libvirt__iface_name => "sw01-eth1-#{domain_uuid}",
      auto_config: false

    node.vm.network :private_network,
      # sw01-eth2 <--> sw02-eth2
      :mac => "#{get_mac()}",
      :libvirt__tunnel_type => "udp",
      :libvirt__tunnel_local_ip => "127.255.255.1",
      :libvirt__tunnel_local_port => 10002,
      :libvirt__tunnel_ip => "127.255.255.2",
      :libvirt__tunnel_port => 10002,
      :libvirt__iface_name => "sw01-eth2-#{domain_uuid}",
      auto_config: false

  end
  config.vm.define "sw02" do |node|
    guest_name = "sw02"
    node.vm.box = "arista/veos"
    node.vm.synced_folder ".", "/vagrant", id: "vagrant-root", disabled: true

    node.ssh.insert_key = false

    node.vm.provider :libvirt do |domain|
      domain.default_prefix = "#{domain_prefix}"
      domain.cpus = 2
      domain.memory = 2048
      domain.disk_bus = "ide"
      domain.nic_adapter_count = 2
    end

    node.vm.network :private_network,
      # sw02-eth1 <--> sw01-eth1
      :mac => "#{get_mac()}",
      :libvirt__tunnel_type => "udp",
      :libvirt__tunnel_local_ip => "127.255.255.2",
      :libvirt__tunnel_local_port => 10001,
      :libvirt__tunnel_ip => "127.255.255.1",
      :libvirt__tunnel_port => 10001,
      :libvirt__iface_name => "sw02-eth1-#{domain_uuid}",
      auto_config: false

    node.vm.network :private_network,
      # sw02-eth2 <--> sw01-eth2
      :mac => "#{get_mac()}",
      :libvirt__tunnel_type => "udp",
      :libvirt__tunnel_local_ip => "127.255.255.2",
      :libvirt__tunnel_local_port => 10002,
      :libvirt__tunnel_ip => "127.255.255.1",
      :libvirt__tunnel_port => 10002,
      :libvirt__iface_name => "sw02-eth2-#{domain_uuid}",
      auto_config: false

  end

end