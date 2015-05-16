Puppet::Type.type(:cgsnapshot).provide(:snap) do

  confine :operatingsystem => [:redhat, :centos]

  commands :cgsnapshot => '/bin/cgsnapshot'

  @@cgsnapshot_classvars = {
    # This is just so we don't do this more than once for multiple calls.
    :cgrules => ''
  }

  def retrieve
    # This is the first thing that happens, so we buffer this here.
    if @@cgsnapshot_classvars[:cgrules] == '' then
      begin
        @@cgsnapshot_classvars[:cgrules] = execute("#{command(:cgsnapshot)} -s -b #{@resource[:blacklist]}")
      rescue Exception => e
        # If we got here, then we didn't get anything valid returned.
        Puppet.warning("Cgsnapshot failed, skipping. Message: #{e}")
        @@cgsnapshot_classvars[:cgrules] = nil
      end
    end

    current_rules = ""
    if File.readable?(@resource[:name]) then
      File.open(@resource[:name],'r') do |fh|
        current_rules = fh.read.strip
      end
    end

    current_rules
  end

  def insync?(is)
    # If this is the case, we couldn't retrieve them.
    if @@cgsnapshot_classvars[:cgrules].nil? then
      return true
    end
    @@cgsnapshot_classvars[:cgrules] &&= @@cgsnapshot_classvars[:cgrules].strip

    @@cgsnapshot_classvars[:cgrules] == is
  end

  def sync
    File.open(@resource[:name],'w') do |fh|
      fh.puts(@@cgsnapshot_classvars[:cgrules])
    end
    File.chmod(0644,@resource[:name])
  end
end
