provides :mule_app

property :name, String, name_attribute: true, required: true
property :app_archive, String, required: true
property :mule_home, String, required: true
property :ensure_deploy, [TrueClass, FalseClass], default: false
property :deploy_timeout, Integer, default: 30000

action :deploy do
  deploy_app(new_resource.mule_home, new_resource.app_archive, new_resource.name)
  ensure_app_deployed(new_resource.mule_home, new_resource.name, new_resource.deploy_timeout) if new_resource.ensure_deploy
end

action :undeploy do
  
end

action :update do
  
end

action_class   do
  include Mule::AppHelper
end