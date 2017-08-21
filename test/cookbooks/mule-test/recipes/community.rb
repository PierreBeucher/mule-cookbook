directory '/tmp/mule'

remote_file "/tmp/mule/mule-standalone-3.8.0.zip" do
  source 'https://repository-master.mulesoft.org/nexus/content/repositories/releases/org/mule/distributions/mule-standalone/3.8.0/mule-standalone-3.8.0.zip'
  action :create
end

group node['mule-test']['group'] do
end

user node['mule-test']['user'] do
    manage_home true
    shell '/bin/bash'
    home "/home/#{node['mule-test']['user']}"
    comment 'Mule user'
    group node['mule-test']['group']
end

include_recipe 'java::default'

mule_instance 'mule-esb' do
    enterprise_edition false
    home '/usr/local/mule-esb-test'
    env 'test'
    user node['mule-test']['user']
    group node['mule-test']['group']
    action :create
end

mule_instance 'mule-esb-2' do
    enterprise_edition false
    home '/usr/local/mule-esb-test-2'
    env 'test'
    user node['mule-test']['user']
    group node['mule-test']['group']
    action :create
end

# Let's create a dummy app...
dummy_app = '/tmp/mule/dummy-app.zip'
template '/tmp/mule/mule-config.xml' do
  source 'mule-config.xml.erb'
  owner 'root'
  group 'root'
  mode '0755'
  notifies :run, 'execute[create dummy app archive]', :immediately
end
execute 'create dummy app archive' do
  command "zip #{dummy_app} /tmp/mule/mule-config.xml -j"
  action :nothing
end

mule_app 'mule-test-app-1.0' do
  app_name 'mule-test-app'
  mule_home '/usr/local/mule-esb-test'
  version '1.0'
  ensure_deploy true
  app_archive dummy_app
  action :deploy
end

mule_app 'mule-test-app-1.1' do
  app_name 'mule-test-app'
  mule_home '/usr/local/mule-esb-test'
  version '1.1'
  ensure_deploy true
  app_archive dummy_app
  action :deploy
end

mule_app 'mule-test-app-refresh' do
  mule_home '/usr/local/mule-esb-test'
  version '1.0'
  app_archive dummy_app
  ensure_deploy true
  action [ :deploy, :refresh ]
end

mule_app 'mule-test-app-undeploy' do
  mule_home '/usr/local/mule-esb-test'
  version '1.0'
  app_archive dummy_app
  ensure_deploy true
  action [ :deploy, :undeploy ]
end
