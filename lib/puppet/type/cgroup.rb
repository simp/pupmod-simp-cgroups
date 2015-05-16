module Puppet
  newtype(:cgroup) do
    @doc = <<-EOM
      Add a cgroup if it does not already exist.

      Examples:

      # A regular mount:
      cgroup { 'cpu': }

      # A mount in a strange location:
      cgroup { 'tmp/cpu': }

      # A submount:
      cgroup { 'cpu/default': }

      # Deleting a submount:
      cgroup { 'cpu/default': ensure => 'absent' }
    EOM

    require Pathname(__FILE__).dirname + "../util/cgroups_common.rb"

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
      defaultto :present

      newvalue :present do
        provider.create
      end

      newvalue :absent do
        provider.destroy
      end
    end

    newparam(:name, :namevar => true) do
      desc = <<-EOM
        The cgroup name.

        CGroup name validity is based on the content of /proc/cgroups on the target system.

        For base mount points, you *must* make the last entry in the name path a valid cgroup type.
      EOM
    end

    newparam(:target) do
      desc "The cgroup target. If not specified, puppet will attempt to
            choose something sane for your operating system based on :name."

      defaultto :unknown

      osfamily = Facter.value(:osfamily)
      munge do |value|
        if value == :unknown or value[0].chr != '/' then
          case osfamily
          when "RedHat"
            value == :unknown ? value = "/cgroup/#{resource[:name]}" : value = "/cgroup/#{value}"
          else
            fail Puppet::Error, "Operating system family #{osfamily} not supported"
          end
        end

        # This is a bit of hackery but, if anything in the path is a valid
        # CGroup name, then go ahead and accept. Not ideal, but keeps the user
        # interface less cluttered.
        found_cgroup = false
        value.split('/').each do |cgroup|
          CGroups::Common.supported_cgroup?(cgroup) and found_cgroup = true and break
        end

        if not found_cgroup then
          fail Puppet::Error, "CGroup supplied in :name must be one of '#{CGroups::Common.system_cgroups.join(", ")}' not #{value}"
        end

        value
      end

      validate do |value|
        unless value == :unknown or Puppet::Util.absolute_path?(value)
          fail Puppet::Error, "CGroup mount paths must be fully qualified, not '#{value}'"
        end
      end
    end

    autorequire([:cgroup, :file]) do
      walk_back = self[:target].split('/')

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
