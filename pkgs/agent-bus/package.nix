{
  lib,
  python3Packages,
  redis,
}:
python3Packages.buildPythonApplication {
  pname = "agent-bus";
  version = "0.1.0";
  pyproject = true;

  src = builtins.fetchGit {
    url = "ssh://git@github.com/h0lylag/agent-bus.git";
    rev = "1f1b6b1fc93e85c6201bc7df2568dd406303a580";
  };
  build-system = [ python3Packages.setuptools ];
  dependencies = [
    python3Packages.mcp
    python3Packages.redis
    python3Packages.pydantic
  ];
  nativeCheckInputs = with python3Packages; [
    pytestCheckHook
    pytest-asyncio
  ];
  # Tests launch only a temporary Redis instance and the installed stdio server.
  preCheck = ''
    export REDIS_SERVER=${redis}/bin/redis-server
    export AGENT_BUS_EXECUTABLE=$out/bin/agent-bus
  '';
  pythonImportsCheck = [ "agent_bus" ];
  meta = {
    description = "Local Redis Streams MCP mailbox";
    homepage = "https://github.com/h0lylag/agent-bus";
    mainProgram = "agent-bus";
    platforms = lib.platforms.linux;
  };
}
