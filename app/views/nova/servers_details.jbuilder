json.servers do
    json.array! @vms do |vm|
        json.status    "ACTIVE"
        json.id        vm.id
        json.name      vm.name
        json.tenant_id vm.resource_pool

        json.flavor do
            json.id "standard"
        end

        json.addresses do
            json.private do
                json.array! [vm.public_ip_address] do |ip|
                    json.addr ip
                    json.version 4
                end
            end
        end
    end
end
