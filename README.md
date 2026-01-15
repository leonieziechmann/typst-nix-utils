# Typst Nix Utils

**Instant, cross-project development workflows for Typst.**

This flake provides helper functions to turn your Typst packages into composable Nix building blocks. It solves the "dependency hell" of developing multiple inter-dependent packages simultaneously.

## The Problem: The "Universe Wait"

If you maintain multiple Typst packages (e.g., a "core" library and several "templates"), developing them together is painful:

1. **The Feedback Loop is Slow:** To use changes from your `core` library in your `template` project, you usually have to wait for a Typst Universe release (days/weeks) or hack together manual symlinks in `~/.local/share/...`.
2. **Versioning Conflicts:** working on "vNext" of a library often breaks your current projects if you rely on global mutable state (local cache).
3. **CI Inconsistency:** Your local symlinks work, but your CI fails because it can't find your unreleased changes.

## The Solution: Instant "Local Universe"

`typst-nix-utils` lets you treat your local projects as if they were already published.

* **Zero Wait Time:** Changes in `project-a` are instantly available to `project-b` via Nix.
* **Isolated Environments:** Each project gets its own "Universe" containing exactly the versions it needs.
* **Hybrid Workflow:** Explicitly mix your **local bleeding-edge packages** with **standard internet packages** from the real Typst Universe.

## Installation

Add this repository to your `flake.nix` inputs:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  flake-utils.url = "github:numtide/flake-utils";

  # The magic glue
  typst-utils.url = "github:leonieziechmann/typst-nix-utils";
};
```

## Usage

### 1. "Package" Your Library

In your library repo (e.g., `my-core`), use `buildTypstPackage`. This prepares it for consumption by other projects.

```nix
# my-core/flake.nix
outputs = { ... }: {
  packages.default = typst-utils.lib.buildTypstPackage {
    inherit pkgs;
    pname = "my-core";
    version = "0.2.0-dev";
    src = ./.;
    # Only expose what matters (keeps cache small)
    files = [ "lib.typ" "typst.toml" "src" ];
  };
}
```

### 2. Consume It Immediately

In your consumer repo (e.g., `my-template`), import the library and create a development environment.

```nix
# my-template/flake.nix
inputs = {
  # ... other inputs ...
  # Point directly to your other project!
  my-core.url = "github:me/my-core";
  # OR for local dev: "path:../my-core";
};

outputs = { self, pkgs, typst-utils, my-core, ... }: {
  devShells.default = pkgs.mkShell {
    buildInputs = [
      (typst-utils.lib.mkTypstEnv {
        inherit pkgs;
        typst = pkgs.typst;
        packages = [
          # 🚀 THIS is the magic:
          my-core.packages.${system}.default

          # You can also add nixpkgs versions:
          # pkgs.typstPackages.codetastic
        ];
      })
    ];

    shellHook = ''
      echo "Ready! You can now #import \"@preview/my-core:0.2.0-dev\""
    '';
  };
}
```

## How It Works

* **`mkTypstEnv`**: Creates a custom `typst` binary.
* It points `TYPST_PACKAGE_PATH` to a read-only Nix store path containing your specific dependencies.
* It leaves `TYPST_PACKAGE_CACHE_PATH` untouched, so `typst` can still download other packages from the internet (hybrid mode).
* It handles the directory structure mismatch between Nixpkgs (`lib/`) and Typst (`share/`).


* **`buildTypstPackage`**: Installs your source files into the correct XDG structure (`share/typst/packages/preview/...`) so they are discoverable.

## 🚀 Publishing Workflow

This repository also includes a **Reusable GitHub Workflow** to automate publishing your packages to the [Typst Universe](https://github.com/typst/packages). It handles version extraction, file copying, and pushing to your fork of `typst/packages`.

Create a file at `.github/workflows/publish.yaml` in your package repository:

```yaml
name: Publish to Typst Universe

on:
  release:
    types: [published]

jobs:
  publish:
    # Use the shared workflow from this repo
    uses: leonieziechmann/typst-nix-utils/.github/workflows/publish-package.yaml@main
    with:
      # Target fork where the PR branch will be pushed
      fork_repo: leonieziechmann/packages

      # Optional: Override which files are included (Default: "typst.toml lib.typ src LICENSE README.md")
      # files: "typst.toml lib.typ assets template LICENSE README.md"

      # Optional: Path to package root if it's not in the repo root
      # package_path: "packages/my-lib"
    secrets:
      # A PAT with permission to push to your fork
      packages_pat: ${{ secrets.PACKAGES_PAT }}
```
