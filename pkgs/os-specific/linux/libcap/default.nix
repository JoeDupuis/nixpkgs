{ stdenv, lib, buildPackages, fetchurl, attr, perl
, usePam ? !isStatic, pam ? null
, isStatic ? stdenv.hostPlatform.isStatic
}:

assert usePam -> pam != null;

stdenv.mkDerivation rec {
  pname = "libcap";
  version = "2.44";

  src = fetchurl {
    url = "mirror://kernel/linux/libs/security/linux-privs/libcap2/${pname}-${version}.tar.xz";
    sha256 = "1qf80lifygbnxwvqjf8jz5j24n6fqqx4ixnkbf76xs2vrmcq664j";
  };

  patches = lib.optional isStatic ./no-shared-lib.patch;

  outputs = [ "out" "dev" "lib" "man" "doc" ]
    ++ lib.optional usePam "pam";

  depsBuildBuild = [ buildPackages.stdenv.cc ];
  nativeBuildInputs = [ perl ];

  buildInputs = lib.optional usePam pam;

  propagatedBuildInputs = [ attr ];

  makeFlags = [
    "lib=lib"
    "PAM_CAP=${if usePam then "yes" else "no"}"
    "BUILD_CC=$(CC_FOR_BUILD)"
    "CC:=$(CC)"
  ];

  prePatch = ''
    # use relative bash path
    substituteInPlace progs/capsh.c --replace "/bin/bash" "bash"

    # ensure capsh can find bash in $PATH
    substituteInPlace progs/capsh.c --replace execve execvpe

    # set prefixes
    substituteInPlace Make.Rules \
      --replace 'prefix=/usr' "prefix=$lib" \
      --replace 'exec_prefix=' "exec_prefix=$out" \
      --replace 'lib_prefix=$(exec_prefix)' "lib_prefix=$lib" \
      --replace 'inc_prefix=$(prefix)' "inc_prefix=$dev" \
      --replace 'man_prefix=$(prefix)' "man_prefix=$doc"
  '';

  installFlags = [ "RAISE_SETFCAP=no" ];

  postInstall = ''
    ${lib.optionalString (!isStatic) ''rm "$lib"/lib/*.a''}
    mkdir -p "$doc/share/doc/${pname}-${version}"
    cp License "$doc/share/doc/${pname}-${version}/"
  '' + stdenv.lib.optionalString usePam ''
    mkdir -p "$pam/lib/security"
    mv "$lib"/lib/security "$pam/lib"
  '';

  meta = {
    description = "Library for working with POSIX capabilities";
    homepage = "https://sites.google.com/site/fullycapable";
    platforms = stdenv.lib.platforms.linux;
    license = stdenv.lib.licenses.bsd3;
  };
}
