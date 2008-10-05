%define rcver	%{nil}
%define dotrc	%{nil}

Name:		renrot
Version:	1.1
Release:	1%{?dotrc}%{?dist}
License:	Artistic 2.0
Group:		Applications/Multimedia
Summary:	A program to rename and rotate files according to EXIF tags
URL:		http://puszcza.gnu.org.ua/projects/renrot/
Source0:	ftp://download.gnu.org.ua/pub/release/renrot/%{name}-%{version}%{?rcver}.tar.gz
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:	noarch
BuildRequires:	perl(Image::ExifTool) >= 5.72
BuildRequires:	perl(Getopt::Long) >= 2.34
Requires:	perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))
Requires:	libjpeg >= 6b
Requires(hint):	perl(Image::Magick)

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
%setup -q -n %{name}-%{version}%{?rcver}

%build
%{__perl} Makefile.PL PREFIX=%{_prefix}
make

%install
rm -rf $RPM_BUILD_ROOT
make install PREFIX=$RPM_BUILD_ROOT%{_prefix}

# Fix renrot permissions
chmod 755 $RPM_BUILD_ROOT%{_bindir}/renrot

# install sample configuration files
mkdir -p $RPM_BUILD_ROOT%{_sysconfdir}/%{name}
install -m644 etc/colors.conf $RPM_BUILD_ROOT%{_sysconfdir}/%{name}
install -m644 etc/copyright.tag $RPM_BUILD_ROOT%{_sysconfdir}/%{name}
install -m644 etc/renrot.conf $RPM_BUILD_ROOT%{_sysconfdir}/%{name}
install -m644 etc/tags.conf $RPM_BUILD_ROOT%{_sysconfdir}/%{name}

# Remove some unwanted files
find $RPM_BUILD_ROOT -type f -name .packlist -exec rm -f {} \;
find $RPM_BUILD_ROOT -type f -name perllocal.pod -exec rm -f {} \;

%clean
rm -rf $RPM_BUILD_ROOT

%triggerin -- renrot < 0.21-0.2.rc2
if [ -f %{_sysconfdir}/renrot.rc ]; then
    /bin/mkdir -p %{_sysconfdir}/%{name}
    /bin/mv -fb %{_sysconfdir}/renrot.rc %{_sysconfdir}/%{name}/renrot.conf
fi

%files
%defattr(-,root,root,-)
%doc AUTHORS README ChangeLog NEWS TODO
%lang(ru) %doc README.russian
%{_bindir}/renrot
%{_mandir}/man1/*.1*
%dir %{_sysconfdir}/%{name}
%config(noreplace) %{_sysconfdir}/%{name}/colors.conf
%config(noreplace) %{_sysconfdir}/%{name}/copyright.tag
%config(noreplace) %{_sysconfdir}/%{name}/renrot.conf
%config(noreplace) %{_sysconfdir}/%{name}/tags.conf

%changelog
* Sun Jun 01 2008 Andy Shevchenko <andy@smile.org.ua>
- change License to Artistic 2.0 accordingly to mainstream
- update URLs
- require (optional) Image::Magick

* Tue Aug 22 2006 Andy Shevchenko <andy@smile.org.ua>
- add colors.conf

* Wed Jun 07 2006 Andy Shevchenko <andriy@asplinux.com.ua>
- relocate configuration to %_sysconfdir/%name

* Sat Jun 03 2006 Andy Shevchenko <andriy@asplinux.com.ua>
- remove BR: perl
- fix renrot permissions

* Mon May 15 2006 Andy Shevchenko <andriy@asplinux.com.ua>
- install rc-file

* Tue Apr 18 2006 Andy Shevchenko <andriy@asplinux.com.ua>
- initial package
