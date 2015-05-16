module CGroups
  module Config_Parser

    class Error < Exception; end
  
    public
  
    # Read the cgconfig.conf file and return as an array:
    #   - catalog version number
    #   - the material before the target block (if any)
    #   - target block to manipulate
    #   - the rest of the file (if any)
    def self.read(section,config)
      File.readable?(config) or
        Puppet.warning("Could not open '#{config}'. The system will not set this value at boot time.") and
        raise Error
  
      cgconfig = {
        :version => nil,
        :header  => nil,
        :target  => nil,
        :footer  => nil
      }
  
      content = nil
  
      File.open(config,'r'){ |fh| content = fh.read.split("\n") }
  
      # The first line must be our header, if it's not, we'll rewrite the whole darn thing.
      if content.shift =~ /# Generated from Puppet catalog: \(\d+\)/ then
        cgconfig[:version] = $1
      else
        Puppet.warning("Incorrect header in '#{config}', writing new file")
        return cgconfig
      end
  
      # TODO: Finish me. Keeping around as an example of how to do this.
    end
      
    private
  end
end
