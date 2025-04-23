# Set the running host architecture (not applied for different host architectures)
ARCH=$(uname -m)

if [ "$ARCH" == "x86_64" ]; then
  POST_ARCH="amd64"
elif [ "$ARCH" == "aarch64" ]; then
  POST_ARCH="arm64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

CHANNEL="stable"
OKD_VERSION=$(curl -s https://mirror.openshift.com/pub/openshift-v4/aarch64/clients/ocp/$CHANNEL/release.txt | sed -nE 's/^Name:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+)/\1/p')

OC_TAR_NAME="oc.tar.gz"
INSTALLER_TAR_NAME="openshift-install-linux.tar.gz"

curl -L https://mirror.openshift.com/pub/openshift-v4/$ARCH/clients/ocp/$CHANNEL/openshift-client-linux-$POST_ARCH-rhel9-$OKD_VERSION.tar.gz -o $OC_TAR_NAME
tar zxvf $OC_TAR_NAME
chmod +x oc

curl -L https://mirror.openshift.com/pub/openshift-v4/$ARCH/clients/ocp/$CHANNEL/openshift-install-rhel9-$POST_ARCH.tar.gz -o $INSTALLER_TAR_NAME
tar zxvf $INSTALLER_TAR_NAME
chmod +x openshift-install-fips

if ! ./openshift-install-fips version; then
  echo "Error: openshift-install-fips failed to execute. Cleaning up..."
  exit 1
fi

rm -f $OC_TAR_NAME $INSTALLER_TAR_NAME

# Retrieve the FCOS ISO
ISO_URL=$(./openshift-install-fips coreos print-stream-json | jq -r ".architectures.$ARCH.artifacts.metal.formats.iso.disk.location" )
curl -L $ISO_URL -o rhcos.iso

cp ./install-config.yaml ./sno/install-config.yaml

# Generate OKD assets
./openshift-install-fips --dir=sno create single-node-ignition-config

# Embed the ignition data into the FCOS ISO
podman run --privileged --pull always --rm \
  -v /dev:/dev -v /run/udev:/run/udev -v $PWD:/data -w /data \
  quay.io/coreos/coreos-installer:release \
  iso ignition embed -fi sno/bootstrap-in-place-for-live-iso.ign rhcos.iso
