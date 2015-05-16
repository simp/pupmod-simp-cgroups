module CGroups
  module Rule

    class Error < Exception; end
  
    public
  
    def self.assign_order(rule)
      rule = rule.split(/\s+/)
  
      name,process = rule[0].split(':')
      controllers = rule[1]
  
      order = 1000
      case
        when name[0].chr == '*' then order = 99
        when name[0].chr == '@' then order = 79
        else order = 49
      end
  
      not process.nil? and order -= 9
      controllers[0].chr == '*' and order -= 1
  
      return "#{order}#{rule}"
    end
  
    private
  end
end
