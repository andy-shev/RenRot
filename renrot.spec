Name:		renrot
Version:	0.20
Release:	0.1.rc3%{?dist}
License:	GPL or Artistic
Group:		Applications/Multimedia
Summary:	A program to rename and rotate files according to EXIF tags
URL:		http://freshmeat.net/projects/renrot/
Source0:	ftp://ftp.dn.farlep.net/pub/misc/renrot/%{name}-%{version}rc3.tar.gz
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:	noarch
BuildRequires:	perl >= 1:5.6.0
BuildRequires:	perl(Image::ExifTool) >= 5.61
BuildRequires:	perl(Getopt::Long) >= 2.34
Requires:	perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))
Requires:	libjpeg >= 6b

%description
Renrot renames files according the DateTimeOriginal and FileModifyDate
EXIF tags, if they exist. Otherwise, the name will be set according to
the current timestamp. Additionally, it rotates files and their
thumbnails, accordingly Orientation EXIF tag.

The script can also put commentary into the Commentary and UserComment
tags.

Personal details can be specified via XMP tags defined in a
configuration file.

%prep
%setup -q -n %{name}-%{version}rc3

%build
%{__perl} Makefile.PL PREFIX=%{_prefix}
make

%install
rm -rf $RPM_BUILD_ROOT
make install PREFIX=$RPM_BUILD_ROOT%{_prefix}

# install rc-file
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}
install -m644 renrot.rc $RPM_BUILD_ROOT%{_sysconfdir}/renrot.rc

# Remove some unwanted files
find $RPM_BUILD_ROOT -type f -name .packlist -exec rm -f {} \;
find $RPM_BUILD_ROOT -type f -name perllocal.pod -exec rm -f {} \;

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc AUTHORS README ChangeLog NEWS TODO
%lang(ru) %doc README.russian
%{_bindir}/renrot
%{_mandir}/man1/*.1*
%config(noreplace) %{_sysconfdir}/renrot.rc

%changelog
* Mon May 15 2006 Andy Shevchenko <andriy@asplinux.com.ua>
- install rc-file

* Tue Apr 18 2006 Andy Shevchenko <andriy@asplinux.com.ua>
- initial package
