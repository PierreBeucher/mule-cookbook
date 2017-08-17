module Mule
  module AppHelper
    
    # Deploy an application by simply copying the app archive into
    # the given Mule instance apps folder. Does not check for deployment success
    def deploy_app(mule_home, app_archive_src, app_name=nil)
      final_app_name = app_name.nil? ? File.basename(app_archive_src, "*.rb") : app_name
      app_archive_ext = File.extname(app_archive_src)
      app_archive_name = final_app_name + app_archive_ext
      app_archive_dest = File.join(mule_home, "apps", app_archive_name)
      
      FileUtils.copy_file(app_archive_src, app_archive_dest)
      
      # Ensure the archive is readable by Mule runtime user
      File.chown(File.stat(File.join(mule_home, "apps")).uid, nil, app_archive_dest)
      File.chmod(0640, app_archive_dest)      
    end
    
    # Undeploy an app by simply deleting its anchor. Does not check for undeployment success.
    def undeploy_app(mule_home, app_name)
      File.delete(_anchor_path(mule_home, app_name))
    end
    
    # Refresh an app by simply performing a touch on the app mule-config.xml file
    # does not re-copy the application archive into apps folder 
    def refresh_app(mule_home, app_name)
      app_mule_config = File.join(mule_home, "apps", app_name, "mule-config.xml")
      raise "Cannot refresh #{app_name} for instance #{mule_home}, application not deployed." if !File.file?(app_mule_config)
      file app_mule_config do
        action :touch
      end
    end
    
    def ensure_app_deployed(mule_home, app_name, timeout=60000, check_period=1000)
      deploy_ok = wait_for_app_deploy(mule_home, app_name, true, timeout, check_period)
      raise "Cannot deploy application: #{app_name} for Mule instance located at #{mule_home}. Check Mule logs for details." if !deploy_ok
    end
    
    def ensure_app_undeployed(mule_home, app_name, timeout=60000, check_period=1000)
      undeployed = wait_for_app_deploy(mule_home, app_name, false, timeout, check_period)
      raise "Cannot undeploy application: #{app_name} for Mule instance located at #{mule_home}. Check Mule logs for details." if !undeployed
    end
    
    def _anchor_path(mule_home, app_name)
      return File.join(mule_home, "apps", app_name+"-anchor.txt")
    end
    
    # Wait for an application to be in a deployment state
    # return true if application is found in expected state at the end of timeout, false otherwise
    # App state is determined by the existence of an anchor file
    def wait_for_app_deploy(mule_home, app_name, deployed, timeout, check_period)
      anchor = _anchor_path(mule_home, app_name)
      start_time = Time.now
      begin
         return true if deployed == File.file?(anchor)
         sleep(check_period/1000)
      end while((Time.now - start_time)*1000 <= timeout)      
      return deployed == File.file?(anchor)
    end
  
  end
end