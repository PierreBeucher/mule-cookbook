require 'spec_helper'

describe file('/usr/local/mule-esb-test/apps/mule-test-app-1.0-anchor.txt') do
  it { should_not exist }
end

describe file('/usr/local/mule-esb-test/apps/mule-test-app-1.1-anchor.txt') do
  it { should be_file }
end

describe file('/usr/local/mule-esb-test/apps/mule-test-app-refresh-1.0-anchor.txt') do
  it { should be_file }
end

describe file('/usr/local/mule-esb-test/apps/mule-test-app-undeploy-1.0-anchor.txt') do
  it { should_not exist }
end