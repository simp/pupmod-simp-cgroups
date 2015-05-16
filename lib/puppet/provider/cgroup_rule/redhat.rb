Puppet::Type.type(:cgroup_rule).provide(:redhat) do

  require Pathname(__FILE__).dirname + "../../util/cgroups_rule.rb"
  require Pathname(__FILE__).dirname + "../../util/cgroups_common.rb"

  defaultfor :operatingsystem => [:centos, :redhat]

  # Fedora has a different format
  confine :operatingsystem => [:centos, :redhat]

  @@cgroup_rule_classvars = {
    :target_file => '/etc/cgrules.conf',

    # The hash where all old rules and associated metadata will be collected.
    # We're going to write this *every* time 'flush' is called. This is not the
    # greatest thing in the world but you're guaranteed to have a propely built
    # file after each resource run if you do it this way. Without this, you end
    # up with a partially built file.
    :cgrules => {},

    # Don't read the file every time. Basically a prefetch.
    :initialized => false,

    # This is here so that we don't search through the whole catalog every time
    # we run a resource.
    :cgroup_rule_resources => nil,

    # How many resources do we have?
    :num_resources => 0,

    # What purge instance ar we on?
    :purge_count => 0,

    :purging => false,

    :file_header => <<-EOM.gsub(/^\s+/,'')
      # Puppet Header: This file managed by Puppet
      # Puppet Header: Any manual changes may be deleted or modified on the next
      # Puppet Header: run of Puppet.
    EOM
  }

  def initialize(*args)
    super(*args)

    # We only need to snarf the data once.
    if not @@cgroup_rule_classvars[:initialized] then
      orig_lines = []
      clean_lines = []
      if File.readable?(@@cgroup_rule_classvars[:target_file]) then
        File.open(@@cgroup_rule_classvars[:target_file],'r') { |fh|
          orig_lines = fh.read.split("\n").delete_if{|x| x =~ /^\s*(# Puppet Header:.*)?$/}.map{|x| x = x.strip}
          clean_lines = purge_bad_rules(orig_lines)

          comments = nil
          last_rule = nil
          clean_lines.each_with_index do |rule,i|
            # Keep comments associated with the next line.
            if rule.chomp =~ /^#.*$/ then
              comments ||= []
              comments << rule
              next
            end
            # This is here so that we can keep continuation lines together when we
            # put the file back together.
            if rule =~ /^\s*\%/ then
              if not @@cgroup_rule_classvars[:cgrules][last_rule] then
                Puppet.warning("Got continuation line without a starting rule at line #{i}, deleting.")
              else
                @@cgroup_rule_classvars[:cgrules][last_rule][:next_lines] ||= []
                @@cgroup_rule_classvars[:cgrules][last_rule][:next_lines] << rule
              end
              next
            end

            @@cgroup_rule_classvars[:cgrules][rule] = {
              :order => CGroups::Rule.assign_order(rule),
              :next_lines => nil,
              :old_line => true,
              :comments => []
            }

            comments and @@cgroup_rule_classvars[:cgrules][rule][:comments] = comments.dup and comments = nil

            last_rule = rule
          end
        }
      end

      # If we had to remove bad lines, go ahead and write the corrected file back out.
      # This does mean that we might write the file twice, but there's not
      # really another good way to do this consistently.
      if orig_lines.count != clean_lines.count then
        Puppet.debug("Rewriting #{@@cgroup_rule_classvars[:target_file]} to clean up bad content")
        File.open(@@cgroup_rule_classvars[:target_file],'w') { |fh|
          fh.rewind
          fh.puts(clean_lines.join("\n"))
        }
        File.chmod(0644,@@cgroup_rule_classvars[:target_file])
      end
    end

    @@cgroup_rule_classvars[:initialized] = true
  end

  def destination
    # Make sure this is called first! It helps track our internal metadata.
    @newline = resource[:user]
    @newline += ":#{resource[:process]}" if resource[:process] != :unknown
    @newline += " #{Array(resource[:controllers]).join(',')}"

    @old_key = nil
    @@cgroup_rule_classvars[:cgrules].each_key do |rule|
      old_dest = rule.split(/\s+/).last
      if rule.split(/\s+/)[0..1].join(' ') == @newline then
        # The comments were the same, return the usual destination.
        Puppet.debug("Matched '#{@newline}' with '#{rule}'")
        @@cgroup_rule_classvars[:cgrules][rule][:old_line] = false
        @old_key = rule

        # If the comment changes, this needs to be updated anyway.
        if resource[:comment] and @@cgroup_rule_classvars[:cgrules][rule][:comments].join("\n") != resource[:comment] then
          # Update due to the comment changing.
          return :comment
        else
          return old_dest
        end
      end
    end

    return nil
  end

  # Notice that, in here, we're not actually DOING anything except manipulating
  # the class object @@cgroup_rule_classvars[:cgrules]. This is so that we can put the file together
  # one time only and write it to disk all at once.
  def destination=(should)
    target = "#{@newline} #{should}"
    new_rule = {
      :order => resource[:order],
      :old_line => false,
      :next_lines => nil,
      :comments => []
    }

    resource[:comment] and new_rule[:comments] = Array(resource[:comment])

    if @old_key then
      new_rule[:order] = @@cgroup_rule_classvars[:cgrules][@old_key][:order]
      new_rule[:next_lines] = @@cgroup_rule_classvars[:cgrules][@old_key][:next_lines]
      new_rule[:comments] = @@cgroup_rule_classvars[:cgrules][@old_key][:comments]
      @@cgroup_rule_classvars[:cgrules].delete(@old_key)
    end

    @@cgroup_rule_classvars[:cgrules][target] = new_rule
  end

  def purge
    # Use the following when you ever want to support targeting different files.
    #Puppet.warning(resource.catalog.resources.find_all{|x| x.is_a?(Puppet::Type.type(:cgroup_rule)) and x.value(:target) == resource[:target]}.count)

    @@cgroup_rule_classvars[:purge_count] += 1

    # We really only want to do this once...
    if not @@cgroup_rule_classvars[:cgroup_rule_resources] then
      # How many resources (lines) are we managing?
      @@cgroup_rule_classvars[:cgroup_rule_resources] = resource.catalog.resources.find_all{|x| x.is_a?(Puppet::Type.type(:cgroup_rule))}
      @@cgroup_rule_classvars[:num_resources] = @@cgroup_rule_classvars[:cgroup_rule_resources].count
    end

    # We can't figure everything out until we've gotten to the last entry.
    # If you don't do this, you get a notice at *every line* which isn't very log-friendly.
    if @@cgroup_rule_classvars[:purge_count] == @@cgroup_rule_classvars[:num_resources] then
      # Figure out if we're purging or not and get rid of anything old if we are.
      purge = true
      @@cgroup_rule_classvars[:cgroup_rule_resources].each do |res|
        if res.value(:purge).to_s == "false" then
          purge = false
          break
        end
      end

      if purge then
        purge = false
        @@cgroup_rule_classvars[:cgrules].each do |rule,metadata|
          if metadata[:old_line] then
            # We should purge and have old lines, purgify!
            purge = true
            break
          end
        end
      end

      # If we got this far, then there's something to purge if we're supposed to.
      purge and return :purged or return resource[:purge]
    end

    # We were't ready to do anything yet.
    return resource[:purge]
  end

  def purge=(should)
    # Don't do anything here, just wait for the flush.
    # The reason for this is that all of the other resources need to be
    # processed before we go mucking about with @@cgroup_rule_classvars[:cgrules].
    @@cgroup_rule_classvars[:purging] = true
  end

  def flush
    # Have to rewrite the file every time to ensure sanity.
    File.open(@@cgroup_rule_classvars[:target_file],'w') { |fh|
      fh.rewind
      fh.puts(@@cgroup_rule_classvars[:file_header].strip)
      @@cgroup_rule_classvars[:cgrules].sort_by { |k,v| v[:order] }.each do |rule,metadata|
        # If we're purging, this will put the file together one item at a time.
        @@cgroup_rule_classvars[:purging] and metadata[:old_line] and next
        not metadata[:comments].empty? and fh.puts(metadata[:comments].join("\n"))
        fh.puts(rule)
        metadata[:next_lines] and fh.puts(metadata[:next_lines].join("\n"))
      end
    }
    File.chmod(0644,@@cgroup_rule_classvars[:target_file])
  end

  private

  def purge_bad_rules(to_scan)
    res = to_scan.dup
    to_scan.each_with_index do |rule,i|
      # Ignore blank and comment lines
      rule =~ /^\s*(#.*)?$/ and next

      split_rule = rule.split(/\s+/)
      user,controllers,destination = split_rule
      if split_rule.size != 3 or destination[0].chr == '/' then
        Puppet.warning("Rule '#{rule}' in #{@@cgroup_rule_classvars[:target_file]} is malformed, deleting.")
        res[i] = nil
      end
    end

    return res.compact
  end

end
