endpoints = [
    ["compute",   "nova", "v2"],
    ["computev3", "nova", "v3"],

    ["network",   "neutron", "v1"],

    ["volume",    "cinder", "v1"],
    ["volumev2",  "cinder", "v2"],

    ["image",     "glance", "v1"]
]

json.access do
    json.token do
        json.issued_at @token.loginTime
        json.expires   @token.loginTime + 86400
        json.id        "#{@username}::#{@password}"
        json.tenant do
            json.description @token.fullName
            json.enabled     true
            json.id          @username
            json.name        @token.fullName
        end
    end

    json.serviceCatalog do
        json.array! endpoints do |endpoint|
            type, name, version = endpoint
            json.type type
            json.name name
            json.endpoints do
                json.array! [""] do
                    json.region      "vcenter"
                    json.id          type
                    json.adminURL    "#{Rails.configuration.api_url}/#{name}/#{version}/"
                    json.internalURL "#{Rails.configuration.api_url}/#{name}/#{version}/"
                    json.publicURL   "#{Rails.configuration.api_url}/#{name}/#{version}/"
                end
            end
        end
    end
end
