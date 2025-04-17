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

# Get OKD latest version
OKD_VERSION=$(curl -s https://api.github.com/repos/okd-project/okd-scos/releases/latest | jq -r '.tag_name')

OC_TAR_NAME="oc.tar.gz"
INSTALLER_TAR_NAME="openshift-install-linux.tar.gz"

# Download the OKD client (oc) and make it available for use by entering the following commands
curl -L https://github.com/okd-project/okd-scos/releases/download/$OKD_VERSION/openshift-client-linux-$POST_ARCH-$OKD_VERSION.tar.gz -o $OC_TAR_NAME
tar zxvf $OC_TAR_NAME
chmod +x oc

# Download the OKD installer and make it available for use by entering the following commands
curl -L https://github.com/okd-project/okd-scos/releases/download/$OKD_VERSION/openshift-install-linux-$POST_ARCH-$OKD_VERSION.tar.gz -o $INSTALLER_TAR_NAME
tar zxvf $INSTALLER_TAR_NAME
chmod +x openshift-install

if ! ./openshift-install version; then
  echo "Error: openshift-install failed to execute. Cleaning up..."
  exit 1
fi

rm -f $OC_TAR_NAME $INSTALLER_TAR_NAME

# Retrieve the FCOS ISO
ISO_URL=$(./openshift-install coreos print-stream-json | jq -r ".architectures.$ARCH.artifacts.metal.formats.iso.disk.location" )
curl -L $ISO_URL -o fcos-live.iso

cp ./install-config.yaml ./sno/install-config.yaml

# Generate OKD assets
./openshift-install --dir=sno create single-node-ignition-config

# Embed the ignition data into the FCOS ISO
podman run --privileged --pull always --rm \
  -v /dev:/dev -v /run/udev:/run/udev -v $PWD:/data -w /data \
  quay.io/coreos/coreos-installer:release \
  iso ignition embed -fi sno/bootstrap-in-place-for-live-iso.ign fcos-live.iso
