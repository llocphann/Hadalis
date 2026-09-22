{
  description = "Hadalis desktop shell runtime, packaged for NixOS and Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      nixosModule = import ./nix/nixos-module.nix;
      homeModule = import ./nix/home-module.nix;
    in
    {
      packages = forAllSystems (pkgs:
        let
          package = pkgs.callPackage ./nix/package.nix { inherit pkgs; };
          workflowParser = pkgs.callPackage ./nix/workflow-parser.nix { inherit pkgs; };
          packageWithWorkflowParser = pkgs.callPackage ./nix/package.nix {
            inherit pkgs;
            withWorkflowParser = true;
          };
        in
        {
          default = package;
          inir = package;
          inir-workflow-parser = workflowParser;
          inir-with-workflow-parser = packageWithWorkflowParser;
        });

      devShells = forAllSystems (pkgs:
        let
          package = pkgs.callPackage ./nix/package.nix { inherit pkgs; };
          workflowParser = pkgs.callPackage ./nix/workflow-parser.nix { inherit pkgs; };
        in
        {
          workflow-acceptance = pkgs.mkShell {
            packages =
              package.passthru.runtimeDependencies
              ++ [
                pkgs.python3
                pkgs.sway
                pkgs.niri
                pkgs.dbus
                pkgs.pkg-config
                pkgs.wayland
                pkgs.stdenv.cc
                workflowParser
              ];

            QML2_IMPORT_PATH = lib.makeSearchPath
              "lib/qt-6/qml"
              package.passthru.qmlDependencies;
            QT_PLUGIN_PATH = lib.makeSearchPath
              "lib/qt-6/plugins"
              package.passthru.qmlDependencies;
            HADALIS_WORKFLOW_MESA_DRIVERS = "${pkgs.mesa.drivers}";
            HADALIS_WORKFLOW_GRAMMAR =
              "${workflowParser}/lib/inir/code-workflow/qmljs.so";
            HADALIS_TREE_SITTER_LIBRARY =
              workflowParser.passthru.treeSitterLibrary;
            HADALIS_WORKFLOW_DBUS_RUN_SESSION =
              "${pkgs.dbus}/bin/dbus-run-session";
            HADALIS_WORKFLOW_DBUS_DAEMON =
              "${pkgs.dbus}/bin/dbus-daemon";
            HADALIS_WORKFLOW_DBUS_SESSION_CONFIG =
              "${pkgs.dbus}/share/dbus-1/session.conf";
          };
        });

      nixosModules.default = nixosModule;
      nixosModules.inir = nixosModule;

      homeModules.default = homeModule;
      homeModules.inir = homeModule;

      # Conventional alias most Home Manager setups look for.
      homeManagerModules.default = homeModule;
      homeManagerModules.inir = homeModule;

      formatter = forAllSystems (pkgs: pkgs.nixpkgs-fmt);
    };
}
