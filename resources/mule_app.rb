provides :mule_app

property :app_name, String, name_property: true
property :version, String, required: true
property :app_archive, String
property :mule_home, String, required: true
property :ensure_deploy, [TrueClass, FalseClass], default: false
property :deploy_timeout, Integer, default: 30000
property :undeploy_other_versions, [TrueClass, FalseClass], default: true

action :deploy do
  versions = get_deployed_versions(new_resource.mule_home, new_resource.app_name)
  if !versions.include?(new_resource.version)
    undeploy_versions(new_resource.mule_home, new_resource.app_name, new_resource.ensure_deploy, versions - [new_resource.version], new_resource.deploy_timeout) if new_resource.undeploy_other_versions    
    deploy_app(new_resource.mule_home, new_resource.app_archive, new_resource.app_name, new_resource.version)
    ensure_app_deployed(new_resource.mule_home, new_resource.app_name, new_resource.version, new_resource.deploy_timeout) if new_resource.ensure_deploy
  end
  
end

action :undeploy do
  if is_app_deployed?(new_resource.mule_home, new_resource.app_name, new_resource.version)
    undeploy_app(new_resource.mule_home, new_resource.app_name)
    ensure_app_undeployed(new_resource.mule_home, new_resource.app_name, new_resource.version, new_resource.deploy_timeout) if new_resource.ensure_deploy
  end
end

action :refresh do
  refreshed_at = Time.now
  refresh_app(new_resource.mule_home, new_resource.app_name, new_resource.version)
  ensure_app_refreshed(new_resource.mule_home, new_resource.app_name, new_resource.version, refreshed_at, new_resource.deploy_timeout) if new_resource.ensure_deploy
end


action_class.class_eval do
  include Mule::AppHelper
end