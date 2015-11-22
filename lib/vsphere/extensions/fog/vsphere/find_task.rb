module Fog
  module Compute
    class Vsphere
      class Real
        def find_task(task_id)
          RbVmomi::VIM::Task.new(@connection, task_id)
        rescue RbVmomi::Fault
          nil
        end
      end
    end
  end
end
