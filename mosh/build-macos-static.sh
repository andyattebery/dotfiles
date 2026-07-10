#!/usr/bin/env bash
#
# Build mosh on macOS against a private, statically-linked protobuf + abseil.
#
# Homebrew's protobuf ships only dylibs whose filenames encode the version
# (libprotobuf.35.0.0.dylib), so `brew upgrade protobuf` deletes the library
# mosh-client is linked against and mosh dies at startup with a dyld error.
# Homebrew's protoc also drifts out of sync with generated .pb.h files.
#
# Linking protobuf statically from a pinned prefix removes both failure modes:
# the resulting binaries reference no Homebrew library at all, and protoc is
# frozen alongside the runtime it generated code for.
#
# Usage:
#   ./build-macos-static.sh              build (uses versions.lock if present)
#   ./build-macos-static.sh --install    build, gate tests, `sudo make install`
#   ./build-macos-static.sh --update     re-resolve latest versions, rewrite lock
#   ./build-macos-static.sh --clean      delete artifacts and exit (keeps the lock)
#   ./build-macos-static.sh --force-deps rebuild the dep prefix, then continue
#   ./build-macos-static.sh --check-all  run mosh's entire suite, not just the gate

set -euo pipefail

CACHE_ROOT="$HOME/Library/Caches/mosh-build"
DATA_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/mosh-deps"
LOCK="$DATA_ROOT/versions.lock"
INSTALL_PREFIX=/usr/local
JOBS=$(sysctl -n hw.ncpu)

PB_REPO=protocolbuffers/protobuf
MOSH_REPO=mobile-shell/mosh

log()  { printf '\n==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() { sed -n '3,21p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

# The gate for --install. mosh's full `make check` takes 5+ minutes, almost all
# of it the ~26 `displaytests` -- terminal-emulation rendering, which this build
# does not touch. What this build *does* change is the protobuf runtime, and the
# only cheap test that round-trips all three .proto files through a real
# mosh-client <-> mosh-server session is local.test (~0.5s). The four unit tests
# (crypto, base64) add ~0.6s and no protobuf coverage, but are near-free sanity.
# Together ~1.1s. Use --check-all for the whole suite.
GATE_TESTS='ocb-aes encrypt-decrypt base64 nonce-incr local.test'

do_install=0 do_update=0 do_clean=0 force_deps=0 check_all=0
while [ $# -gt 0 ]; do
  case $1 in
    --install)    do_install=1 ;;
    --update)     do_update=1 ;;
    --clean)      do_clean=1 ;;
    --force-deps) force_deps=1 ;;
    --check-all)  check_all=1 ;;
    -h|--help)    usage 0 ;;
    *)            printf 'unknown option: %s\n\n' "$1" >&2; usage 1 ;;
  esac
  shift
done

# otool and -framework CoreFoundation are macOS-specific.
[ "$(uname -s)" = Darwin ] || die "this script only supports macOS"

for tool in cmake pkg-config curl shasum jq tar otool make; do
  command -v "$tool" >/dev/null || die "missing required tool: $tool"
done

# ---------------------------------------------------------------- clean

if [ "$do_clean" -eq 1 ]; then
  printf 'This will delete:\n'
  printf '  %s\n' "$CACHE_ROOT"
  for p in "$DATA_ROOT"/pb*-absl*/; do
    [ -d "$p" ] && printf '  %s\n' "$p"
  done
  # The lock is the reproducibility anchor: a clean rebuild must be able to
  # reproduce the build it just cleaned. Only --update moves versions.
  printf '\nPreserved: %s\n' "$LOCK"
  printf '\nProceed? [y/N] '
  read -r reply
  case $reply in
    [yY]|[yY][eE][sS]) ;;
    *) die "aborted" ;;
  esac
  rm -rf "$CACHE_ROOT"
  for p in "$DATA_ROOT"/pb*-absl*/; do
    [ -d "$p" ] && rm -rf "$p"
  done
  log "cleaned"
  exit 0
fi

# ---------------------------------------------------------------- lockfile

PB_VER='';   PB_SHA=''
ABSL_VER=''; ABSL_SHA=''
MOSH_VER=''; MOSH_SHA=''

read_lock() {
  [ -f "$LOCK" ] || return 1
  PB_VER=$(awk   '$1=="protobuf"{print $2}' "$LOCK")
  PB_SHA=$(awk   '$1=="protobuf"{print $3}' "$LOCK")
  ABSL_VER=$(awk '$1=="abseil"  {print $2}' "$LOCK")
  ABSL_SHA=$(awk '$1=="abseil"  {print $3}' "$LOCK")
  MOSH_VER=$(awk '$1=="mosh"    {print $2}' "$LOCK")
  MOSH_SHA=$(awk '$1=="mosh"    {print $3}' "$LOCK")
  [ -n "$PB_VER$PB_SHA$ABSL_VER$ABSL_SHA$MOSH_VER$MOSH_SHA" ] || return 1
  [ -n "$PB_VER" ] && [ -n "$ABSL_VER" ] && [ -n "$MOSH_VER" ] || return 1
}

write_lock() {
  mkdir -p "$DATA_ROOT"
  { printf 'protobuf %s %s\n' "$PB_VER"   "$PB_SHA"
    printf 'abseil %s %s\n'   "$ABSL_VER" "$ABSL_SHA"
    printf 'mosh %s %s\n'     "$MOSH_VER" "$MOSH_SHA"
  } > "$LOCK"
  log "wrote $LOCK"
}

gh_latest_tag() { curl -fsSL "https://api.github.com/repos/$1/releases/latest" | jq -r .tag_name; }

pb_url()   { printf 'https://github.com/%s/releases/download/v%s/protobuf-%s.tar.gz' "$PB_REPO" "$1" "$1"; }
absl_url() { printf 'https://github.com/abseil/abseil-cpp/releases/download/%s/abseil-cpp-%s.tar.gz' "$1" "$1"; }
mosh_url() { printf 'https://github.com/%s/releases/download/mosh-%s/mosh-%s.tar.gz' "$MOSH_REPO" "$1" "$1"; }

# fetch <url> <dest> [expected_sha]  -- prints the sha256 on stdout
fetch() {
  local url=$1 dest=$2 want=${3:-} got
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ]; then
    got=$(shasum -a 256 "$dest" | cut -d' ' -f1)
    if [ -z "$want" ] || [ "$got" = "$want" ]; then printf '%s' "$got"; return; fi
    warn "checksum mismatch on cached $(basename "$dest"), refetching"
    rm -f "$dest"
  fi
  log "fetching $(basename "$dest")" >&2
  curl -fsSL --retry 3 -o "$dest" "$url"
  got=$(shasum -a 256 "$dest" | cut -d' ' -f1)
  if [ -n "$want" ] && [ "$got" != "$want" ]; then
    die "checksum mismatch for $url
  expected $want
  got      $got"
  fi
  printf '%s' "$got"
}

# extract <tarball> <parent_dir> <expected_subdir>
# Never `tar -m`: it stamps every file with the extraction time, which inverts
# the configure/configure.ac mtime ordering and wakes automake's rebuild rules.
extract() {
  local tarball=$1 parent=$2 sub=$3
  mkdir -p "$parent"
  rm -rf "${parent:?}/${sub:?}"
  tar xzf "$tarball" -C "$parent"
  [ -d "$parent/$sub" ] || die "expected $parent/$sub after extracting $tarball"
}

# ---------------------------------------------------------------- resolve

if [ "$do_update" -eq 1 ] || ! read_lock; then
  log "resolving latest versions"
  PB_VER=$(gh_latest_tag "$PB_REPO");   PB_VER=${PB_VER#v}
  MOSH_VER=$(gh_latest_tag "$MOSH_REPO"); MOSH_VER=${MOSH_VER#mosh-}
  [ -n "$PB_VER" ] && [ -n "$MOSH_VER" ] || die "could not resolve latest versions"
  log "protobuf $PB_VER, mosh $MOSH_VER"

  PB_TAR="$CACHE_ROOT/dist/protobuf-$PB_VER.tar.gz"
  PB_SHA=$(fetch "$(pb_url "$PB_VER")" "$PB_TAR")
  extract "$PB_TAR" "$CACHE_ROOT/src" "protobuf-$PB_VER"

  # Derived, never "latest": protobuf is only tested against the abseil version
  # its MODULE.bazel declares. Homebrew ships a different one.
  derived=$(awk -F'"' '/bazel_dep\(name = "abseil-cpp"/{print $4}' \
              "$CACHE_ROOT/src/protobuf-$PB_VER/MODULE.bazel")
  [ -n "$derived" ] || die "could not derive abseil version from protobuf MODULE.bazel"
  if [ -n "$ABSL_VER" ] && [ "$ABSL_VER" != "$derived" ] && [ "$do_update" -eq 0 ]; then
    die "lock says abseil $ABSL_VER but protobuf $PB_VER wants $derived; re-run with --update"
  fi
  ABSL_VER=$derived
  log "abseil $ABSL_VER (derived from protobuf's MODULE.bazel)"

  ABSL_SHA=$(fetch "$(absl_url "$ABSL_VER")" "$CACHE_ROOT/dist/abseil-cpp-$ABSL_VER.tar.gz")
  MOSH_SHA=$(fetch "$(mosh_url "$MOSH_VER")" "$CACHE_ROOT/dist/mosh-$MOSH_VER.tar.gz")
  write_lock
else
  log "using $LOCK: protobuf $PB_VER, abseil $ABSL_VER, mosh $MOSH_VER"
fi

PREFIX="$DATA_ROOT/pb${PB_VER}-absl${ABSL_VER}"

# ---------------------------------------------------------------- deps

build_deps() {
  local pb_tar="$CACHE_ROOT/dist/protobuf-$PB_VER.tar.gz"
  local absl_tar="$CACHE_ROOT/dist/abseil-cpp-$ABSL_VER.tar.gz"
  fetch "$(pb_url "$PB_VER")"     "$pb_tar"   "$PB_SHA"   >/dev/null
  fetch "$(absl_url "$ABSL_VER")" "$absl_tar" "$ABSL_SHA" >/dev/null
  extract "$absl_tar" "$CACHE_ROOT/src" "abseil-cpp-$ABSL_VER"
  [ -d "$CACHE_ROOT/src/protobuf-$PB_VER" ] || extract "$pb_tar" "$CACHE_ROOT/src" "protobuf-$PB_VER"

  # Abseil first: the protobuf tarball does not bundle it, and protobuf's
  # cmake/abseil-cpp.cmake resolves it via find_package(absl CONFIG).
  log "building abseil $ABSL_VER (static)"
  cmake -S "$CACHE_ROOT/src/abseil-cpp-$ABSL_VER" -B "$CACHE_ROOT/build/absl" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DABSL_ENABLE_INSTALL=ON \
    -DABSL_PROPAGATE_CXX_STD=ON \
    -DABSL_BUILD_TESTING=OFF \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON >/dev/null
  cmake --build "$CACHE_ROOT/build/absl" -j"$JOBS" --target install >/dev/null

  log "building protobuf $PB_VER (static)"
  cmake -S "$CACHE_ROOT/src/protobuf-$PB_VER" -B "$CACHE_ROOT/build/protobuf" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_PREFIX_PATH="$PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -Dprotobuf_BUILD_SHARED_LIBS=OFF \
    -Dprotobuf_BUILD_TESTS=OFF \
    -Dprotobuf_BUILD_PROTOC_BINARIES=ON \
    -Dprotobuf_INSTALL=ON \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON >/dev/null
  cmake --build "$CACHE_ROOT/build/protobuf" -j"$JOBS" --target install >/dev/null
}

[ "$force_deps" -eq 1 ] && rm -rf "$PREFIX"
if [ -f "$PREFIX/lib/libprotobuf.a" ] && [ -x "$PREFIX/bin/protoc" ]; then
  log "dep prefix present: $PREFIX"
else
  build_deps
fi
[ -f "$PREFIX/lib/libprotobuf.a" ] || die "dep build produced no libprotobuf.a"
[ -x "$PREFIX/bin/protoc" ]        || die "dep build produced no protoc"

# ---------------------------------------------------------------- mosh

MOSH_TAR="$CACHE_ROOT/dist/mosh-$MOSH_VER.tar.gz"
MOSH_SRC="$CACHE_ROOT/src/mosh-$MOSH_VER"
fetch "$(mosh_url "$MOSH_VER")" "$MOSH_TAR" "$MOSH_SHA" >/dev/null
extract "$MOSH_TAR" "$CACHE_ROOT/src" "mosh-$MOSH_VER"

cd "$MOSH_SRC"

# mosh declares no AM_MAINTAINER_MODE, so automake's rebuild rules are live. The
# dist tarball's mtimes keep them dormant. Assert that rather than trust it: a
# `tar -m` extraction would silently trigger an autoconf/automake run.
[ configure -nt configure.ac ] \
  || die "configure is not newer than configure.ac; automake rebuild rules would fire (was this extracted with 'tar -m'?)"

# mosh 1.4.0 does AX_CXX_COMPILE_STDCXX([11]) whenever protobuf >= 3.6, which
# forces -std=gnu++11; protobuf 35 headers require C++17. Presetting CXXFLAGS
# also suppresses autoconf's own `-g -O2` default (configure: ac_test_CXXFLAGS),
# so -O2 -g must be restated here or the binary ships unoptimized.
#
# Abseil's generated .pc omits -framework CoreFoundation, which cctz's
# local_time_zone() needs; static archives push it onto the consumer.
log "configuring mosh $MOSH_VER against $PREFIX"
env \
  PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}" \
  PROTOC="$PREFIX/bin/protoc" \
  CXXFLAGS="-O2 -g -std=gnu++17" \
  LDFLAGS="-framework CoreFoundation${LDFLAGS:+ $LDFLAGS}" \
  ./configure --prefix="$INSTALL_PREFIX"

mk_cxxflags=$(awk -F= '/^CXXFLAGS[[:space:]]*=/{sub(/^[^=]*=/,""); print; exit}' Makefile)
case $mk_cxxflags in
  *-std=gnu++17*) ;;
  *) die "configure dropped -std=gnu++17 (Makefile CXXFLAGS:$mk_cxxflags)" ;;
esac
case $mk_cxxflags in
  *-O2*) ;;
  *) die "configure dropped -O2, binary would be unoptimized (Makefile CXXFLAGS:$mk_cxxflags)" ;;
esac

log "building mosh $MOSH_VER"
make -j"$JOBS"

# ---------------------------------------------------------------- verify

# The load-bearing check. If any of the pinning above silently regresses, mosh
# picks Homebrew's protobuf back up and this is what catches it. mosh-client is
# checked first: it is the binary actually used on this Mac.
verify_static() {
  local status=0 bin
  for bin in "$@"; do
    [ -x "$bin" ] || { printf 'missing binary: %s\n' "$bin" >&2; status=1; continue; }
    if otool -L "$bin" | tail -n +2 | grep -Eq 'protobuf|absl|utf8_'; then
      printf '%s still links protobuf/abseil dynamically:\n' "$bin" >&2
      otool -L "$bin" | grep -E 'protobuf|absl|utf8_' >&2
      status=1
    fi
  done
  return $status
}

log "verifying built binaries carry no dynamic protobuf/abseil"
verify_static src/frontend/mosh-client src/frontend/mosh-server \
  || die "static-link verification failed"

if otool -L src/frontend/mosh-client | tail -n +2 | grep -q /opt/homebrew; then
  log "note: mosh-client links these Homebrew libraries (not pinned by this script)"
  otool -L src/frontend/mosh-client | grep /opt/homebrew
fi

# ---------------------------------------------------------------- install

if [ "$do_install" -eq 1 ]; then
  # Never sudo-install something whose tests did not pass. Scoped to what this
  # build actually changes -- see GATE_TESTS above.
  if [ "$check_all" -eq 1 ]; then
    log "running mosh's full test suite (slow: 5+ min)"
    make check
  else
    log "running gate tests: $GATE_TESTS"
    make -C src/tests check TESTS="$GATE_TESTS"
  fi

  # Prompt for the password explicitly, outside any redirected output.
  log "requesting sudo for 'make install' to $INSTALL_PREFIX"
  sudo -v

  log "installing to $INSTALL_PREFIX"
  sudo make install

  # `make install` copies a different file than the one verified above.
  log "verifying installed binaries"
  verify_static "$INSTALL_PREFIX/bin/mosh-client" "$INSTALL_PREFIX/bin/mosh-server" \
    || die "installed binaries failed static-link verification"

  log "installed: $("$INSTALL_PREFIX/bin/mosh-client" --version | head -1)"
else
  log "built: $(./src/frontend/mosh-client --version | head -1)"
  log "re-run with --install to 'make check' and 'sudo make install' to $INSTALL_PREFIX"
fi
