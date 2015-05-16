Puppet::Type.type(:cgroup_controller).provide(:redhat) do

  defaultfor :operatingsystem => [:centos, :redhat]

  confine :operatingsystem => [:centos, :redhat]
  confine :feature => :posix

  def initialize(args)
    super(args)
  end

  def value

    not File.exists?(resource[:name]) and raise Puppet::Error,"CGroup target '#{resource[:name]}' does not exist."
    File.read(resource[:name]).chomp
  end

  def value=(should)
    File.open(resource[:name],'w'){ |fh| fh.puts(should) }

    # Ok, this gets a little weird. There are some entries that you just can't
    # set. If you hit one of these, the only way to know is to read the value
    # again and compare.
    should == File.read(resource[:name]).chomp or raise Puppet::Error,"Cannot write value '#{should}' to '#{resource[:name]}'. This may not be a writable target. See CGroups documentation for details."
  end
end
