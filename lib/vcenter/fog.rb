require 'fog'
require 'fog/compute/models/server'
require 'fog/core/collection'
require 'fog/core/model'
require 'rbvmomi/vim'

module Fog
  module Fog::Compute
    class Fog::Compute::Vsphere
      class Servers < Fog::Collection
        def find_vm_by_path(vm_path, datacenter = nil)
          Server.new service.find_vm_by_path(vm_path, datacenter)
        end
      end

      # define missing operation for Server
      class Server < Fog::Compute::Server
        def find_by_path(vm_path, datacenter = nil)
          new service.find_vm_by_path(vm_path, datacenter)
        end

        def move_to_folder(options = {})
          requires :instance_uuid
          service.vm_move_to_folder('instance_uuid' => instance_uuid, 'folder' => options[:folder], 'datacenter' => datacenter)
        end

        def annotate(options = {})
          requires :instance_uuid
          service.vm_annotate('instance_uuid' => instance_uuid, 'annotation' => options[:annotation])
        end

        def set_memory(options = {})
          requires :instance_uuid
          service.vm_reconfig_memory('instance_uuid' => instance_uuid, 'memory' => options[:memory])
        end

        def add_network_card(options = {})
          requires :instance_uuid

          # execute reconfigure task
          hardware_spec = {
            :deviceChange => [
              RbVmomi::VIM.VirtualDeviceConfigSpec(
               :operation => RbVmomi::VIM.VirtualDeviceConfigSpecOperation(:add),
                :device => RbVmomi::VIM.VirtualE1000(
                  :key => -1,
                  :backing => RbVmomi::VIM.VirtualEthernetCardNetworkBackingInfo(:deviceName => "Network adapter")
                 )
               )
             ]
           }

          service.vm_reconfig_hardware('instance_uuid' => instance_uuid, 'hardware_spec' => hardware_spec)
        end

        def set_network(options = {})
          requires :instance_uuid
          service.vm_set_network('instance_uuid' => instance_uuid, 'adapter_index' => options[:adapter_index], 'network_name' => options[:network_name], 'datacenter' => self.datacenter)
        end

        def set_disk_size(options = {})
          requires :instance_uuid
          service.set_disk_size('instance_uuid' => instance_uuid, 'disk_size' => options[:size], 'datacenter' => self.datacenter)
        end

        def mark_as_template(options = {})
          requires :instance_uuid
          service.mark_as_template('instance_uuid' => instance_uuid)
        end
      end

      class Real
        #def find_vm_by_path(vm_path, dc = nil)
        #  datacenters   = [dc] if dc
        #  datacenters ||= raw_datacenters.collect { |d| d["name"] }
        #  vm = nil
        #  counter = 1
        #  datacenters.each do |datacenter|
        #    if folder
        #      vm = list_all_templates_in_folder(folder, datacenter)
        #        .detect { |v| v["id"] == id || v["name"] == id }
        #    else
        #      raw_vm = raw_list_all_virtual_machines(dc)
        #          .shuffle
        #          .detect { |v| counter+=1; puts counter; v.config.uuid == id }
        #      vm = convert_vm_view_to_attr_hash([raw_vm]).first if raw_vm
        #    end
        #  end
        #  vm ? vm : raise(Fog::Compute::Vsphere::NotFound, "#{id} was not found")
        #end

        def find_vm_by_path(vm_path, datacenter_name = nil)
          folder = File.dirname(vm_path)
          vm_name = File.basename(vm_path)
          vm = list_vms_in_folder(folder, datacenter_name)
            .detect { |v| v["id"] == vm_name || v["name"] == vm_name }
          vm ? vm : raise(Fog::Compute::Vsphere::NotFound, "#{id} was not found")
        end

        def list_vms_in_folder(path, datacenter_name)
          folder = get_raw_vmfolder(path, datacenter_name)
          vms = folder.children.grep(RbVmomi::VIM::VirtualMachine)
          # remove all template based virtual machines
          vms.delete_if { |v| v.config.nil? || v.config.template }
          vms.map(&method(:convert_vm_mob_ref_to_attr_hash))
        end


        def vm_move_to_folder(options = {})
          raise ArgumentError, "instance_uuid is a required parameter" unless options.has_key? 'instance_uuid'
          raise ArgumentError, "folder is a required parameter" unless options.has_key? 'folder'
          raise ArgumentError, "datacenter is a required parameter" unless options.has_key? 'datacenter'

          vm_mob_ref = get_vm_ref(options['instance_uuid'])
          vm_folder_ref = get_raw_vmfolder(options['folder'], options['datacenter'])
          task = vm_folder_ref.MoveIntoFolder_Task('_this'=> vm_folder_ref, 'list' => [vm_mob_ref])
          task.wait_for_completion
          { 'task_state' => task.info.state }
        end


        # search VM by name
        # if default get_virtual_machine can't find vm by name methods iterates through folders
        # and try to find matching folder + VM combination
        # even through it seems as a lot of work it's still much more efficient than servers.all
        def get_virtual_machine_by_name(vm_name, datacenter_name = nil)
          begin
            return get_virtual_machine(vm_name, datacenter_name)
          rescue Fog::Compute::Vsphere::NotFound
          end

          datacenters = find_datacenters(datacenter_name)
          datacenters.map do |dc|
            @connection.serviceContent.viewManager.CreateContainerView({
              :container  => dc.vmFolder,
              :type       =>  ["Folder"],
              :recursive  => true
            }).view.each do |folder|
              begin
                return get_virtual_machine(get_full_folder(folder, dc) + "/" + vm_name, datacenter_name)
              rescue Fog::Compute::Vsphere::NotFound
              end
            end
          end
          raise Fog::Compute::Vsphere::NotFound
        end

        # build full folder path
        def get_full_folder(folder, dc)
          return folder.name if folder.parent == dc.vmFolder
          return get_full_folder(folder.parent, dc) + "/" + folder.name
        end

        def vm_annotate(options = {})
          raise ArgumentError, "instance_uuid is a required parameter" unless options.has_key? 'instance_uuid'
          raise ArgumentError, "annotation is a required parameter" unless options.has_key? 'annotation'

          vm_mob_ref = get_vm_ref(options['instance_uuid'])
          task = vm_mob_ref.ReconfigVM_Task(:spec => RbVmomi::VIM.VirtualMachineConfigSpec(:annotation => options['annotation']))
          task.wait_for_completion
          { 'task_state' => task.info.state }
        end

        # translated perl code from http://communities.vmware.com/message/840944#840944
        def vm_set_network(options = {})
          raise ArgumentError, "instance_uuid is a required parameter" unless options.has_key? 'instance_uuid'
          raise ArgumentError, "network_name is a required parameter" unless options.has_key? 'network_name'
          raise ArgumentError, "datacenter is a required parameter" unless options.has_key? 'datacenter'
          raise ArgumentError, "adapter_index is a required parameter" unless options.has_key? 'adapter_index'

          # get information about virtual port group and virtual switch
          networkObj = self.get_raw_network(options['network_name'], options['datacenter'] || vm.datacenter)

          backingInfo = nil
          if networkObj.class.to_s == "Network"
            backingInfo = RbVmomi::VIM.VirtualEthernetCardNetworkBackingInfo(
              :deviceName => networkObj.name,
              :network => networkObj
            )
          else
            portgroupKey = networkObj.key
            switchUuid = networkObj.config.distributedVirtualSwitch.uuid

            backingInfo = RbVmomi::VIM.VirtualEthernetCardDistributedVirtualPortBackingInfo(
              :port => RbVmomi::VIM.DistributedVirtualSwitchPortConnection(
                :portgroupKey => portgroupKey,
                :switchUuid => switchUuid
              )
            )
          end

          # get vm info
          vm_mob_ref = get_vm_ref(options['instance_uuid'])

          # get first vm interface
          interface = vm_mob_ref.config.hardware.device.grep(RbVmomi::VIM::VirtualEthernetCard)[options['adapter_index']]
          interface.backing = backingInfo

          # execute reconfigure task
          new_vm_spec = RbVmomi::VIM.VirtualMachineConfigSpec(
            :deviceChange => [RbVmomi::VIM.VirtualDeviceConfigSpec(
              :device => interface,
              :operation => RbVmomi::VIM.VirtualDeviceConfigSpecOperation(:edit)
            )]
          )
          task = vm_mob_ref.ReconfigVM_Task(:spec => new_vm_spec)
          task.wait_for_completion
          { 'task_state' => task.info.state }
        end

        # translated perl code from http://communities.vmware.com/message/840944#840944
        def set_disk_size(options = {})
          raise ArgumentError, "instance_uuid is a required parameter" unless options.has_key? 'instance_uuid'
          raise ArgumentError, "datacenter is a required parameter" unless options.has_key? 'datacenter'
          raise ArgumentError, "set_disk_size is a required parameter" unless options.has_key? 'disk_size'

          # get vm info
          vm_mob_ref = get_vm_ref(options['instance_uuid'])

          # get first vm interface
          virtual_disk = vm_mob_ref.config.hardware.device.grep(RbVmomi::VIM::VirtualDisk)[0]
          virtual_disk.capacityInKB = options['disk_size'] * 1024 * 1024;

          # execute reconfigure task
          new_vm_spec = RbVmomi::VIM.VirtualMachineConfigSpec(
            :deviceChange => [RbVmomi::VIM.VirtualDeviceConfigSpec(
              :device => virtual_disk,
              :operation => RbVmomi::VIM.VirtualDeviceConfigSpecOperation(:edit)
            )]
          )
          task = vm_mob_ref.ReconfigVM_Task(:spec => new_vm_spec)
          task.wait_for_completion
          { 'task_state' => task.info.state }
        end

        def mark_as_template(options = {})
          raise ArgumentError, "instance_uuid is a required parameter" unless options.key? 'instance_uuid'

          vm_mob_ref = get_vm_ref(options['instance_uuid'])

          unless vm_mob_ref.kind_of? RbVmomi::VIM::VirtualMachine
            raise Fog::Vsphere::Errors::NotFound,
              "Could not find VirtualMachine with instance uuid #{options['instance_uuid']}"
          end

          vm_mob_ref.MarkAsTemplate
        end
      end
    end
  end
end
