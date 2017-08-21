module Mule
  module AppHelper
    
    # Deploy an application by simply copying via remote_file the app archive into
    # the given Mule instance apps folder. Does not check for deployment success
    def deploy_app(mule_home, app_archive_src, app_name, version)
      dest_archive_name = _app_full_name(app_name, version) + ::File.extname(app_archive_src)
      remote_file ::File.join(mule_home, "apps", dest_archive_name) do
        source ::File.join("file://", File.absolute_path(app_archive_src))
        owner ::File.stat(File.join(mule_home, "apps")).uid
        group ::File.stat(File.join(mule_home, "apps")).gid
        mode '0640'
        action :create
      end    
    end
    
    # Undeploy an app by simply deleting its anchor. Does not check for undeployment success.
    def undeploy_app(mule_home, app_name)
       file _anchor_path(mule_home, app_name, version) do
         action :delete
       end
    end
    
    # Refresh an app by simply performing a touch on the app mule-config.xml file
    # does not re-copy the application archive into apps folder 
    def refresh_app(mule_home, app_name, version)
      app_mule_config = ::File.join(_app_path(mule_home, app_name, version), "mule-config.xml")
      file app_mule_config do
        action :touch
      end
    end
    
    # Retrieve deployed versions of an application
    # Versions are retrieved using anchors and retrieve
    # the bit of string between -anchor.txt
    def get_deployed_versions(mule_home, app_name)
      versions = []
      Dir["#{mule_home}/apps/#{app_name}-*-anchor.txt"].each do |anchor_path|
        
        # This a potential version because we may have
        # an app named "my-app-1.0.0" and another "my-app-with-butter-1.1.0"
        # but we don't want "butter-1.1.0" to be recognized as a version
        potential_version = File.basename(anchor_path).chomp("-anchor.txt").sub(app_name+"-", "")  # remove "app-name-" and "-anchor.txt"
        versions << potential_version if _is_app_version?(potential_version)
      end
      
      return versions
    end
    
    # check if a piece of string can be interpreted as an app version
    # TODO improve this a bit... for now only check if version starts with a digit 0-9
    def _is_app_version?(potential_version)
      return (potential_version =~ /\d/) == 0
    end
    
    # retrieve deployed instances versions of an application
    # return an array of application versions found
    def is_app_deployed?(mule_home, app_name, version)
      return File.file?( _anchor_path(mule_home, app_name, version))
    end
    
    # check if an app is undeployed by checking for its directory to exists
    def is_app_undeployed?(mule_home, app_name, version)
      return !Dir.exist?(_app_path(mule_home, app_name, version))
    end
    
    def ensure_app_deployed(mule_home, app_name, version, timeout=60000, check_period=1000)
      # Define this in a ruby_block to ensure check is performed during convergence, duh !
      ruby_block "Ensure app #{app_name} version #{version} deployed for #{mule_home}" do
        block do
          deployed = wait_for_true(timeout, check_period) do
            is_app_deployed?(mule_home, app_name, version)
          end
          raise "Cannot deploy application: #{app_name} for Mule instance #{mule_home}. Check Mule logs for details." unless deployed
        end
      end
    end
    
    def ensure_app_undeployed(mule_home, app_name, version, timeout=60000, check_period=1000)
      ruby_block "Ensure #{app_name}  version #{version} undeployed for #{mule_home}" do
        block do
          undeployed = wait_for_true(timeout, check_period) do
            is_app_undeployed?(mule_home, app_name, version)
          end
          raise "Cannot undeploy application: #{app_name} for Mule instance #{mule_home}. Check Mule logs for details." unless undeployed
        end
      end
    end
    
    def ensure_app_refreshed(mule_home, app_name, version, refreshed_at, timeout=60000, check_period=1000)
      ruby_block "Ensure #{app_name} version #{version} refreshed for #{mule_home}" do
        block do
          # check for modification time
          anchor = _anchor_path(mule_home, app_name, version)
          refreshed = wait_for_true(timeout, check_period) do
            File.stat(anchor).mtime > refreshed_at
          end
          raise "Cannot refresh application: #{app_name} for Mule instance #{mule_home}. Check Mule logs for details." unless refreshed
        end
      end
    end
    
    # Undeploy all versions for this app
    def undeploy_versions(mule_home, app_name, ensure_undeploy, versions=[], timeout=60000)
      versions.each { |v_to_undeploy|
        standalone_app "#{app_name}-#{v_to_undeploy}" do
          app_name app_name
          version v_to_undeploy
          mule_home mule_home
          ensure_deploy ensure_undeploy
          deploy_timeout timeout
          undeploy_other_versions false
          action :undeploy
        end
      }
    end
    
    def _anchor_path(mule_home, app_name, version)
      return ::File.join(mule_home, "apps", _app_full_name(app_name, version)+"-anchor.txt")
    end
    
    def _app_path(mule_home, app_name, version)
      return ::File.join(mule_home, "apps", _app_full_name(app_name, version))
    end
    
    def _app_full_name(short_name, version)
      return short_name + "-" + version
    end
    
    # will yield block periodically and return whenever expected == yield(block)
    # or timeout occur. When timeout, return expected == yield(block)
    def wait_for_true(timeout=60000, check_period=5000)
      start_time = Time.now
      begin
         return true if yield == true
         sleep(check_period/1000)
      end while((Time.now - start_time)*1000 <= timeout)      
      return yield == true
    end   
  end
end