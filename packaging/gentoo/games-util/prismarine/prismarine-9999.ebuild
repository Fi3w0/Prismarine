# Copyright 2026 Fi3w0
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit cmake git-r3 xdg

DESCRIPTION="Minecraft library and instance manager for Prism Launcher"
HOMEPAGE="https://github.com/Fi3w0/Prismarine"
EGIT_REPO_URI="https://github.com/Fi3w0/Prismarine.git"
EGIT_BRANCH="main"

LICENSE="GPL-3 CC-BY-NC-ND-4.0 OFL-1.1"
SLOT="0"
IUSE="+keychain"
# The public source tree does not contain the private test suites.
RESTRICT="test"

DEPEND="
	>=dev-qt/qtbase-6.6:6[concurrent,gui,network,opengl,ssl,widgets]
	>=dev-qt/qtdeclarative-6.6:6[opengl]
	>=dev-qt/qtquick3d-6.6:6
	>=dev-qt/qtshadertools-6.6:6
	>=dev-qt/qtsvg-6.6:6
	app-arch/libarchive:=
	>=dev-libs/openssl-3:0=
	keychain? ( dev-libs/qtkeychain:= )
"
RDEPEND="${DEPEND}"
BDEPEND="virtual/pkgconfig"

DOCS=( README.md NOTICE TRADEMARKS.md )

src_configure() {
	local mycmakeargs=(
		-DBUILD_TESTING=OFF
		-DPRISMARINE_KEYCHAIN=$(usex keychain)
	)
	cmake_src_configure
}

pkg_postinst() {
	xdg_pkg_postinst
	elog "Install Prism Launcher and sign in once before using Prismarine."
	elog "Prismarine is beta software; use disposable instances when testing changes."
}
