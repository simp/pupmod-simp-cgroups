module Puppet
  newtype(:cgsnapshot_blacklist) do
    @doc = <<-EOM
      Add or remove items from the target cgsnapshot_blacklist.conf file

      Examples:

      # Add cpu.shares to the file.
      cgroup { 'cpu.shares': }

      # Remove 'blkio.weight' from the file.
      cgroup { 'blkio.weight': ensure => 'absent' }
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

    ensurable do
      self.defaultvalues
      defaultto :present
    end

    newparam(:name, :namevar => true) do
      desc = <<-EOM
        The value to ensure is/not present in the cgsnapshot_blacklist.conf file.
        This is not checked for validity since cgsnapshot will ignore invalid entries.
      EOM

      validate do |value|
        if value =~ /\// then
          raise Puppet::ParseError,"Blacklist values cannot contain slashes"
        end
      end
    end

    newproperty(:target) do
      desc "The target blacklist file."

      defaultto {
        if @resource.class.defaultprovider.ancestors.include?(Puppet::Provider::ParsedFile) then
          @resource.class.defaultprovider.default_target
        else
          nil
        end
      }
    end
  end
end
