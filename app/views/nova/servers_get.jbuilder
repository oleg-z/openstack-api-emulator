json.server do
    if @cloning_in_progress
        json.status "BUILD"
        json.id     @vm.vm_id
    else
        json.status @vm.state
        json.id     @vm.vm_id
        json.name   @vm.name

        if @vm.public_ip_address
            json.addresses do
                json.private do
                    json.array! [@vm.public_ip_address] do |ip|
                        json.addr ip
                        json.version 4
                    end
                end

                json.public do
                    json.array! [@vm.public_ip_address] do |ip|
                        json.addr ip
                        json.version 4
                    end
                end
            end
        end
    end
end
