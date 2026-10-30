{
  description = "Akizip – a GTK4/libadwaita archive manager for GNOME, packaged for Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      # 7zz (the 7-Zip engine) is only built for these in nixpkgs
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      akizipFor =
        pkgs:
        let
          python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
        in
        pkgs.stdenv.mkDerivation (finalAttrs: {
          pname = "akizip";
          version = "0.4.4";

          src = pkgs.fetchFromGitHub {
            owner = "AkiZip";
            repo = "AkiZip";
            tag = finalAttrs.version;
            hash = "sha256-LzLzbCVoN4SRFaxALlod8K5iYLiCx9iJ6BJnlN7tum0=";
          };

          # Upstream hard-codes the Flatpak path /app/bin/7zz.
          # Point it at 7zz from nixpkgs instead.
          postPatch = ''
            substituteInPlace src/plugins/sevenzip.py \
              --replace-fail "'/app/bin/7zz'" "'${pkgs.lib.getExe' pkgs._7zz "7zz"}'"
          '';

          nativeBuildInputs = with pkgs; [
            meson
            ninja
            pkg-config
            gettext
            glib # glib-compile-resources / glib-compile-schemas
            desktop-file-utils
            gtk4 # gtk4-update-icon-cache
            gobject-introspection
            wrapGAppsHook4
            python # meson's python.find_installation() writes this into the launcher's shebang
          ];

          buildInputs = [
            pkgs.gtk4
            pkgs.libadwaita
            python
          ];

          # The meson tests only validate the desktop/metainfo/schema files.
          doCheck = false;

          meta = {
            description = "Modern archive manager for GNOME, built with GTK 4 and libadwaita";
            homepage = "https://github.com/AkiZip/AkiZip";
            license = pkgs.lib.licenses.gpl3Plus;
            mainProgram = "akizip";
            platforms = systems;
          };
        });
    in
    {
      packages = forAllSystems (pkgs: rec {
        akizip = akizipFor pkgs;
        default = akizip;
      });

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = nixpkgs.lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.akizip;
        };
      });

      overlays.default = final: _prev: {
        akizip = akizipFor final;
      };

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
