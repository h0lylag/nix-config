{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  versioneer,
  scantree,
}:

buildPythonPackage rec {
  pname = "dirhash";
  version = "0.5.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-5gdg8Ksuk12MsIiSPqLGSSOY3KQs7Hhd93iYX9TNU4Y=";
  };

  build-system = [
    setuptools
    versioneer
  ];

  dependencies = [
    scantree
  ];

  # Upstream tests drive external hashers and a hardcoded digest corpus; they
  # do not exercise the library surface harbor uses.
  doCheck = false;

  pythonImportsCheck = [ "dirhash" ];

  meta = with lib; {
    description = "Python module and CLI for hashing of file system directories";
    homepage = "https://github.com/andhus/dirhash-python";
    license = licenses.mit;
  };
}
