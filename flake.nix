{
  description = "Helper functions for building Typst environments with Nix";

  outputs = { ... }: {
    lib = {
      # =========================================================
      # 1. Builder for YOUR packages
      # =========================================================
      # Arguments:
      # - files: (Optional) List of files/folders to copy. 
      #          If null, copies the entire directory.
      #          Example: files = [ "lib.typ" "typst.toml" "src" ];
      buildTypstPackage = { pkgs, pname, version, src, files ? null }:
        pkgs.stdenv.mkDerivation {
          inherit pname version src;
          dontBuild = true;

          installPhase = ''
            target="$out/share/typst/packages/preview/${pname}/${version}"
            mkdir -p "$target"

            ${if files == null then ''
              # No files specified? Copy everything (default behavior)
              cp -r * "$target"
            '' else ''
              # Files specified? Loop through the list and copy them individually
              ${pkgs.lib.concatMapStringsSep "\n" (file: "cp -r ${file} \"$target/\"") files}
            ''}
          '';
        };

      # =========================================================
      # 2. Environment Builder
      # =========================================================
      # Creates a wrapper that sets TYPST_PACKAGE_PATH to the Nix store
      # but leaves the Cache path open for online downloads.
      mkTypstEnv = { pkgs, typst, packages ? [] }:
        pkgs.symlinkJoin {
          name = "typst-with-packages";
          paths = packages ++ [ typst ];
          nativeBuildInputs = [ pkgs.makeBinaryWrapper ];

          postBuild = ''
            # The unified package directory we will expose to Typst
            PKGS_DIR="$out/share/typst/packages"
            mkdir -p "$PKGS_DIR"

            if [ -d "$out/lib/typst-packages" ]; then
              for namespace in "$out/lib/typst-packages"/*; do
                ns_name=$(basename "$namespace")
                target_ns="$PKGS_DIR/$ns_name"

                if [ -d "$target_ns" ]; then
                  echo "🔗 Merging Nixpkgs '$ns_name' into existing directory..."
                  ln -s "$namespace"/* "$target_ns/"
                else
                  ln -s "$namespace" "$PKGS_DIR/"
                fi
              done
            fi

            # Set TYPST_PACKAGE_PATH to our unified Nix directory.
            # This makes Typst see these packages as "local/system" packages.
            wrapProgram $out/bin/typst \
              --set TYPST_PACKAGE_PATH "$PKGS_DIR"
          '';
        };
    };
  };
}
