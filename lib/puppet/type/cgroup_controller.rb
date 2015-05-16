module Puppet
  newtype(:cgroup_controller) do
    @doc = <<-EOM
      Manage CGroup controller settings.

      The CGroup in question must already be mounted.

      Example:

      # Set the cpu shares for the 'default' cgroup to '1000'
      cgroup_controller { 'cpu/default/cpu.shares': value => '1000' }
    EOM

    def initialize(args)
      super(args)

      if self[:tag] then
        self[:tag] += ['cgroups']
      else
        self[:tag] = ['cgroups']
      end
    end

    def finish
      # Do stuff here if necessary after the catalog compiles.

      super
    end

    newparam(:name, :namevar => :true) do
      desc "The target attribute to manipulate under the group. If the path to the attribute is not absolute, it will be inferred from the operating system."

      osfamily = Facter.value(:osfamily)
      munge do |value|
        if value[0].chr != '/' then
          case osfamily
          when "RedHat"
            value == :unknown ? value = "/cgroup/#{resource[:name]}" : value = "/cgroup/#{value}"
          else fail Puppet::Error, "Operating system family #{osfamily} not supported"
          end
        end
      end
    end

    newproperty(:value) do
      desc "The value to which the :name should be set under :group."
    end

    autorequire(:cgroup) do
      walk_back = self[:name].split('/')

      to_req = []
      while not walk_back.empty? do
        entry = walk_back.join('/')
        not entry.empty? and to_req << entry
        walk_back.pop
      end

      to_req
    end

    autorequire(:service) do
      ['cgconfig']
    end
  end
end
