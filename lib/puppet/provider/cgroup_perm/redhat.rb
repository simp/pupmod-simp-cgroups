Puppet::Type.type(:cgroup_perm).provide(:redhat) do

  defaultfor :operatingsystem => [:centos, :redhat]

  # Fedora has a different format
  confine :operatingsystem => [:centos, :redhat]
  confine :feature => :posix

  def initialize(args)
    super(args)

    @perm_target = resource[:name]
    @perm_target[0].chr != '/' and @perm_target = "/cgroup/#{resource[:name]}"

    @property_flush = {}
  end

  # This is a super hack define. It was stupid to have getters for
  # everything, so I just made one instead.
  # This returns a hash with all of the expected values in place and you simply
  # have to fetch the one you want.
  # I suppose this works almost like prefetching but without the magic.
  def retrieve
    if not @perm_values then
      if not File.readable?("#{@perm_target}/tasks") then
        raise Puppet::Error, "You do not appear to have a cgroup mounted at '#{@perm_target}'"
      end

      @perm_values = Hash.new

      @perm_values[:task_uid] = File.stat("#{@perm_target}/tasks").uid
      @perm_values[:task_gid] = File.stat("#{@perm_target}/tasks").gid

      admin_uid = []
      admin_gid = []
      Dir.glob("#{@perm_target}/*").each do |file|
        next if not File.file?(file)
        next if file == "#{@perm_target}/tasks"

        admin_uid << File.stat(file).uid
        admin_gid << File.stat(file).gid
      end

      # Setting these to blank in the case of a mixed permissions set
      admin_uid.uniq.size == 1 ? @perm_values[:admin_uid] = admin_uid.first : @perm_values[:admin_uid] = "!!MISMATCH!!"
      admin_gid.uniq.size == 1 ? @perm_values[:admin_gid] = admin_gid.first : @perm_values[:admin_gid] = "!!MISMATCH!!"
    end

    @perm_values
      
  end

  def task_uid=(should)
    @property_flush[:task_uid] = should
  end

  def task_gid=(should)
    @property_flush[:task_gid] = should
  end

  def admin_uid=(should)
    @property_flush[:admin_uid] = should
  end

  def admin_gid=(should)
    @property_flush[:admin_gid] = should
  end

  def flush
    # Here, we go ahead and write the actual values to the cgroups files.
    if @property_flush then
      if @property_flush[:task_uid] or @property_flush[:task_gid] then
        FileUtils.chown(@property_flush[:task_uid],@property_flush[:task_gid],"#{@perm_target}/tasks")
      end

      if @property_flush[:admin_uid] or @property_flush[:admin_gid] then
        Dir.glob("#{@perm_target}/*").each do |file|
          # Skip submounts
          next if not File.file?(file)
          next if file == "#{@perm_target}/tasks"

          FileUtils.chown(@property_flush[:admin_uid],@property_flush[:admin_gid],file)
          # Set the permissions on the actual group appropriately!
          # This matches what the cgconfig daemon actually does (whether or not
          # it is correct)
          FileUtils.chown(@property_flush[:admin_uid],@property_flush[:admin_gid],File.dirname(file))
        end
      end
    end
  end

  def get_path
    @perm_target
  end
end
