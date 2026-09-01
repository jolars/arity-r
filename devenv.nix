{ pkgs, ... }:

{
  packages = [
    pkgs.arity
    pkgs.bashInteractive
    pkgs.checkbashisms
    pkgs.go-task
  ];

  languages = {
    rust = {
      enable = true;
      toolchainFile = ./src/rust/rust-toolchain.toml;
    };

    r = {
      enable = true;
      package = (
        pkgs.rWrapper.override {
          packages = with pkgs.rPackages; [
            covr
            devtools
            rextendr
            rmarkdown
            roxygen2
            testthat
            urlchecker
            pkgdown
          ];
        }
      );
    };
  };
}
