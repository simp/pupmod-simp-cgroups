require 'spec_helper_acceptance'

test_name 'cgroups class'

describe 'cgroups class' do
  let(:manifest) {
    <<-EOS
      include '::cgroups'
    EOS
  }

  # We need this for our tests to run properly!
  on 'client', puppet('config set stringify_facts false')

  context 'with defaults' do

    # Using puppet_apply as a helper
    it 'should work with no errors' do
      apply_manifest(manifest, :catch_failures => true)
    end

    it 'should be idempotent' do
      apply_manifest(manifest, {:catch_changes => true})
    end

    required_packages = ['libcgroup','libcgroup-pam']

    required_packages.each do |pkg|
      describe package(pkg) do
        it { is_expected.to be_installed }
      end
    end

    required_services = ['cgred','cgconfig']

    required_services.each do |svc|
      describe service(svc) do
        it { is_expected.to be_enabled }
        it { is_expected.to be_running }
      end
    end

    describe group('cgred') do
      it { is_expected.to exist }
    end

    describe file(%(/cgroup/cpu)) do
      it { is_expected.to be_directory }
    end
  end
end
