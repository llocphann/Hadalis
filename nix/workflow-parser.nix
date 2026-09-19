{ pkgs }:

let
  lib = pkgs.lib;
  version = "0.3.1";
  treeSitterLib = lib.getLib pkgs.tree-sitter;
in
pkgs.stdenv.mkDerivation {
  pname = "inir-workflow-parser";
  inherit version;

  src = pkgs.fetchurl {
    name = "tree-sitter-qmljs-${version}.tar.gz";
    url = "https://static.crates.io/crates/tree-sitter-qmljs/tree-sitter-qmljs-${version}.crate";
    hash = "sha256-5u06cEDfVP7RGDgBrUghOWIr+bnsHF9+42xeziWAbFg=";
  };

  strictDeps = true;

  buildPhase = ''
    runHook preBuild
    "$CC" $CFLAGS $CPPFLAGS -std=c11 -fPIC -shared -I src \
      src/parser.c src/scanner.c $LDFLAGS -o qmljs.so
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 qmljs.so "$out/lib/inir/code-workflow/qmljs.so"
    install -Dm644 LICENSE "$out/share/licenses/$pname/LICENSE"
    runHook postInstall
  '';

  passthru = {
    grammarPath = "lib/inir/code-workflow/qmljs.so";
    treeSitterLibrary = "${treeSitterLib}/lib/libtree-sitter.so";
  };

  meta = {
    description = "Native tree-sitter QML grammar for Hadalis Code Workflow";
    homepage = "https://github.com/yuja/tree-sitter-qmljs";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
