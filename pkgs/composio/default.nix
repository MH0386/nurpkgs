{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  nodejs,
  bun,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "composio";
  version = "0.2.24";

  src = fetchFromGitHub {
    owner = "ComposioHQ";
    repo = "composio";
    tag = "@composio/cli@${finalAttrs.version}";
    hash = "sha256-jpoeELnc5O/cP4QNC9PGHvmvinEXk7Igdkzo5Pc4QTc=";
  };

  pnpmWorkspaces = [
    "@composio/cli..."
    "@composio/cli-keyring..."
    "@composio/core..."
    "@composio/json-schema-to-zod..."
    "@composio/ts-builders..."
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src pnpmWorkspaces;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-1l+OxYrupHMSM+S03b0+UqwJhZNE/DYlHTBXcNrKjts=";
  };

  nativeBuildInputs = [
    bun
    makeWrapper
    nodejs
    pnpm_10
    pnpmConfigHook
  ];

  postPatch = ''
    substituteInPlace ts/packages/cli/package.json \
      --replace-fail '"version": "0.2.23"' '"version": "${finalAttrs.version}"'
  '';

  buildPhase = ''
    runHook preBuild

    export LD_LIBRARY_PATH="${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}''${LD_LIBRARY_PATH:+:}$LD_LIBRARY_PATH"

    echo "=== Building cli-keyring ==="
    pnpm --dir ts/packages/cli-keyring run build

    echo "=== Building core ==="
    pnpm --dir ts/packages/core run build

    echo "=== Building json-schema-to-zod ==="
    pnpm --dir ts/packages/json-schema-to-zod run build

    echo "=== Building ts-builders ==="
    pnpm --dir ts/packages/ts-builders run build

    bun run --cwd ts/packages/cli ./scripts/build-binary.ts

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    installDir="$out/libexec/composio"
    mkdir -p "$installDir" "$out/bin"

    cp -r ts/packages/cli/dist/. "$installDir"/
    chmod +x "$installDir/composio"
    printf '%s\n' '@composio/cli@${finalAttrs.version}' > "$installDir/release-tag.txt"

    makeWrapper "$installDir/composio" "$out/bin/composio" \
      ${lib.optionalString stdenv.hostPlatform.isLinux ''--prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [ stdenv.cc.cc ]
      }"''}

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/composio" --version
    runHook postInstallCheck
  '';

  meta = {
    description = "CLI for generating and managing Composio integrations";
    homepage = "https://github.com/ComposioHQ/composio";
    changelog = "https://github.com/ComposioHQ/composio/releases/tag/%40composio%2Fcli%40${finalAttrs.version}";
    downloadPage = "https://github.com/ComposioHQ/composio/releases";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.MH0386 ];
    mainProgram = "composio";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
  };
})
