#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
ROOTDIR=$DIR/../../../

release_tag=$(cat $ROOTDIR/buildpack-gh-release/tag)
release_tag=${release_tag:1} # Strip the "v" from e.g. v1.7.22

# Revision is 1 because this task is triggered by new releases only.
# If a manually change something, we would be calling the tool manually with
# a different revision number.

# Make sure that the SUSE revision does not conflict with irregular patch
# level java releases by enforcing versions with four parts
if [ ${release_tag//[^.]} == "." ]; then
  revision=0.1
else
  revision=1
fi

version="${release_tag}.${revision}"

pushd git.cf-buildpack
git checkout
echo "---" > config/version.yml
echo "version: v${version}" >> config/version.yml
# It needs at least bundler 2.0.1
gem install bundler
bundler.ruby2.5 install
bundler.ruby2.5 exec rake clobber package
CHECKSUM=$(sha1sum build/java-buildpack-v${version}.zip | cut -d' ' -f1)
mv build/java-buildpack-v${version}.zip ../out/java-buildpack-v${version}-${CHECKSUM:0:8}.zip
popd
