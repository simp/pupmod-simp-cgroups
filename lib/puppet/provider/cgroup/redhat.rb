Puppet::Type.type(:cgroup).provide(:redhat) do

  defaultfor :operatingsystem => [:centos, :redhat]

  confine :osfamily => :redhat

  commands :umount => '/bin/umount'
  commands :mount => '/bin/mount'
  commands :rmdir => '/bin/rmdir'

  def initialize(*args)
    super(*args)
  end

  def exists?

    @target = resource[:target]

    # This tells us if we're a submount or not.
    @submount = false

    retval = false

    File.readlines('/proc/mounts').each do |line|
      # If we're trying to mount something on top of an existing CGroup, well,
      # that's bad.
      if line =~ /^.* (#{@target}\/.+) cgroup / then
        raise Puppet::Error, "Cannot create '#{@target}'. The system appears to have a cgroup mounted at '#{$1}'."
      end

      # We have to deconstruct the target and see if the path that we're
      # looking for is actually a subdirectory of a mount.
      walk_back = @target.split('/')
      while not walk_back.empty? do
        entry = walk_back.join('/')
        if line =~ /^.+ #{entry} cgroup / then
          # Here, we found a proper cgroup mount.
          retval = true
          if entry != @target then
            # Here, we discovered that it was a submount!
            Puppet.debug("#{@target} appears to be a submount of #{entry}.")
            @submount = true
            # Here, we check to see if the submount exists.
            if not File.directory?(@target) then
              retval = false
            end
          end
          break
        end
        walk_back.pop
      end
      break if retval
    end 

    Puppet.debug("Returning #{retval} for #{@target}")
    retval
  end

  def create
    Puppet.debug("Making directory: #{@target}")
    begin
      FileUtils.mkdir_p(@target, :mode => 0755)
    rescue
      fail Puppet::Error,"Could not create cgroup '#{@target}'"
    end

    if not @submount then
      Puppet.debug("Mounting #{@target} as type #{resource[:name]}")
      execute("#{command(:mount)} -t cgroup -o #{resource[:name]} cgroup #{@target}")
    end
  end

  def destroy
    if @submount then
      Puppet.debug("Deleting submount: #{@target}")
      begin
        FileUtils.rmdir(@target)
      rescue
      fail Puppet::Error,"Could not remove cgroup '#{@target}', tasks are probably still assigned."
      end
    else
      Puppet.debug("Unmounting: #{@target}")
      execute("#{command(:umount)} #{@target}")
    end
  end

  private
end
