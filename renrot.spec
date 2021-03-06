%define rcver	%{nil}
%define dotrc	%{nil}

Name:		renrot
Version:	1.2.0
Release:	3%{?dotrc}%{?dist}
License:	Artistic 2.0
Group:		Applications/Multimedia
Summary:	A program to rename and rotate files according to EXIF tags
URL:		http://puszcza.gnu.org.ua/projects/renrot/
Source0:	ftp://download.gnu.org.ua/pub/release/renrot/%{name}-%{version}%{?rcver}.tar.gz
BuildArch:	noarch
BuildRequires:	perl(ExtUtils::MakeMaker)
BuildRequires:	perl(Getopt::Long) >= 2.34
BuildRequires:	perl(Image::ExifTool) >= 5.72
Requires:	perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))
Requires:	perl(Image::Magick)
Requires:	/usr/bin/jpegtran

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
%{__perl} Makefile.PL INSTALLDIRS=vendor
make

%install
make pure_install PERL_INSTALL_ROOT=$RPM_BUILD_ROOT

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

%triggerin -- renrot < 0.21-0.2.rc2
if [ -f %{_sysconfdir}/renrot.rc ]; then
    /bin/mkdir -p %{_sysconfdir}/%{name}
    /bin/mv -fb %{_sysconfdir}/renrot.rc %{_sysconfdir}/%{name}/renrot.conf
fi

%files
%doc AUTHORS ChangeLog NEWS README TODO
%lang(ru) %doc README.russian
%{_bindir}/renrot
%{_mandir}/man1/*.1*
%dir %{_sysconfdir}/%{name}
%config(noreplace) %{_sysconfdir}/%{name}/colors.conf
%config(noreplace) %{_sysconfdir}/%{name}/copyright.tag
%config(noreplace) %{_sysconfdir}/%{name}/renrot.conf
%config(noreplace) %{_sysconfdir}/%{name}/tags.conf
%{perl_vendorlib}/Image/

%changelog
* Sun Jul 15 2012 Andy Shevchenko <andy.shevchenko@gmail.com>
- explicitly require perl-Image-Magick

* Mon Jun 20 2011 Petr Sabata <contyk@redhat.com> - 1.1-3
- Perl mass rebuild
- Dropping now obsolete Buildroot and defattr
- Commenting Requires(hint) out since fedpkg refuses to work with it

* Thu Jul 01 2010 Adam Tkac <atkac redhat com> - 1.1-2
- Require /usr/bin/jpegtran instead of libjpeg; compatible with both
  libjpeg and libjpeg-turbo

* Mon Oct 06 2008 Andy Shevchenko <andy@smile.org.ua> - 1.1-0.3.rc3
- update to 1.1rc3
- change License to Artistic 2.0 accordingly to mainstream
- update URLs
- require (optional) Image::Magick

* Tue Sep 04 2007 Andy Shevchenko <andy@smile.org.ua> 0.25-3.1
- Fix License tag
- Add BuildRequires: perl(ExtUtils::MakeMaker)

* Tue Aug 22 2006 Andy Shevchenko <andy@smile.org.ua>
- add colors.conf

* Wed Jun 07 2006 Andy Shevchenko <andriy@asplinux.com.ua>
- relocate configuration to %_sysconfdir/%name

* Sat Jun 03 2006 Andy Shevchenko <andriy@asplinux.com.ua> 0.20-2
- remove BR: perl
- fix renrot permissions

* Mon May 15 2006 Andy Shevchenko <andriy@asplinux.com.ua>
- install rc-file

* Tue Apr 18 2006 Andy Shevchenko <andriy@asplinux.com.ua>
- initial package
