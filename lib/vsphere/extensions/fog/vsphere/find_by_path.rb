module Fog
  module Compute
    class Vsphere
      class Servers < Fog::Collection
        def find_by_path(vm_path, datacenter = nil)
          object = service.find_by_path(vm_path, datacenter)
          (object.nil? || object["template"]) ? nil : Server.new(object)
        end
      end

      class Templates < Fog::Collection
        def find_by_path(vm_path, datacenter = nil)
          object = service.find_by_path(vm_path, datacenter)
          (object.nil? || !object["template"]) ? nil : Template.new(object)
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
      end
    end
  end
end
