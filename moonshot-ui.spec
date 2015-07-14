Name:           moonshot-ui
Version:        0.7.2
Release:        2%{?dist}
Summary:        Moonshot Federated Identity User Interface

Group:          Security Tools
License:        BSD
URL:            http://www.project-moonshot.org/
Source0:	%{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root

BuildRequires:		glib-devel
BuildRequires:  	gtk2-devel
BuildRequires: libgee-devel
BuildRequires:  	dbus-devel
BuildRequires: 		dbus-glib-devel
BuildRequires: 		desktop-file-utils
BuildRequires: 		shared-mime-info
BuildRequires: gnome-keyring-devel

Requires:        desktop-file-utils, shared-mime-info, dbus-x11

%description


%prep
%setup -q


%build
%configure
make %{?_smp_mflags}


%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT


%clean
rm -rf $RPM_BUILD_ROOT
%post
	/usr/bin/update-desktop-database

%postun
	/usr/bin/update-desktop-database

%package devel
Summary: Moonshot UI Development
Requires: moonshot-ui  = %{version}-%{release}

%description devel

	     Moonshot UI development




%files
%defattr(-,root,root,-)
%{_bindir}/moonshot
%{_bindir}/moonshot-webp
%{_datadir}/applications/*
%{_datadir}/dbus-1/*
%{_datadir}/mime/packages/*
%{_datadir}/moonshot-ui
%{_libexecdir}/moonshot-ui/moonshot-dbus-launch
%{_libdir}/libmoonshot.so.*
%config(noreplace) %{_sysconfdir}/moonshot/*
%doc webprovisioning/default-identity.msht

%files devel
%{_includedir}/*.h
%{_libdir}/libmoonshot.a
%{_libdir}/libmoonshot.so
%exclude %{_libdir}/*.la






%changelog
