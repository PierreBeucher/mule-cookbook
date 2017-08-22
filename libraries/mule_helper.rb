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
    
    def install_initd_service
      template "/etc/default/#{new_resource.name}" do
        owner new_resource.user
        group new_resource.group
        source 'mule.erb'
        cookbook 'mule'
        mode 0644
        variables(
          mule_home: new_resource.home,
          mule_user: new_resource.user,
          mule_env:  new_resource.env
        )
      end
  
      template "/etc/init.d/#{new_resource.name}" do
        source 'mule.init_d.erb'
        cookbook 'mule'
        mode 0755
        variables(
          mule_env: new_resource.env,
          mule_user: new_resource.user,
          mule_home: new_resource.home
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
    
    
    def setup_raspbian_armhf_wrapper(wrapper_source='https://wrapper.tanukisoftware.com/download/3.5.32/wrapper-linux-armhf-32-3.5.32.tar.gz', wrapper_version='3.5.32')
      download_unpack_wrapper(wrapper_source, "#{new_resource.home}/additional_wrapper")
      
      wrapper_os = 'linux'
      wrapper_arch = 'armhf'
      wrapper_bits = '32'
      wrapper_name = "wrapper-#{wrapper_os}-#{wrapper_arch}-#{wrapper_bits}-#{wrapper_version}"
      
      add_java_wrapper("#{new_resource.home}/additional_wrapper/#{wrapper_name}", wrapper_os, wrapper_arch, wrapper_bits, wrapper_version, true)
      add_local_machine_mule_dist_arch('armhf') 
    end    
    
    # Add a Java wrapper so and launch script to the current installation
    # wrapper_home is the path to the wrapper package
    # wrapper_type is the wrapper os and arch, such as inux-armhf-32
    # override_jar : whether to override any existing wrapper-{version}.jar by the one available in the resource
    def add_java_wrapper(wrapper_home, wrapper_os, wrapper_arch, wrapper_bits, wrapper_version, override_jar=false)
      
      wrapper_type = "#{wrapper_os}-#{wrapper_arch}-#{wrapper_bits}"
      
      remote_file "#{new_resource.home}/lib/boot/libwrapper-#{wrapper_type}.so" do
        source "file://#{wrapper_home}/lib/libwrapper.so"
        owner new_resource.user
        group new_resource.group
        mode '0775'
        notifies :restart, "service[#{new_resource.name}]" 
      end
      
      remote_file "#{new_resource.home}/lib/boot/exec/wrapper-#{wrapper_type}" do
        source "file://#{wrapper_home}/bin/wrapper"
        owner new_resource.user
        group new_resource.group
        mode '0775'
        notifies :restart, "service[#{new_resource.name}]"
      end   
           
      #execute "remove previous wrapper.jar for #{wrapper_version}" do
      #  command "rm #{new_resource.home}/lib/boot/wrapper-*.jar"
      #  only_if { override_jar }
      #end
            
      remote_file "#{new_resource.home}/lib/boot/wrapper-#{wrapper_version}.jar" do
        source "file://#{wrapper_home}/lib/wrapper.jar"
        owner new_resource.user
        group new_resource.group
        mode '0775'
        only_if { override_jar }
        notifies :restart, "service[#{new_resource.name}]"
      end
      
    end
    
    def download_unpack_wrapper(wrapper_source, dest)
      
      directory dest do
        user new_resource.user
        group new_resource.group
        action :create
      end
      
      # Download and add wrapper
      wrapper_archive_name = File.basename(URI.parse(wrapper_source).path)
      wrapper_archive_path = File.join(dest, wrapper_archive_name)
      remote_file wrapper_archive_path do
        source wrapper_source
        user new_resource.user
        group new_resource.group
      end
         
     execute "extract wrapper #{wrapper_archive_name}" do
       command "tar xzvf #{wrapper_archive_name} && touch #{wrapper_archive_name}.extracted"
       cwd dest
       not_if { File.exists?("#{dest}/#{wrapper_archive_name}.extracted") }
     end
     
    end
    
    def add_local_machine_mule_dist_arch(as_dist_arch)
      
      execute 'add local machine dist arch' do
        command 'sed -i \'s/case \"\$PROC_ARCH\" in/case \"\$PROC_ARCH\" in\n\t\t\'$(uname -m)\')\n\t\t\tDIST_ARCH=\"armhf\"\n\t\t\tbreak;;/g\'' + " #{new_resource.home}/bin/mule"
        not_if "grep 'DIST_ARCH=\\\"#{as_dist_arch}\\\"' #{new_resource.home}/bin/mule" 
      end
      
    end
    
  end
end
