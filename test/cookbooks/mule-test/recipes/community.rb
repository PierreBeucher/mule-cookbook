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

remote_file "/tmp/mule/mule-example-hello.zip" do
  source 'http://repo1.maven.org/maven2/org/mule/examples/mule-example-hello/3.4.0/mule-example-hello-3.4.0.zip'
  action :create
end

mule_app 'mule-test-app' do
  mule_home '/usr/local/mule-esb-test'
  app_archive '/tmp/mule/mule-example-hello.zip'
end
