json.flavors do
    json.array! @flavors do |flavor|
        json.id    flavor
        json.name  flavor
        json.vcpus @flavors_details[flavor]["cpu"]
        json.ram   @flavors_details[flavor]["memory"]
        json.disk  @flavors_details[flavor]["disk"]
        json.swap  ""
    end
end

