require_relative "openstack_vm"

class VSphereDriver::OpenstackImage < VSphereDriver::OpenstackVM
  def state
    task_id = Rails.cache.read(@vm_id)
    if task_id
      task = vsphere.find_task(task_id)
      return :QUEUED if task.info.state != "success" || vm_obj(reload: true).nil?
      Rails.cache.delete(@vm_id)
    end
    return vm_obj(reload: true) ? :ACTIVE : :DELETED
  end
end
