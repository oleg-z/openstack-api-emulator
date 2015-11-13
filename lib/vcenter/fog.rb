require 'fog'
require 'fog/compute/models/server'
require 'fog/core/collection'
require 'fog/core/model'
require 'rbvmomi/vim'

module Fog
  module Fog::Compute
    class Fog::Compute::Vsphere
      class Templates < Fog::Collection
        def find_by_path(vm_path, datacenter = nil)
          object = service.find_by_path(vm_path, datacenter)
          (object.nil? || !object["template"]) ? nil : Template.new(object)
        end
      end

      class Template < Fog::Model
        attribute :path
      end

      class Servers < Fog::Collection
        def find_by_path(vm_path, datacenter = nil)
          object = service.find_by_path(vm_path, datacenter)
          (object.nil? || object["template"]) ? nil : Server.new(object)
        end
      end

      class Server < Fog::Compute::Server
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
        def find_by_path(vm_path, datacenter_name = nil)
          folder = File.dirname(vm_path)
          vm_name = File.basename(vm_path)

          folder = get_raw_vmfolder(folder, datacenter_name)
          raise(Fog::Compute::Vsphere::NotFound, "#{vm_name} was not found") unless folder

          folder
            .children
            .grep(RbVmomi::VIM::VirtualMachine)
            .map(&method(:convert_vm_mob_ref_to_attr_hash))
            .detect { |v| v["id"] == vm_name || v["name"] == vm_name }
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
