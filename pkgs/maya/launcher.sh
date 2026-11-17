#!@runtimeShell@
# maya.py keeps its configs next to itself and looks there for its engines,
# build stamps, llama.cpp and Python environment, so it runs from a writable
# copy of the release. Models go to $MAYA_HOME/Maya-data.
set -euo pipefail

home=${MAYA_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/maya}
app=$home/app
release=@out@/share/maya/release

if [ "$(cat "$app/.nix-release" 2>/dev/null || true)" != "$release" ]; then
  mkdir -p "$app"
  # The build stamps hash these sources, so a file left over from an older
  # release would make the setup compile the engines again.
  rm -rf "$app"/{CMakeLists.txt,cmake,src,include,third_party/ggml,third_party/llama.cpp,tools/vision} \
    "$app"/build-hip "$app"/build-vision "$app"/.venv
  cp -rT --no-preserve=mode,ownership "$release" "$app"
  @python@ -m venv --system-site-packages "$app/.venv"
  cp @out@/share/maya/pip-stamp.json "$app/.venv/.strata-pip.json"
  echo "$release" >"$app/.nix-release"
fi

export ROCM_PATH=@rocm@
# The dashboard's self-update is a git pull, which this copy cannot do.
export MAYA_UPDATE_CHECK=0
# The HIP setup's checks look for a C++ compiler even with the engines built.
export PATH=@cc@/bin:$PATH

exec "$app/.venv/bin/python" "$app/maya.py" "$@"
