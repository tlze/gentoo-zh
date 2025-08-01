# Copyright 1999-2021 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
WX_GTK_VER="3.2-gtk3"

inherit wxwidgets xdg-utils git-r3
DESCRIPTION="aMule with DLP patch, the all-platform eMule p2p client"
HOMEPAGE="https://github.com/persmule/amule-dlp"
EGIT_REPO_URI="https://github.com/persmule/amule-dlp"

LICENSE="GPL-2+"
SLOT="0"
IUSE="daemon debug geoip nls remote stats upnp +X"

RDEPEND="
	dev-libs/boost:=
	dev-libs/crypto++:=
	sys-libs/binutils-libs:0=
	sys-libs/readline:0=
	sys-libs/zlib
	x11-libs/wxGTK:${WX_GTK_VER}[X?]
	daemon? ( acct-user/amule )
	geoip? ( dev-libs/geoip )
	nls? ( virtual/libintl )
	remote? (
		acct-user/amule
		media-libs/libpng:0=
	)
	stats? ( media-libs/gd:=[jpeg,png] )
	upnp? ( net-libs/libupnp:0 )
	!net-p2p/amule
"
DEPEND="${RDEPEND}
	X? ( dev-util/desktop-file-utils )
"
BDEPEND="
	virtual/pkgconfig
	nls? ( sys-devel/gettext )
"

pkg_setup() {
	setup-wxwidgets
}

src_prepare() {
	default

	eapply "${FILESDIR}"/amule-dlp-allow-autoconf.patch
	eapply "${FILESDIR}"/amule-dlp-fix-boost-1.87.patch
	if [[ ${PV} == 9999 ]]; then
		./autogen.sh || die
	fi
}

src_configure() {
	local myconf=(
		--with-denoise-level=0
		--with-wx-config="${WX_CONFIG}"
		--enable-amulecmd
		--with-boost
		$(use_enable debug)
		$(use_enable daemon amule-daemon)
		$(use_enable geoip)
		$(use_enable nls)
		$(use_enable remote webserver)
		$(use_enable stats cas)
		$(use_enable stats alcc)
		$(use_enable upnp)
	)

	if use X; then
		myconf+=(
			$(use_enable remote amule-gui)
			$(use_enable stats alc)
			$(use_enable stats wxcas)
		)
	else
		myconf+=(
			--disable-monolithic
			--disable-amule-gui
			--disable-alc
			--disable-wxcas
		)
	fi

	econf "${myconf[@]}"
}

src_install() {
	default

	if use daemon; then
		newconfd "${FILESDIR}"/amuled.confd-r1 amuled
		newinitd "${FILESDIR}"/amuled.initd amuled
	fi
	if use remote; then
		newconfd "${FILESDIR}"/amuleweb.confd-r1 amuleweb
		newinitd "${FILESDIR}"/amuleweb.initd amuleweb
	fi

	if use daemon || use remote; then
		keepdir /var/lib/${PN}
		fowners amule:amule /var/lib/${PN}
		fperms 0750 /var/lib/${PN}
	fi
}

pkg_postinst() {
	local ver

	if use daemon || use remote; then
		for ver in ${REPLACING_VERSIONS}; do
			if ver_test ${ver} -lt "2.3.2-r4"; then
				elog "Default user under which amuled and amuleweb daemons are started"
				elog "have been changed from p2p to amule. Default home directory have been"
				elog "changed as well."
				echo
				elog "If you want to preserve old download/share location, you can create"
				elog "symlink /var/lib/amule/.aMule pointing to the old location and adjust"
				elog "files ownership *or* restore AMULEUSER and AMULEHOME variables in"
				elog "/etc/conf.d/{amuled,amuleweb} to the old values."

				break
			fi
		done
	fi

	use X && xdg_desktop_database_update
}

pkg_postrm() {
	use X && xdg_desktop_database_update
}
