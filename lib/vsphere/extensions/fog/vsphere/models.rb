require 'fog/vsphere/models/compute/template'
require 'fog/vsphere/models/compute/folders'

module Fog
  module Compute
    class Vsphere
      class Folders < Fog::Collection
        def exist?(id, datacenter = nil)
          service.get_folder(id, datacenter, type)
          true
        rescue
          false
        end

        def ensure_exist(id, datacenter)

        end
      end

      class Template < Fog::Model
        attribute :path
      end
    end
  end
end
