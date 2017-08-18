name             'mule'
maintainer       'Reed McCartney'
maintainer_email 'reed@hoegg.software'
license          'Apache License, Version 2.0'
description      'Installs/Configures Mule ESB'
long_description 'Installs/Configures Mule ESB'
version          '0.8.5'

supports 'ubuntu'
supports 'centos'
supports 'debian'
supports 'raspbian'

depends 'compat_resource'

source_url 'https://github.com/hoeggsoftware/mule-cookbook' if respond_to?(:source_url)
issues_url 'https://github.com/hoeggsoftware/mule-cookbook/issues' if respond_to?(:issues_url)
