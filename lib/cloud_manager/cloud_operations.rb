###############################################################################
#   Copyright (c) 2012-2013 VMware, Inc. All Rights Reserved.
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
################################################################################

# @version 0.5.0

module Serengeti
  module CloudManager
    class Cloud
      CLUSTER_ACTION_MESSAGE = {
        CLUSTER_DELETE  => 'delete',
        CLUSTER_START   => 'start',
        CLUSTER_STOP    => 'stop',
        CLUSTER_RECONFIG => 'reconfig',
        CLUSTER_LIST    => 'list'
      }

      def cloud_vms_op(cloud_provider, cluster_info, cluster_data, action)
        act = CLUSTER_ACTION_MESSAGE[action]
        act = 'unknown' if act.nil?
        logger.info("enter #{act} cluster ... ")
        create_cloud_provider(cloud_provider)
        result = prepare_working(cluster_info, cluster_data)
        @dc_resources = result[:dc_res]

        @status = action
        matched_vms = @dc_resources.clusters.values.map { |cs| cs.hosts.values.map { |host| host.vms.values } }.flatten
        logger.debug("operate vm list before :#{matched_vms.map {|v| v.name}}")
        #for delete action, delete whole cluster currently
        if action == CLUSTER_DELETE
          matched_vms = matched_vms.select { |vm| vm_is_this_cluster?(vm.name) and vm_is_exited_in_cloud?(vm.mob) }
        else
          matched_vms = matched_vms.select { |vm| vm_match_targets?(vm.name, @targets) and vm_is_exited_in_cloud?(vm.mob)}
        end

        logger.debug("operate vm list:#{matched_vms.map {|v| v.name}}")
        logger.debug("vms name: #{matched_vms.collect{ |vm| vm.name }.pretty_inspect}")

        #logger.debug("#{act} all vm's")
        matched_vms
      end

      def list_vms(options = {})
        cloud_provider, cluster_info, cluster_data, task = @cloud_provider, @cluster_info, @cluster_last_data, @task
        action_process(CLOUD_WORK_LIST, task) do
          logger.debug("enter list_vms...")
          vms = cloud_vms_op(cloud_provider, cluster_info, cluster_data, CLUSTER_LIST)
          cluster_wait_ready(vms) if options[:wait_for_ip]
        end
        get_result.servers
      end

      #TODO: support deleting node/group
      def delete()
        cloud_provider, cluster_info, cluster_data, task = @cloud_provider, @cluster_info, @cluster_last_data, @task
        action_process(CLOUD_WORK_DELETE, task) do
          vms = cloud_vms_op(cloud_provider, cluster_info, cluster_data, CLUSTER_DELETE)
          group_each_by_threads(vms, :callee=>'delete vm') { |vm| vm.delete }

          # trick: get the root vm folder of this hadoop cluster from its node group's
          # vm folder path

          root_folder = cluster_info["groups"].first["vm_folder_path"]
          break if root_folder.nil?
          # delete the vm folder after all vms been destroyed
          root_folder = root_folder.split('/')[0,2].join('/')
          @client.folder_delete(@dc_resources.mob, root_folder)
        end
      end

      def start()
        cloud_provider, cluster_info, cluster_data, task = @cloud_provider, @cluster_info, @cluster_last_data, @task
        action_process(CLOUD_WORK_START, task) do
          vms = cloud_vms_op(cloud_provider, cluster_info, cluster_data, CLUSTER_START)
          vms.each { |vm| vm.action = VmInfo::VM_ACTION_START }
          cluster_wait_ready(vms, :force_power_on=>true)
        end
      end

      def stop()
        cloud_provider, cluster_info, cluster_data, task = @cloud_provider, @cluster_info, @cluster_last_data, @task
        action_process(CLOUD_WORK_STOP, task) do
          vms = cloud_vms_op(cloud_provider, cluster_info, cluster_data, CLUSTER_STOP)
          group_each_by_threads(vms, :callee=>'stop vm') { |vm| vm.stop }
        end
      end

      def reconfig()
        cloud_provider, cluster_info, cluster_data, task = @cloud_provider, @cluster_info, @cluster_last_data, @task
        action_process(CLOUD_WORK_RECONFIG, task) do
          vms = cloud_vms_op(cloud_provider, cluster_info, cluster_data, CLUSTER_RECONFIG)
          group_each_by_threads(vms, :callee=>'reconfig vm') { |vm| vm.reconfig }
        end
      end

    end
  end
end
