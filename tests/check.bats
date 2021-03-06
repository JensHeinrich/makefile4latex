MAKE_ARGS=
NO_CLEAN=
WITH_LONG_NAME=

# test_dir <directory>
# test_dir <directory> <number of runs>
test_dir() {(
  set -eu
  set -o pipefail

  (
    cd "$1"
    if [ -n "$WITH_LONG_NAME" ]; then
      longsuffix=-very-long-abcd-efgh-ijkl-mnop-qrst-uvwx-yzab-cdef-ghij-klmn-opqr-stuv-wxyz-1234-5678-9012-3456-7890
      longname=${WITH_LONG_NAME%.*}$longsuffix.${WITH_LONG_NAME##*.}
      if [ ! -f "$longname" ]; then
        ln -s "$WITH_LONG_NAME" "$longname"
      fi
    fi
    [ -n "$NO_CLEAN" ] || make clean
    make $MAKE_ARGS | tee make.out
  )

  if grep 'Rerun' $1/*.log | grep -v 'Package: rerunfilecheck\|rerunfilecheck.sty'; then
    echo "FAIL: documents incomplete"
    exit 1
  fi

  [ $# -le 1 ] && return

  num=$(grep halt-on-error "$1/make.out" | wc -l)
  if [ $2 -ne $num ]; then
    echo "FAIL: wrong number of running LaTeX: $num (must be $2)" >&2
    exit 1
  fi

  rm "$1/make.out"
)}

# check_tarball <file> <number of files>
check_tarball() {(
  set -eu
  set -o pipefail

  num=$(tar tf "$1" | wc -l)
  if [ $2 -ne $num ]; then
    echo "FAIL: wrong number of files in archive $1: $num (must be $2)" >&2
    exit 1
  fi
)}

@test "latex" {
  test_dir latex 5
}

@test "bibtex" {
  WITH_LONG_NAME=doc.tex test_dir bibtex 6
}

@test "makeindex" {
  WITH_LONG_NAME=doc.tex test_dir makeindex 4
}

@test "makeglossaries" {
  WITH_LONG_NAME=doc.tex test_dir makeglossaries 4
}

@test "axohelp" {
  WITH_LONG_NAME=doc.tex test_dir axohelp 4
}

@test "platex_dvipdfmx" {
  test_dir platex_dvipdfmx 1
}

@test "dist" {
  MAKE_ARGS='dist' test_dir bibtex && \
  check_tarball bibtex/doc.tar.gz 2 && \
  MAKE_ARGS='dist' test_dir makeindex && \
  check_tarball makeindex/doc.tar.gz 2 && \
  MAKE_ARGS='dist' test_dir makeglossaries && \
  check_tarball makeglossaries/doc.tar.gz 3
}

@test "latexdiff1" {
  MAKE_ARGS='DIFF=HEAD' test_dir latexdiff 3
}

@test "latexdiff2" {
  MAKE_ARGS='DIFF=HEAD' test_dir latexdiff 3 && \
  MAKE_ARGS='DIFF=44aaae0' NO_CLEAN=1 test_dir latexdiff 2 && \
  MAKE_ARGS='DIFF=44aaae0..HEAD' NO_CLEAN=1 test_dir latexdiff 1
}

teardown() {
  find . -name make.out -exec rm {} \;
  find . -name '*-very-long-*' -exec rm {} \;
}
