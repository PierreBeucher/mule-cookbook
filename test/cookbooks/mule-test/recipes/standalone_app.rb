# Let's create a dummy app...
dummy_app = '/tmp/mule/dummy-app.zip'
package 'zip'
template '/tmp/mule/mule-config.xml' do
  source 'mule-config.xml.erb'
  owner 'root'
  group 'root'
  mode '0755'
  notifies :run, 'execute[create dummy app archive]', :immediately
end
execute 'create dummy app archive' do
  command "zip #{dummy_app} /tmp/mule/mule-config.xml -j"
  action :run
  not_if { ::File.file?(dummy_app) }
end

standalone_app 'mule-test-app-1.0' do
  app_name 'mule-test-app'
  mule_home '/usr/local/mule-esb-test'
  version '1.0'
  ensure_deploy true
  app_archive dummy_app
  action :deploy
end

standalone_app 'mule-test-app-1.1' do
  app_name 'mule-test-app'
  mule_home '/usr/local/mule-esb-test'
  version '1.1'
  ensure_deploy true
  app_archive dummy_app
  action :deploy
end

standalone_app 'mule-test-app-refresh' do
  mule_home '/usr/local/mule-esb-test'
  version '1.0'
  app_archive dummy_app
  ensure_deploy true
  action [ :deploy, :refresh ]
end

standalone_app 'mule-test-app-undeploy' do
  mule_home '/usr/local/mule-esb-test'
  version '1.0'
  app_archive dummy_app
  ensure_deploy true
  action [ :deploy, :undeploy ]
end
