{ rustPlatform
, fetchFromGitHub
, lib
, openssl
, pkg-config
, stdenv
, Security
, SystemConfiguration
}:
rustPlatform.buildRustPackage rec {
  pname = "sentry-cli";
  version = "2.17.5";

  src = fetchFromGitHub {
    owner = "getsentry";
    repo = "sentry-cli";
    rev = version;
    sha256 = "sha256-7qBw0MT1FM1rAbOEtVuf/XEBY8yosRWsnGwVbqpc3QQ=";
  };
  doCheck = false;

  # Needed to get openssl-sys to use pkgconfig.
  OPENSSL_NO_VENDOR = 1;

  buildInputs = [ openssl ] ++ lib.optionals stdenv.isDarwin [ Security SystemConfiguration ];
  nativeBuildInputs = [ pkg-config ];

  cargoHash = "sha256-LAasV0rY4jgoC+soBshECUXvXYIe5zQZmnKtBONAD6g=";

  meta = with lib; {
    homepage = "https://docs.sentry.io/cli/";
    license = licenses.bsd3;
    description = "A command line utility to work with Sentry";
    changelog = "https://github.com/getsentry/sentry-cli/raw/${version}/CHANGELOG.md";
    maintainers = with maintainers; [ rizary ];
  };
}
