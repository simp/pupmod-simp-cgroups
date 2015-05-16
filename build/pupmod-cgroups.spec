%global short_name cgroups

Summary: CGroups Puppet Module
Name: pupmod-cgroups
Version: 1.0.0
Release: 6
License: Apache License, Version 2.0
Group: Applications/System
Source: %{name}-%{version}-%{release}.tar.gz
Buildroot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Requires: puppet >= 3.3.0
Buildarch: noarch
Requires: simp-bootstrap >= 4.2.0
Obsoletes: pupmod-cgroups-test

Prefix:"/etc/puppet/environments/simp/modules/%{short_name}"

%description
This puppet module provides for the management of CGroups on a Linux system.
See http://www.kernel.org/doc/Documentation/cgroups/cgroups.txt for additional
information.

%prep
%setup -q

%build

%install
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

mkdir -p %{buildroot}/%{prefix}

dirs='files lib manifests templates'
for dir in $dirs; do
  test -d $dir && cp -r $dir %{buildroot}/%{prefix}
done

mkdir -p %{buildroot}/usr/share/simp/tests/modules/%{short_name}

%clean
[ "%{buildroot}" != "/" ] && rm -rf %{buildroot}

%files
%defattr(0640,root,puppet,0750)
/etc/puppet/environments/simp/modules/%{short_name}

%post
#!/bin/sh

if [ -d /etc/puppet/environments/simp/modules/%{short_name}/plugins ]; then
  /bin/mv /etc/puppet/environments/simp/modules/%{short_name}/plugins /etc/puppet/environments/simp/modules/%{short_name}/plugins.bak
fi

%postun
# Post uninstall stuff

%changelog
* Fri Jan 16 2015 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.0-6
- Changed puppet-server requirement to puppet

* Tue Feb 15 2014 Kendall Moore <kmoore@keywcorp.com> - 1.0.0-5
- Added spec tets.
- Updated init.pp to pass all lint tests.

* Mon Dec 10 2013 Kendall Moore <kmoore@keywcorp.com> - 1.0.0-4
- Updated for hiera and puppet 3 compatibility.

* Mon Oct 14 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.0-3
- Updated the custom types to no longer use Puppet::Util::FileLocking
  since it has been removed.

* Tue Jul 09 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.0-2
- Fixed a bug in the cgroup_rule provider that was causing valid rules
  that should be purged to not be purged. Also fixed an ordering issue
  with the purge property.

* Wed Jun 19 2013 Nick Markowski <nmarkowski@keywcorp.com> - 1.0.0-1
- Added mit_test to remove valid lines manually added to /etc/cgrules.conf
  when purge => true

* Tue Jun 18 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.0-1
- Fixed a typo in the 'defaultvalues' in 'order' for the cgroup_rule
  type.

* Mon Feb 25 2013 Trevor Vaughan <tvaughan@onyxpoint.com> - 1.0.0-0
- Creation of the first cut at a CGroups module.
- The following native types are provided:
  - cgroup => manages cgroup mounts and subgroups
  - cgroup_controller => Manages actual cgroup settings
  - cgroup_perm => Manages permissions on group files
  - cgroup_rule => Manages cgroup user rules in /etc/cgrules.conf
  - cgsnapshot_blacklist => Manages cgsnapshot blacklist files
  - cgsnapshot => Fires off a snapshot sync
