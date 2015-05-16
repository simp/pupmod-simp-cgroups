# == Class: cgroups
#
# == Parameters
#
# [*default_mounts*]
#   Whether or not to set up the default cgroup mounts.
#
# [*sync_on_update*]
#   If set to true, then the running cgroup configuration will be saved to
#   /etc/cgconfig.conf each time puppet runs and changes rules or
#   permissions.
#
# [*cgred_id*]
#   The GID to use for the cgred group.
#
# == Authors
#
# * Trevor Vaughan <tvaughan@onyxpoint.com>
#
class cgroups (
  $default_mounts = true,
  $sync_on_update = true,
  $cgred_gid = '450'
){

  if $default_mounts {
    cgroup { 'cpuset': }
    cgroup { 'cpu': }
    cgroup { 'cpuacct': }
    cgroup { 'memory': }
    cgroup { 'devices': }
    cgroup { 'freezer': }
    cgroup { 'net_cls': }
    cgroup { 'blkio': }
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

  validate_bool($default_mounts)
  validate_bool($sync_on_update)
  validate_integer($cgred_gid)
}

