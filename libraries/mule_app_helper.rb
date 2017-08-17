module Mule
  module AppHelper
    
    def deploy_app(instance_home, app_archive_src, app_name=nil)
      final_app_name = app_name.nil? ? File.basename(app_archive_src, "*.rb") : app_name
      app_archive_ext = File.extname(app_archive_src)
      app_archive_name = final_app_name + app_archive_ext
      app_archive_dest = File.join(instance_home, "apps", app_archive_name)
      
      log "Deploy app: " + final_app_name + " from " + app_archive_src + "to " + app_archive_dest
      FileUtils.copy_file(app_archive_src, app_archive_dest)
      
      # Ensure the archive is readable by Mule runtime use
      File.chown(File.stat(File.join(instance_home, "apps")).uid, nil, app_archive_dest)
      File.chmod(0640, app_archive_dest)      
    end
    
    # Check if an app is properly deployed, i.e. {app_name}-anchor.txt exists
    # if timeout not specified or <= 0, check once and return immediatly
    # otherwise will check periodically until timeout
    # timeout and check_period: milliseconds
    def check_app_deployed(instance_home, app_name, timeout=0, check_period=1000)
      app_anchor_path = File.join(instance_home, "apps", app_name + "-anchor.txt")
      start_time = Time.now
      log "Check for file: " + app_anchor_path
      begin
         return true if File.file?(app_anchor_path)
         sleep(check_period/1000)
         log "Checking again for " + app_anchor_path
      end while((Time.now - start_time)*1000 <= timeout)
      
      return File.file?(app_anchor_path)
    end
    
    def ensure_app_deployed(instance_home, app_name, timeout=0, check_period=1000)
      deploy_result = check_app_deployed(instance_home, app_name, timeout, check_period)
      raise "Cannot deploy application: #{app_name} for Mule instance located at #{instance_home}. Check Mule logs for details." if !deploy_result
    end
    
  end
end