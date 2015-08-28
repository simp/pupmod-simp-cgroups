require 'spec_helper'

describe 'cgroups' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      let(:facts) do
        facts
      end
      context "on #{os}" do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('cgroups') }

        it { is_expected.to contain_package('libcgroup').with_ensure('latest') }
        it { is_expected.to contain_package('libcgroup-pam').with_ensure('latest') }

        it { is_expected.to contain_service('cgred').with_ensure('running') }
        it { is_expected.to contain_service('cgconfig').with_ensure('running') }
      end
    end
  end
end
