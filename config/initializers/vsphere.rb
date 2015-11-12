require File.join(Rails.root, "lib", "vcenter_driver")

configuration = YAML.load_file("#{Rails.root}/config/vsphere.yml")[Rails.env]
configuration.each { |k, v| Rails.application.config.send("#{k}=", v) }



