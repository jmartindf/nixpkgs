{
  lib,
  async-timeout,
  buildPythonPackage,
  deprecated,
  fetchFromGitHub,
  pympler,
  pytest-asyncio,
  pytest-lazy-fixtures,
  pytestCheckHook,
  pythonOlder,
  redis,
  wrapt,
}:

buildPythonPackage rec {
  pname = "coredis";
  version = "4.20.0";
  format = "setuptools";

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "alisaifee";
    repo = pname;
    tag = version;
    hash = "sha256-N7RQEgpBnXa+xtthySfec1Xw3JHtGCT2ZjmOK7H5B+A=";
  };

  postPatch = ''
    substituteInPlace pytest.ini \
      --replace "-K" ""
  '';

  propagatedBuildInputs = [
    async-timeout
    deprecated
    pympler
    wrapt
  ];

  nativeCheckInputs = [
    pytestCheckHook
    redis
    pytest-asyncio
    pytest-lazy-fixtures
  ];

  pythonImportsCheck = [ "coredis" ];

  pytestFlagsArray = [
    # All other tests require Docker
    "tests/test_lru_cache.py"
    "tests/test_parsers.py"
    "tests/test_retry.py"
    "tests/test_utils.py"
  ];

  meta = with lib; {
    description = "Async redis client with support for redis server, cluster & sentinel";
    homepage = "https://github.com/alisaifee/coredis";
    changelog = "https://github.com/alisaifee/coredis/blob/${src.tag}/HISTORY.rst";
    license = licenses.mit;
    teams = [ teams.wdz ];
  };
}
