# Init cgroups
#
# @param default_mounts
#   Whether or not to set up the default cgroup mounts.
#   NOTE: These are only effective on RHEL6
#
# @param sync_on_update
#   If set to true, then the running cgroup configuration will be saved to
#   /etc/cgconfig.conf each time puppet runs and changes rules or
#   permissions.
#
# @param cgred_id
#   The GID to use for the cgred group.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class cgroups (
  Boolean $default_mounts = true,
  Boolean $sync_on_update = true,
  Integer $cgred_gid      = 450
){

  if $default_mounts and defined('$::cgroups') and is_hash($::cgroups) and !empty($::cgroups) {
    $system_cgroups = keys($facts['cgroups'])
    cgroup { $system_cgroups: }
  }

  # We want to make sure we're keeping track of the running state of the
  # system.
  if $sync_on_update {
    cgsnapshot { '/etc/cgconfig.conf': }
  }

  group { 'cgred': gid => $cgred_gid }

  package { 'libcgroup':
    ensure  => 'latest',
    require => Group['cgred']
  }
  package { 'libcgroup-pam': ensure => 'latest' }

  service { [
    'cgred',
    'cgconfig'
  ]:
    ensure     => 'running',
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
    require    => Package['libcgroup']
  }
}
