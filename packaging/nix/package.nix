{ lib, stdenv, cmake, ninja, pkg-config, qt6, kdePackages, libarchive, openssl }:

stdenv.mkDerivation {
  pname = "prismarine";
  version = "0.4.0";
  src = lib.cleanSource ../..;

  nativeBuildInputs = [ cmake ninja pkg-config qt6.wrapQtAppsHook ];
  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtquick3d
    qt6.qtshadertools
    qt6.qtsvg
    kdePackages.qtkeychain
    libarchive
    openssl
  ];

  cmakeFlags = [ "-DBUILD_TESTING=OFF" "-DPRISMARINE_KEYCHAIN=ON" ];

  meta = {
    description = "Minecraft library and instance manager for Prism Launcher";
    homepage = "https://github.com/Fi3w0/Prismarine";
    # The logo has different terms from the code; respect Nix's license policy.
    license = [ lib.licenses.gpl3Only lib.licenses.cc-by-nc-nd-40 lib.licenses.ofl ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "prismarine";
  };
}
