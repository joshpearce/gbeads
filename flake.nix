{
  description = "gbeads - GitHub issue wrapper for work organization";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-darwin" "x86_64-linux" "aarch64-darwin" "aarch64-linux"];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
  in {
    packages = forAllSystems (pkgs: {
      default = self.packages.${pkgs.system}.gbeads;
      gbeads = pkgs.stdenv.mkDerivation {
        pname = "gbeads";
        version = "0.1.0";
        src = ./.;

        nativeBuildInputs = [pkgs.makeWrapper];

        dontBuild = true;

        installPhase = ''
          mkdir -p $out/bin
          cp gbeads $out/bin/gbeads
          chmod +x $out/bin/gbeads
          wrapProgram $out/bin/gbeads \
            --prefix PATH : ${pkgs.lib.makeBinPath [pkgs.gh pkgs.python3 pkgs.bash pkgs.git]}
        '';
      };
    });
  };
}
