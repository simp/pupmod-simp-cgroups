module Puppet
  newtype(:cgsnapshot) do
    @doc = <<-EOM
      Save the currently running cgroups.

      Uses cgsnapshot and will autorequire all necessary cgroup types.
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

    newparam(:name,
      :namevar => true,
      :array_matching => :first,
      :parent => Puppet::Parameter::Path
    ) do
      desc = <<-EOM
        The target file to which to output the contents of cgsnapshot.
      EOM
    end

    newparam(:blacklist,
      :array_matching => :first,
      :parent => Puppet::Parameter::Path
    ) do
      desc = <<-EOM
        The blacklist file from which to read.
      EOM

      defaultto "/etc/cgsnapshot_blacklist.conf"
    end

    newproperty(:ensure) do
      newvalues(:sync,:ignore)
      defaultto 'sync'

      def retrieve
        provider.retrieve
      end

      def insync?(is)
        provider.insync?(is)
      end

      def sync
        provider.sync
      end

      def change_to_s(currentvalue, newvalue)
        case newvalue
          when :sync then return "CGSnapshot saved to #{resource[:name]}."
          else return "Ignoring CGSnapshot settings."
        end
      end
    end

    # This is here to try and figure out how to only search the catalog once in
    # the autorequire.
    @deps = {
      :cgroup => nil,
      :cgroup_controller => nil,
      :cgroup_perm => nil
    }

    @deps.each_key do |type|
      autorequire(type) do
        toreq = []
        catalog.resources.find_all do |r|
          r.is_a?(Puppet::Type.type(type)) and toreq << r[:name]
        end
        toreq
      end
    end

    autorequire(:cgsnapshot_blacklist) do
      [self[:blacklist]]
    end

    autorequire(:service) do
      ['cgconfig']
    end
  end
end
