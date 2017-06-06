provides :mule_instance, platform: 'debian'

property :name, String, name_attribute: true, required: true
property :archive_name, String
property :version, String, default: '3.8.0'
property :user, String, default: 'mule'
property :group, String, default: 'mule'
property :enterprise_edition, [TrueClass, FalseClass], default: false
property :license, String, default: ''
property :source, String, default: '/tmp/mule'
property :home, String, default: '/usr/local/mule-esb'
property :env, String, default: 'test'
property :init_heap_size, String, default: '1024'
property :max_heap_size, String, default: '1024'
property :wrapper_additional, Array, default: lazy{ [] }
property :wrapper_defaults, [TrueClass, FalseClass], default: true
property :amc_setup, String, default: ''

action :create do
      
    if new_resource.enterprise_edition
        install_enterprise_runtime
        update_wrapper

        if !new_resource.license.empty?
            install_license
        end

        if !new_resource.amc_setup.empty?
            run_amc_setup
        end

        install_systemd_service

        start_service
    else
        install_community_runtime
        update_wrapper

        install_systemd_service

        start_service
    end
end

action_class.class_eval do
  include Mule::Helper
end
