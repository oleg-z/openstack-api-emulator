require File.join(Rails.root, "lib", "vsphere", "vsphere_driver")

vsphere_config_path = "#{Rails.root}/config/vsphere.yml"
configuration = YAML.load_file(vsphere_config_path)[Rails.env]
fail "Environment #{Rails.env} isn't defined in #{vsphere_config_path}" unless configuration
configuration.each { |k, v| Rails.application.config.send("#{k}=", v) }
