{ lib
, installShellFiles
, python3
, fetchFromGitHub
, nix-update-script
, testers
, gimme-aws-creds
}:

let
  python = python3.override {
    packageOverrides = self: super: {
      fido2 = super.fido2.overridePythonAttrs (oldAttrs: rec {
        version = "0.9.3";
        format = "setuptools";
        src = self.fetchPypi {
          inherit (oldAttrs) pname;
          inherit version;
          hash = "sha256-tF6JphCc/Lfxu1E3dqotZAjpXEgi+DolORi5RAg0Zuw=";
        };
      });

      okta = super.okta.overridePythonAttrs (oldAttrs: rec {
        version = "0.0.4";
        format = "setuptools";
        src = self.fetchPypi {
          inherit (oldAttrs) pname;
          inherit version;
          hash = "sha256-U+eSxo02hP9BQLTLHAKvOCEJA2j4EQ/eVMC9tjhEkzI=";
        };
        propagatedBuildInputs = [
          self.six
          self.python-dateutil
          self.requests
        ];
        pythonImportsCheck = [ "okta" ];
        doCheck = false; # no tests were included with this version
      });
    };
  };
in
python.pkgs.buildPythonApplication rec {
  pname = "gimme-aws-creds";
  version = "2.6.1"; # N.B: if you change this, check if overrides are still up-to-date
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "Nike-Inc";
    repo = "gimme-aws-creds";
    rev = "v${version}";
    hash = "sha256-h54miRSZWT1mG63k7imJfQU1fdVr3Zc2gcyuP5511EQ=";
  };

  nativeBuildInputs = with python.pkgs; [
    installShellFiles
    pythonRelaxDepsHook
  ];

  pythonRemoveDeps = [
    "configparser"
  ];

  propagatedBuildInputs = with python.pkgs; [
    boto3
    fido2
    beautifulsoup4
    ctap-keyring-device
    requests
    okta
    pyjwt
  ];

  checkInputs = with python.pkgs; [
    pytestCheckHook
    responses
  ];

  disabledTests = [
    "test_build_factor_name_webauthn_registered"
  ];

  pythonImportsCheck = [
    "gimme_aws_creds"
  ];

  postInstall = ''
    rm $out/bin/gimme-aws-creds.cmd
    chmod +x $out/bin/gimme-aws-creds
    installShellCompletion --bash --name gimme-aws-creds $out/bin/gimme-aws-creds-autocomplete.sh
    rm $out/bin/gimme-aws-creds-autocomplete.sh
  '';

  passthru = {
    inherit python;
    updateScript = nix-update-script {
      attrPath = pname;
    };
    tests.version = testers.testVersion {
      package = gimme-aws-creds;
      command = ''touch tmp.conf && OKTA_CONFIG="tmp.conf" gimme-aws-creds --version'';
      version = "gimme-aws-creds ${version}";
    };
  };

  meta = with lib; {
    homepage = "https://github.com/Nike-Inc/gimme-aws-creds";
    changelog = "https://github.com/Nike-Inc/gimme-aws-creds/releases";
    description = "A CLI that utilizes Okta IdP via SAML to acquire temporary AWS credentials";
    license = licenses.asl20;
    maintainers = with maintainers; [ jbgosselin ];
  };
}
