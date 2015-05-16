require 'puppet/provider/parsedfile'
blacklist = '/etc/cgsnapshot_blacklist.conf'

Puppet::Type.type(:cgsnapshot_blacklist).provide(:parsed,
  :parent => Puppet::Provider::ParsedFile,
  :default_target => blacklist,
  :filetype => :flat
) do

  defaultfor :osfamily => :redhat
  confine :osfamily => :redhat

  text_line :comment, :match => /^\s*#/
  text_line :blank, :match => /^\s*$/

  record_line :parsed, :fields => %w{name}
end
