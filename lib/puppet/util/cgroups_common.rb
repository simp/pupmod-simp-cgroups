module CGroups
  module Common

    class Error < Exception; end

    @system_cgroups = lambda{
      retval = nil
      if File.readable?('/proc/cgroups') then
        # We set this just in case we don't find any cgroups.
        retval = :none
  
        # Get all of the supported cgroups from /proc/cgroups...
        retval = File.read('/proc/cgroups').split("\n").map { |x|
          # And snag the first word from each column...
          x = x.split.first.strip
        }.delete_if {|y|
          # And get rid of anything that is a comment.
          y[0].chr == '#'
        }
      end
      retval
    }.call
  
    def self.supported_cgroup?(cgroup)
      @system_cgroups == :none and false
      @system_cgroups.include?(cgroup)
    end
  
    def self.system_cgroups
      Array(@system_cgroups)
    end
  end
end
