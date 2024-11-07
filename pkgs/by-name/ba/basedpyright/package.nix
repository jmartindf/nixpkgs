{
  lib,
  fetchFromGitHub,
  runCommand,
  buildNpmPackage,
  stdenvNoCC,
  docify,
  testers,
  writeText,
  jq,
  basedpyright,
  pkg-config,
  libsecret,
  nix-update-script,
}:

let
  version = "1.21.0";

  src = fetchFromGitHub {
    owner = "detachhead";
    repo = "basedpyright";
    rev = "refs/tags/v${version}";
    hash = "sha256-OQXqwpvYIitWGWshEv1/j2hAphFnGXDuvbRav5TilI4=";
  };

  docstubs = stdenvNoCC.mkDerivation {
    name = "docstubs";
    inherit src;
    nativeBuildInputs = [ docify ];

    installPhase = ''
      runHook preInstall
      cp -r packages/pyright-internal/typeshed-fallback docstubs
      docify docstubs/stdlib --builtins-only --in-place
      cp -rv docstubs "$out"
      runHook postInstall
    '';
  };
in
buildNpmPackage rec {
  pname = "basedpyright";
  inherit version src;

  # sourceRoot = "${src.name}/packages/pyright";
  npmDepsHash = "sha256-hCZ68sLpQs/7SYVf3pMAHfstRm1C/d80j8fESIFdhnw=";

  postPatch = ''
    ln -s ${docstubs} docstubs
  '';

  postInstall = ''
    mv "$out/bin/pyright" "$out/bin/basedpyright"
    mv "$out/bin/pyright-langserver" "$out/bin/basedpyright-langserver"
  '';

  # dontNpmBuild = true;
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libsecret ];
  npmWorkspace = "packages/pyright";

  passthru = {
    updateScript = nix-update-script { };
    tests = {
      version = testers.testVersion { package = basedpyright; };

      # We are expecting 3 errors. Any other amount would indicate, not working
      # stub files, for instance.
      simple = testers.testEqualContents {
        assertion = "simple type checking";
        expected = writeText "expected" ''
          4
        '';
        actual =
          runCommand "actual"
            {
              nativeBuildInputs = [
                jq
                basedpyright
              ];
              base = writeText "test.py" ''
                import sys
                from time import tzset

                def print_string(a_string: str):
                    a_string += 42
                    print(a_string)

                if sys.platform == "win32":
                    print_string(69)
                    this_function_does_not_exist("nice!")
                else:
                    result_of_tzset_is_None: str = tzset()
              '';
              configFile = writeText "pyproject.toml" ''
                [tool.pyright]
                typeCheckingMode = "strict"  # wrong! the setting you're looking for is called `typeCheckingMode`
              '';
            }
            ''
              (basedpyright $base || true)
              (basedpyright --outputjson $base || true) | jq -r .summary.errorCount > $out
            '';
      };
    };
  };

  meta = {
    changelog = "https://github.com/detachhead/basedpyright/releases/tag/${version}";
    description = "Type checker for the Python language";
    homepage = "https://github.com/detachhead/basedpyright";
    license = lib.licenses.mit;
    mainProgram = "basedpyright";
    maintainers = with lib.maintainers; [ kiike ];
  };
}
