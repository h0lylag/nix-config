_final: _prev: {
  # fastmcp 3.2.3's stateful proxy client tests fail with "Attempted to exit a
  # cancel scope that isn't the current task's" in the Nix sandbox, which
  # blocks mcp-nixos. The other ~4700 tests pass.
  pythonPackagesExtensions = _prev.pythonPackagesExtensions ++ [
    (_pyFinal: pyPrev: {
      fastmcp = pyPrev.fastmcp.overridePythonAttrs (old: {
        disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
          "tests/server/providers/proxy/test_stateful_proxy_client.py"
        ];
      });
    })
  ];
}
