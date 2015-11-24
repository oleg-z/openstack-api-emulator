require 'rubygems/package'
module Fog
  module Compute
    class Vsphere
      class Server < Fog::Compute::Server
        def export_ovf(options = {})
          requires :instance_uuid
          service.export_ovf('instance_uuid' => instance_uuid, 'output' => options[:output])
        end
      end

      class Real
        def export_ovf(options = {})
          output = options['output']
          vm = get_vm_ref(options["instance_uuid"])
          lease = vm.ExportVm
          lease_timeout = Time.now + lease.info.leaseTimeout - 60

          descriptor = @connection.serviceContent.ovfManager.CreateDescriptor(obj: vm, cdp: {})

          # modifying ovf manifest
          ovf = Nokogiri::XML(descriptor.ovfDescriptor)

          vmdks = []
          lease.info.deviceUrl.each do |d|
            disk = nil
            filename = "#{vm.name}-disk1.vmdk"
            ovf.css("References/File").each do |f|
              next unless f.attributes["href"].value == d.key
              disk = ovf.css("DiskSection/Disk").detect { |tdisk| tdisk.attributes["fileRef"].value == f.attributes["id"].value }
              f.attributes["href"].value = filename
            end
            fail "Can't find appropriate disk in ovf xml" unless disk

            vmdks << {
              name: "#{vm.name}-disk1.vmdk",
              size: disk.attributes["capacity"].value.to_i * 1024 * 1024 * 1024,
              url:  d.url
            }
          end

          tar = Gem::Package::TarWriter.new(output)
          tar.add_file_simple("#{vm.name}.ovf", 0755, ovf.to_s.size) { |io| io.write(ovf.to_s) }

          all_disks_size = lease.info.totalDiskCapacityInKB * 1024
          vmdks.each do |vmdk|
            downloaded = 0
            tar.add_file_simple(vmdk[:name], 0755, vmdk[:size]) do |io|
              uri = URI(vmdk[:url])
              http = Net::HTTP.new(uri.host, uri.port)
              http.use_ssl = (uri.scheme == 'https')
              http.verify_mode = OpenSSL::SSL::VERIFY_NONE

              http.request_get(uri) do |response|
                response.read_body do |str|
                  downloaded += io.write(str)
                  #puts "Downloaded #{downloaded}, progress: #{progress}%" if progress > last_reported_progress
                  #last_reported_progress = progress
                  if Time.now > lease_timeout
                    progress = (downloaded/all_disks_size) * 100
                    lease.HttpNfcLeaseProgress(percent: progress.to_i)
                    lease_timeout = Time.now + lease.info.leaseTimeout - 60
                  end
                end
              end
            end
          end
          lease.HttpNfcLeaseComplete
        end
      end
    end
  end
end
