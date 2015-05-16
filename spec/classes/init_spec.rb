require 'spec_helper'

describe 'cgroups' do
  it { should create_class('cgroups') }
  it { should compile.with_all_deps }
end
