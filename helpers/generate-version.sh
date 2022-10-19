#!/bin/bash

# Globals
HL='\033[0;34m\033[1m' # Highlight
WA='\033[0;33m\033[1m' # Warning
NC='\033[0m' # No Color

command -v git >/dev/null 2>&1 || {
  echo -e "💥  ${WA}git CLI is not installed.$NC";
  exit 1
}

if [ ! -d ".git" ]; then
  echo -e "💥  ${WA}This is not a git repository.$NC Please run inside root directory of a repository."
  exit 1
fi

# Variables
OUTPUT_INI=
OUTPUT_JSON=
OUTPUT_SH=
AHEAD=`git rev-list "$(git describe --tags --abbrev=0 2> /dev/null)"..HEAD --count 2> /dev/null`
AHEAD=${AHEAD:-"no version found"}
COMMIT=`git rev-parse --verify HEAD`
SHORT=`git rev-parse --short HEAD`
TIMESTAMP=`date -u +"%Y-%m-%dT%H:%M:%SZ"`

# Force branch name to be lowercase (convert / to -) and only allow numbers, characters and "-". Everything else is stripped.
REMOTE_BRANCH=`git branch --remote --verbose --no-abbrev --contains | grep $(git rev-parse --verify HEAD) | sed -rne 's/^[^\/]*\/([^\ ]+).*$/\1/p' | tail -1`
LOCAL_BRANCH=`git rev-parse --abbrev-ref HEAD`
BRANCH=$(echo "${REMOTE_BRANCH:-$LOCAL_BRANCH}" | tr '[:upper:]' '[:lower:]' | tr \/ - | sed "s/[^0-9a-z\-]//g")

VERSION=`git describe --tags --abbrev=0 2> /dev/null | sed -e 's/-[0-9]*//g' | sed 's/[^0-9.]*//g'`
VERSION=${VERSION:-$BRANCH}

if [[ "$AHEAD" != "0" ]]; then
  export VERSION="$BRANCH"
fi

LATEST_TAG="$BRANCH-latest"
LATEST_TAG=$(echo "$LATEST_TAG" | tr '[:upper:]' '[:lower:]' | tr \/ -)
LATEST_TAG=${LATEST_TAG//[!a-z0-9\-\.]}


# Compute Docker image tag from version or branch name
# Only upload final tagged image for retention when tagged with a version - all other docker images only get the "*-latest" tag
TAG=$VERSION
if [[ ( "$AHEAD" != "0" ) || ( "$VERSION" == "$BRANCH" ) ]]; then
  TAG=
  VERSION="$VERSION-$SHORT"
fi
export TAG=$TAG

# Help
usage () {
    echo "usage: source ./generate-version.sh [-h] [-i] [-j] [-s] <FILENAME>" >&2
    echo >&2
    echo "Generate version.* file as JSON or INI or SH. When using -s the resulting shell file can be sourced to expose \$VERSION, \$AHEAD, \$COMMIT, \$BRANCH and \$DOCKER_TAG." >&2
    echo "" >&2
    echo "Options:" >&2
    echo "-h    Show this help" >&2
    echo "-i    Write as .ini file" >&2
    echo "-j    Write as .json file" >&2
    echo "-s    Write as .sh file" >&2
}

while getopts "hijs" flag; do
    case "${flag}" in
        h) usage; exit 0;;
        i) OUTPUT_INI=yes;;
        j) OUTPUT_JSON=yes;;
        s) OUTPUT_SH=yes;;
        *) usage; exit 1;;
    esac
done

main () {
  # Checks
  if [ "$#" -lt 1 ]; then
    usage
    exit 0
  fi

  echo "🚧  Generating build information"
  echo ""
  echo -e "Current version:                  $HL$VERSION$NC"
  echo -e "Commit is ahead of version tag:   $HL$AHEAD$NC"
  echo -e "Hash of commit:                   $HL$COMMIT$NC"
  echo -e "Short hash of commit:             $HL$SHORT$NC"
  echo -e "Build originates from branch:     $HL$BRANCH$NC"
  echo -e "Docker image version tag:         $HL$TAG$NC"
  echo -e "Latest tag:                       $HL$LATEST_TAG$NC"
  echo -e "Build timestamp:                  $HL$TIMESTAMP$NC"
  echo ""

  if [ "$OUTPUT_INI" ]; then
    FILENAME="${@: -1}.ini"
    echo "📝  Writing <$FILENAME> as INI"
    echo "[version]" > $FILENAME
    echo "VERSION = $VERSION" >> $FILENAME
    echo "AHEAD = $AHEAD" >> $FILENAME
    echo "COMMIT = $COMMIT" >> $FILENAME
    echo "SHORT = $SHORT" >> $FILENAME
    echo "BRANCH = $BRANCH" >> $FILENAME
    echo "DOCKER_TAG = $TAG" >> $FILENAME
    echo "LATEST_TAG = $LATEST_TAG" >> $FILENAME
    echo "TIMESTAMP = $TIMESTAMP" >> $FILENAME
  fi

  if [ "$OUTPUT_JSON" ]; then
    FILENAME="${@: -1}.json"
    echo "🐟  Writing <$FILENAME> as JSON"
    echo "{\"version\":\"$VERSION\",\"ahead\":\"$AHEAD\",\"commit\":\"$COMMIT\",\"short\":\"$SHORT\",\"branch\":\"$BRANCH\",\"docker_tag\":\"$TAG\",\"latest_tag\":\"$LATEST_TAG\",\"timestamp\":\"$TIMESTAMP\"}" > $FILENAME
  fi

  if [ "$OUTPUT_SH" ]; then
    FILENAME="${@: -1}.sh"
    echo "💲  Writing <$FILENAME> as Shell"
    echo "#!/bin/sh" > $FILENAME
    echo "export VERSION=\"$VERSION\"" >> $FILENAME
    echo "export AHEAD=\"$AHEAD\"" >> $FILENAME
    echo "export COMMIT=\"$COMMIT\"" >> $FILENAME
    echo "export SHORT=\"$SHORT\"" >> $FILENAME
    echo "export BRANCH=\"$BRANCH\"" >> $FILENAME
    echo "export DOCKER_TAG=\"$TAG\"" >> $FILENAME
    echo "export LATEST_TAG=\"$LATEST_TAG\"" >> $FILENAME
    echo "export TIMESTAMP=\"$TIMESTAMP\"" >> $FILENAME
    chmod ugo+x $FILENAME
  fi
}

( cd . && main "$@" )
