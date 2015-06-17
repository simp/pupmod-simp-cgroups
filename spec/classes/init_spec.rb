require 'spec_helper'

describe 'cgroups' do

  describe 'On a Redhat OS' do
    let(:facts) { {
        :osfamily => 'RedHat',
      } }
    it { should create_class('cgroups') }
    it { should compile.with_all_deps }
  end

end
