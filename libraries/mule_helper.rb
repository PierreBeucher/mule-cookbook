require 'uri'
require 'net/http'

module Mule
  module Helper
    def amc_setup(username, password, organization, environment)
      authToken = get_auth_token(username, password)
      orgId = get_org_id(authToken, organization)
      envId = get_env_id(authToken, orgId, environment)
      registrationToken = get_arm_token(authToken, orgId, envId)
    end

    def get_auth_token(username, password)
      response = anypoint_post('https://anypoint.mulesoft.com/accounts/login',
      { 'username' => username, 'password' => password }.to_json, {'Content-Type' => 'application/json'})
      authToken = JSON.parse(response.body).values_at('access_token')[0]
    end

    def get_org_id(auth, organization)
      response = anypoint_get('https://anypoint.mulesoft.com/accounts/api/profile',
      {'Authorization' => "bearer #{auth}"})
      orgList = JSON.parse(response.body).values_at('memberOfOrganizations')[0]
      orgId = ''
      orgList.each do |org|
        testOrg = org.values_at('name')[0]
        if testOrg.eql?(organization)
          orgId = org.values_at('id')[0]
        end
      end
      orgId
    end

    def get_env_id(auth, orgId, environment)
      response = anypoint_get("https://anypoint.mulesoft.com/accounts/api/organizations/#{orgId}",
      {'Authorization' => "bearer #{auth}"})
      envList = JSON.parse(response.body).values_at('environments')[0]
      envId = ''
      envList.each do |env|
        testEnv = env.values_at('name')[0]
        if testEnv.eql?(environment)
          envId = env.values_at('id')[0]
        end
      end
      envId
    end

    def get_arm_token(auth, orgId, envId)
      response = anypoint_get('https://anypoint.mulesoft.com/hybrid/api/v1/servers/registrationToken',
      {'Authorization' => "bearer #{auth}", 'X-ANYPNT-ORG-ID' => orgId, 'X-ANYPNT-ENV-ID'=> envId})
      regToken = JSON.parse(response.body).values_at('data')[0]
    end

    def anypoint_get(url, headers)
      uri = URI(url)
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      response = https.get(uri.path, headers)
    end

    def anypoint_post(url, body, headers)
      uri = URI(url)
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      response = https.post(uri.path, body, headers)
    end

    def install_community_runtime
      package 'tar'
      package 'unzip'

      archive_name = "mule-standalone-#{new_resource.version}"
      folder_name = "mule-standalone-#{new_resource.version}"
      archive_name = new_resource.archive_name || archive_name

      if ::File.exist?("#{new_resource.source}/#{archive_name}.tar.gz")
        execute "extract .tar.gz for #{new_resource.name}" do
          command "tar -C /tmp/ -zxf #{new_resource.source}/#{archive_name}.tar.gz"
          not_if "[ -e /tmp/#{folder_name} ] || [ -e #{new_resource.home} ]"
        end
      else
        execute "extract .zip for #{new_resource.name}" do
          command "unzip -d /tmp/ #{new_resource.source}/#{archive_name}"
          not_if "[ -e /tmp/#{folder_name} ] || [ -e #{new_resource.home} ]"
        end
      end

      execute "create #{new_resource.home}" do
        command <<-EOH
                    cp -pR /tmp/#{folder_name}/ #{new_resource.home}
                    chown -R #{new_resource.user}:#{new_resource.group} #{new_resource.home}
        EOH
        not_if "[ -e #{new_resource.home} ]"
      end
    end

    def install_enterprise_runtime
      package 'tar'
      package 'unzip'

      archive_name = "mule-ee-distribution-standalone-#{new_resource.version}"
      folder_name = "mule-enterprise-standalone-#{new_resource.version}"
      archive_name = new_resource.archive_name || archive_name

      if ::File.exist?("#{new_resource.source}/#{archive_name}.tar.gz")
        execute "extract .tar.gz for #{new_resource.name}" do
          command "tar -C /tmp/ -zxf #{new_resource.source}/#{archive_name}.tar.gz"
          not_if "[ -e /tmp/#{folder_name} ] || [ -e #{new_resource.home} ]"
        end
      else
        execute "extract .zip for #{new_resource.name}" do
          command "unzip -d /tmp/ #{new_resource.source}/#{archive_name}"
          not_if "[ -e /tmp/#{folder_name} ] || [ -e #{new_resource.home} ]"
        end
      end

      execute "create #{new_resource.home}" do
        command <<-EOH
                    cp -pR /tmp/#{folder_name}/ #{new_resource.home}
                    chown -R #{new_resource.user}:#{new_resource.group} #{new_resource.home}
        EOH
        not_if "[ -e #{new_resource.home} ]"
      end
    end

    def install_systemd_service
      template "/etc/systemd/system/#{new_resource.name}.service" do
        owner 'root'
        group 'root'
        source 'mule.service.erb'
        cookbook 'mule'
        mode 0644
        variables(
        mule_home: new_resource.home,
        version: new_resource.version,
        mule_env: new_resource.env,
        user: new_resource.user,
        name: new_resource.name
        )
      end
    end

    def install_upstart_service
      template "/etc/default/#{new_resource.name}" do
        owner new_resource.user
        group new_resource.group
        source 'mule.erb'
        cookbook 'mule'
        mode 0644
        variables(
        mule_home: new_resource.home,
        mule_env: new_resource.env
        )
      end

      template "/etc/init/#{new_resource.name}.conf" do
        source 'mule.conf.erb'
        cookbook 'mule'
        mode 0644
        variables(
        user: new_resource.user,
        group: new_resource.group,
        name: new_resource.name
        )
      end
    end
    
    # Look for a value in given array.
    # If not found, push the default value in the arrey
    # If found, does nothing
    # If default is nil, look_for value will be used as default value
    def set_value_unless_exists(array, look_for, default=nil)
      if !array.join.include? look_for
        array.push(default.nil? ? look_for : default)
      end
    end

    def update_wrapper
      if new_resource.wrapper_defaults
        
        # Make a new array instead of modifying wrapper_additional array
        # Otherwise Chef may throw an ImmutableAttributeModification exception as we try to modify a node attribute
        wrapper_additional_final = new_resource.wrapper_additional.dup
        
        set_value_unless_exists(wrapper_additional_final, '-Djava.net.preferIPv4Stack=', '-Djava.net.preferIPv4Stack=TRUE')
        set_value_unless_exists(wrapper_additional_final, '-Dmvel2.disable.jit=', '-Dmvel2.disable.jit=TRUE')
        set_value_unless_exists(wrapper_additional_final, '-XX:+HeapDumpOnOutOfMemoryError')
        set_value_unless_exists(wrapper_additional_final, '-XX:+AlwaysPreTouch')
        set_value_unless_exists(wrapper_additional_final, '-XX:+UseParNewGC')
        set_value_unless_exists(wrapper_additional_final, '-Dorg.glassfish.grizzly.nio.transport.TCPNIOTransport.max-receive-buffer-size=', '-Dorg.glassfish.grizzly.nio.transport.TCPNIOTransport.max-receive-buffer-size=1048576')
        set_value_unless_exists(wrapper_additional_final, '-Dorg.glassfish.grizzly.nio.transport.TCPNIOTransport.max-send-buffer-size=', '-Dorg.glassfish.grizzly.nio.transport.TCPNIOTransport.max-send-buffer-size=1048576')
        set_value_unless_exists(wrapper_additional_final, '-XX:PermSize=', '-XX:PermSize=256m')
        set_value_unless_exists(wrapper_additional_final, '-XX:MaxPermSize=', '-XX:MaxPermSize=256m')
        set_value_unless_exists(wrapper_additional_final, '-XX:NewSize=', '-XX:NewSize=512m')
        set_value_unless_exists(wrapper_additional_final, '-XX:MaxNewSize=', '-XX:MaxNewSize=512m')
        set_value_unless_exists(wrapper_additional_final, '-XX:MaxTenuringThreshold=', '-XX:MaxTenuringThreshold=8')
      end

      template "#{new_resource.home}/conf/wrapper.conf" do
        source 'wrapper.conf.erb'
        cookbook 'mule'
        mode 0644
        variables(
        wrapper_additional: wrapper_additional_final,
        init_heap_size: new_resource.init_heap_size,
        max_heap_size: new_resource.max_heap_size
        )
        action :create
        notifies :restart, "service[#{new_resource.name}]"
      end
    end

    def start_service
      service new_resource.name do
        action [:start, :enable]
      end
    end

    def install_license
      execute "copy license for #{new_resource.name}" do
        command <<-EOH
                    cp #{new_resource.source}/#{new_resource.license} /tmp/#{new_resource.license}
                    chown #{new_resource.user}:#{new_resource.group} /tmp/#{new_resource.license}
        EOH
        only_if "[ -e #{new_resource.source}/#{new_resource.license} ]"
      end

      execute "install license for #{new_resource.name}" do
        user new_resource.user
        group new_resource.group
        cwd new_resource.home
        live_stream true
        command "#{new_resource.home}/bin/mule -installLicense /tmp/#{new_resource.license}"
        only_if "[ -e /tmp/#{new_resource.license} ]"
      end
    end

    def run_amc_setup
      execute "run amc setup for #{new_resource.name}" do
        user new_resource.user
        group new_resource.group
        cwd new_resource.home
        live_stream true
        command "#{new_resource.home}/bin/amc_setup -H #{new_resource.amc_setup} #{new_resource.name}"
        not_if "[ -e #{new_resource.home}/.mule/.agent/keystore.jks ]"
      end
    end
  end
end
