endpoints = [
    ["compute",   "nova", "v2/#{@tenant_name}"],
    ["computev3", "nova", "v3/#{@tenant_name}"],

    ["image",     "glance", "v1"],
    ["identity",  "admin",  "v2.0"]
]

json.access do
    json.token do
        json.issued_at @session.issued_at
        json.expires   @session.expires_at
        json.id        @session.session_id
        json.tenant do
            json.id          @session.userName.split("\\").last
            json.name        @session.fullName
            json.description ""
            json.enabled     true
        end
    end

    json.user do
        json.username     @session.userName.split("\\").last
        json.name         @session.userName.split("\\").last
        json.id           @session.userName.split("\\").last
        json.roles_links  []
        json.roles        [
                            { "name" => "service" },
                            { "name" => "admin" }
                          ]
    end

    json.serviceCatalog do
        json.array! endpoints do |endpoint|
            type, name, path = endpoint
            json.type type
            json.name name
            json.endpoints do
                json.array! [""] do
                    json.region      "vcenter"
                    json.id          type
                    json.adminURL    "#{Rails.configuration.api["url"]}/#{name}/#{path}/"
                    json.internalURL "#{Rails.configuration.api["url"]}/#{name}/#{path}/"
                    json.publicURL   "#{Rails.configuration.api["url"]}/#{name}/#{path}/"
                end
            end
        end
    end
end
