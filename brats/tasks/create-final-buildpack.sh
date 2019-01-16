#!/bin/bash

set -xe

unzip s3.suse-buildpacks-staging/*.zip  manifest.yml

# Copy artifacts
staging_urls=`ruby -ryaml -ruri <<EOF
manifest = YAML.load_file("manifest.yml")
dependencies = manifest["dependencies"].select do |d|
  d["uri"].include?("${STAGING_BUCKET_NAME}")
end.each do |d|
  url = URI.parse(d["uri"])
  puts "s3:/" + url.path
end
EOF
`

for url in ${staging_urls}; do
  aws s3 cp ${url} ${url/${STAGING_BUCKET_NAME}/${PRODUCTION_BUCKET_NAME}}
done


# Rewrite manifest
sed -i "s|https://s3.amazonaws.com/${STAGING_BUCKET_NAME}|${PRODUCTION_BUCKET_URL}|" manifest.yml


# Validate manifest
pushd git.cf-buildpack
source .envrc
cp ../manifest.yml manifest.yml
wget https://download.opensuse.org/repositories/Cloud:/Platform:/buildpacks:/build-requires/openSUSE_Leap_15.0/x86_64/go-buildpack-packager-0.1+git-lp150.2.1.x86_64.rpm
rpm -i go-buildpack-packager-*.rpm

if ! buildpack-packager build -cached=true -any-stack; then
  echo "buildpack-packager validation failed"
  exit 1
fi
popd


# Generate new buildpack
original_filename=$(basename $(ls s3.suse-buildpacks-staging/*.zip))
cp s3.suse-buildpacks-staging/${original_filename} production-buildpack.zip
zip -r production-buildpack.zip manifest.yml

new_checksum=$(sha1sum production-buildpack.zip | cut -d' ' -f1)
new_filename=$(echo ${original_filename/-pre-/-} | sed -e "s/[0-9a-f]\{8\}.zip/${new_checksum:0:8}.zip/")

mv production-buildpack.zip s3-out/${new_filename}
