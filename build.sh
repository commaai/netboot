#!/usr/bin/env bash
set -ex

cd "$(dirname "$0")"
DIR=$(pwd)

# build ipxe
cd third_party/ipxe/
docker build -t ipxe-build .
docker build -t ipxe-build .
docker run --rm -i -v $(pwd)/src:/src -v ${DIR}:/netboot ipxe-build <<EOF
make -j $(nproc) \
  EMBED=/netboot/pixiecore/boot.ipxe \
  bin/ipxe.pxe \
  bin/undionly.kpxe \
  bin-x86_64-efi/ipxe.efi \
  bin-i386-efi/ipxe.efi
EOF
cd -

# build pixiecore
docker run --rm -i -v $(pwd):/go/src/go.universe.tf/netboot golang:1.20 <<EOF
bash -ex -c ' \
git config --global --add safe.directory /go/src/go.universe.tf/netboot && \
cd /go/src/go.universe.tf/netboot && \
make build && \
go install github.com/go-bindata/go-bindata/go-bindata@latest && \
go-bindata -o out/ipxe/bindata.go -pkg ipxe -nometadata -nomemcopy \
  third_party/ipxe/src/bin/ipxe.pxe \
  third_party/ipxe/src/bin/undionly.kpxe \
  third_party/ipxe/src/bin-x86_64-efi/ipxe.efi \
  third_party/ipxe/src/bin-i386-efi/ipxe.efi && \
gofmt -s -w out/ipxe/bindata.go \
'
EOF

# build docker container
docker run --rm -i -v /var/run/docker.sock:/var/run/docker.sock -v $(pwd):/go/src/go.universe.tf/netboot golang:1.20 <<EOF
bash -ex -c ' \
git config --global --add safe.directory /go/src/go.universe.tf/netboot && \
cd /go/src/go.universe.tf/netboot && \
apt-get update && apt-get install -y apt-transport-https lsb-release ca-certificates curl gnupg && \
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
echo "deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \$(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list && \
apt-get update && apt-get install -y docker-ce-cli && \
make -f Makefile.inc image GOARCH=amd64 TAG=latest BINARY=pixiecore REGISTRY=local \
'
EOF
