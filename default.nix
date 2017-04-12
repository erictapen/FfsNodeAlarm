with import <nixpkgs> {};

stdenv.mkDerivation rec {
  name = "ffsnodealarm-${version}";
  version = "0.0.1-SNAPSHOT";

  src = ./.;
  
  buildInputs = [
    pkgs.php70Packages.composer
    pkgs.php70
  ];

  buildPhase = ''
    composer install
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp -r . $out/
  '';
}
