module Puppet
  newtype(:cgroup_perm) do
    @doc = <<-EOM
      Set CGroup group permissions.
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

    newparam(:name, :namevar => :true, :array_matching => :first) do
      desc "The full path to the target upon which to act."
    end

    newproperty(:task_uid) do
      desc 'The owner of the control group tasks.'
  
      def retrieve
        provider.retrieve[:task_uid]
      end

      def insync?(is)
        if @should.to_s.strip =~ /^\d+$/ then
          is.to_s == @should.to_s
        else
          Puppet::Util.uid(is) == Puppet::Util.uid(@should.to_s)
        end
      end
    end

    newproperty(:task_gid) do
      desc 'The group owner of the control group tasks.'
  
      def retrieve
        provider.retrieve[:task_gid]
      end

      def insync?(is)
        if @should.to_s.strip =~ /^\d+$/ then
          is.to_s == @should.to_s
        else
          Puppet::Util.gid(is) == Puppet::Util.gid(@should.to_s)
        end
      end
    end
  
    newproperty(:admin_uid) do
      desc 'The administrative owner of the control group.'
  
      def retrieve
        provider.retrieve[:admin_uid]
      end
  
      def insync?(is)
        if @should.to_s.strip =~ /^\d+$/ then
          is.to_s == @should.to_s
        else
          Puppet::Util.uid(is) == Puppet::Util.uid(@should.to_s)
        end
      end
    end

    newproperty(:admin_gid) do
      desc 'The administrative group owner of the control group.'
  
      def retrieve
        provider.retrieve[:admin_gid]
      end

      def insync?(is)
        if @should.to_s.strip =~ /^\d+$/ then
          is.to_s == @should.to_s
        else
          Puppet::Util.gid(is) == Puppet::Util.gid(@should.to_s)
        end
      end
    end

    autorequire(:user) do
      [
        self[:task_uid],
        self[:admin_uid]
      ]
    end

    autorequire(:group) do
      [
        self[:task_gid],
        self[:admin_gid]
      ]
    end

    autorequire(:cgroup) do
      walk_back = provider.get_path.split('/')

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
      must_supply_one = [:task_uid, :task_gid, :admin_uid, :admin_gid]

      found = false
      must_supply_one.each do |var|
        self[var] and found = true and break
      end

      raise(ArgumentError,"You must supply one of '#{must_supply_one.join(', ')}'") if not found
    end
  end
end
