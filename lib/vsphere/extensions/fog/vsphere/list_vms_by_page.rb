module Fog
  module Compute
    class Vsphere
      class Servers < Fog::Collection
        def list_vms_by_page(options = {})
          service
            .list_vms_by_page(from: options[:from], limit: options[:limit])
            .collect { |vm| Server.new(vm) }
        end
      end
    end
  end
end

module Fog
  module Compute
    class Vsphere
      class Real
        def list_vms_by_page(options = { })
          from = options[:from].to_i
          to = from + options[:limit].to_i

          raw_vms = raw_list_all_virtual_machines(options[:datacenter])
          vms = convert_vm_view_to_attr_hash(raw_vms[from, to])


          # remove all template based virtual machines
          #vms.delete_if { |v| v['template'] }
          #vms
        end
      end
    end
  end
end
