module Puppet
  newtype(:cgroup_rule) do
    @doc = <<-EOM
      Manage cgroup rules in /etc/cgrules.conf.

      See cgrules.conf(5) for more details.
    EOM

    require Pathname(__FILE__).dirname + "../util/cgroups_rule.rb"
    require Pathname(__FILE__).dirname + "../util/cgroups_common.rb"

    def initialize(args)
      super(args)

      if self[:tag] then
        self[:tag] += ['cgroups']
      else
        self[:tag] = ['cgroups']
      end

      if self[:notify] then
        self[:notify] += ['Service[cgred]']
      else
        self[:notify] = ['Service[cgred]']
      end
    end

    def finish
      # Do stuff here if necessary after the catalog compiles but before the
      # provider runs.

      super
    end

    def self.title_patterns
        [ [/^(.+)$/,[
          [ :user, lambda{|x| x}],
          [ :process, lambda{|x| x.nil? and x = :unknown or x}],
          [ :controllers, lambda{|x| x}]
        ] ] ]
    end

    newparam(:name, :namevar => false) do
      desc "An arbitrary, but unique, name for the resource."
    end

    newparam(:user) do
      desc <<-EOM
        The user or group name on the system. Use the standard user:process
        syntax for cgrules.conf to bind a process to the rule."
      EOM

      isnamevar
      isrequired
    end

    newparam(:process) do
      desc "The optional process name or full command path of a process"
      isnamevar

      # Ok, this is technically effected up in title_patterns but I'm putting
      # it here to not look like magic. self.title_patterns completely ignores
      # 'defaultto' which I believe is a bug.
      defaultto :unknown
    end

    newparam(:comment) do
      desc "A helpful comment for you entry in the target file."

      munge do |value|
        if not value[0].chr == '#' then
          value = "# #{value}"
        end

        value
      end
    end

    newparam(:controllers) do
      desc "Array of controllers or * for all mounted controllers"
      isnamevar
      isrequired

      munge do |value|
        Array(value).join(',')
      end

      validate do |value|
        if not (Array(value) - CGroups::Common.system_cgroups).empty? then
          fail Puppet::Error, "Controllers must be included in '#{CGroups::Common.system_cgroups.join(", ")}"
        end
      end
    end

    newparam(:order) do
      desc <<-EOM
        The numeric order in which items should be arranged.
        The first match wins when combined alphabetically with the
        corresponding parameters.

        The defaults are:

        - Users + Processes
        - Users
        - Groups + Processes
        - Groups
        - Wildcards
      EOM

      newvalues(/^(\d+|UNKNOWN)$/)

      defaultto('UNKNOWN')

      # This just makes it easier to sort later.
      munge do |value|
        if value == 'UNKNOWN' then
          newline = resource[:user]
          newline += ":#{resource[:process]}" if resource[:process] != :unknown
          newline += " #{resource[:controllers]}"
          value = CGroups::Rule.assign_order(newline)
        else
          Array(value).join(',')
        end

        value
      end # End munge
    end

    # Destination and purge are order dependent on each other!
    # Do NOT reorder them.
    newproperty(:destination) do
      desc "The path relative to the controller hierarchy"

      validate do |value|
        if value[0].chr == '/' then
          raise ArgumentError,"The destination cannot start with '/'."
        end
      end

      def change_to_s(currentvalue, newvalue)
        if currentvalue == :comment then
          return "Updating due to comment change."
        else
          super
        end
      end
    end

    newproperty(:purge) do
      desc <<-EOM 
        Whether or not to remove unknown records.

        If you choose not to purge, then ordering will be best guess based on
        how the rules are written in the existing file.

        If *any* resource set this to :false, then the file will not be purged.
      EOM

      defaultto :true

      newvalues(:true,:false)

      def change_to_s(currentvalue, newvalue)
        return "Purging CGroup rules"
      end
    end

    autorequire(:cgroup) do
      walk_back = self[:destination].split('/')

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

    validate do
      must_supply = [:user, :controllers, :destination]

      found = true
      must_supply.each do |var|
        not self[var] or self[var].empty? and found = false and break
      end

      raise(ArgumentError,"You must supply all of '#{must_supply.join(', ')}'") if not found
    end
  end
end
