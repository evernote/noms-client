Summary: Client libraries/CLIs for NOMS
Name: %{name}
Version: %{version}
Release: %{release}
License: Apache2
Group: Development/Libraries
AutoReqProv: no
Prefix: %{inst_prefix}
Source0: %{source_tarball}
BuildArchitectures: %{build_arch}
Provides: %{cname}, __PROVIDES_DIRS__

%description
The NOMS client libraries and tools provide a cohesive API and CLI to
NOMS services like the CMDB.

%prep
%setup -n %{cname}-%{version}

%build
# Simple template - no building
# tempted to substitute inst_prefix in files here -jdb/20100603

%install
test -d "$RPM_BUILD_ROOT%{inst_prefix}" || mkdir -p "$RPM_BUILD_ROOT%{inst_prefix}"
for d in bin etc lib man; do test -d "$d" && tar cf - "$d" | (cd $RPM_BUILD_ROOT%{inst_prefix}; tar xf -); done
test -d "${RPM_BUILD_ROOT}%{file_dest}" || mkdir -p "${RPM_BUILD_ROOT}%{file_dest}"
ls | egrep -v '^(bin|etc|lib|man)$' | while read d; do tar cf - "$d" | (cd ${RPM_BUILD_ROOT}%{file_dest}; tar xf -); done

%clean
rm -rf ${RPM_BUILD_ROOT}

%pre
__ENSURE_DIRS__

%files
# The calculated manifest understands executable files in bin/ and library files in lib/ and config files in etc/
# It will also list files in $FILES with -default- attributes but can't do anything more complicated than that, so
# if you need different files with different attributes there you'll have to replace this with an actual manifest
__FILE_MANIFEST__
