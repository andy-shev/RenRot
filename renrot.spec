Name:		renrot
Version:	0.19
Release:	1%{?dist}
License:	GPL or Artistic
Group:		Applications/Multimedia
Summary:	A program to rename and rotate files according to EXIF tags
URL:		ftp://ftp.dn.farlep.net/pub/misc/renrot/
Source0:	ftp://ftp.dn.farlep.net/pub/misc/renrot/%{name}-%{version}.tar.gz
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
%setup -q

%build
%{__perl} Makefile.PL PREFIX=%{_prefix}
make

%install
rm -rf $RPM_BUILD_ROOT
make install PREFIX=$RPM_BUILD_ROOT%{_prefix}

# Remove some unwanted files
find $RPM_BUILD_ROOT -type f -name .packlist -exec rm -f {} \;
find $RPM_BUILD_ROOT -type f -name perllocal.pod -exec rm -f {} \;

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc AUTHORS README ChangeLog
%doc renrot.rc
%{_bindir}/renrot
%{_mandir}/man1/*.1*

%changelog
* Tue Apr 18 2006 Andy Shevchenko <andriy@asplinux.com.ua>
- initial package
