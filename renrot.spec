Name:		renrot
Version:	0.14.2
Release:	1%{?dist}
License:	GPL or Artistic
Group:		Applications/Multimedia
Summary:	Rename and rotate files according to EXIF tags
URL:		ftp://ftp.dn.farlep.net/pub/misc/renrot/
Source0:	ftp://ftp.dn.farlep.net/pub/misc/renrot/%{name}-%{version}.tar.gz
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:	noarch
BuildRequires:	perl >= 1:5.6.0
BuildRequires:	perl(Image::ExifTool) >= 5.61
BuildRequires:	perl(Getopt::Long) >= 2.34
Requires:	perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))

%description
Renrot renames files according the DateTimeOriginal, FileModifyDate
EXIF tags if they're exist or the name will be given according the
current timestamp. Additionally, it rotates file and it's thumbnail,
accordingly Orientation EXIF tag.

After all, the script can put the commentary to Commentary and
UserComment tags.

Personal details could be specified via XMP tags defined in config
file.

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
%{_bindir}/renrot
%{_mandir}/man1/*.1*

%changelog
* Tue Apr 18 2006 Andy Shevchenko <andriy@asplinux.com.ua>
- initial package
