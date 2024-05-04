#!/usr/bin/env sh

GITHUB_SSH_AUTHORIZED_KEYS_USERNAME=andyattebery
GITHUB_SSH_AUTHORIZED_KEYS_PATH=/tmp/authorized_keys

PROXMOX_STORAGE=local-zfs_pve-nvme-01
PROXMOX_NETWORK_BRIDGE=vmbr0

VM_ID=1000
VM_CPU_CORES=2
VM_RAM=8192
VM_DISK_SIZE="64G"

VM_CLOUDINIT_USERNAME=services

ubuntu_version="2404"
ubuntu_code_name=noble
ubuntu_image="$ubuntu_code_name-server-cloudimg-amd64.img"
ubuntu_image_path="/tmp/$ubuntu_image"

set -e

if [ -e $ubuntu_image_path ]; then
    rm $ubuntu_image_path
fi

echo "Downloading $ubuntu_image"
wget https://cloud-images.ubuntu.com/$ubuntu_code_name/current/$ubuntu_image --output-document=$ubuntu_image_path

echo "Resizing disk image"
qemu-img resize $ubuntu_image_path $VM_DISK_SIZE

echo "Installing packages into $ubuntu_image_path"
sudo virt-customize -a $ubuntu_image_path --install qemu-guest-agent

echo "Creating VM"
sudo qm create $VM_ID \
    --name "ubuntu-$ubuntu_version-cloudinit-template" \
    --ostype l26 \
    --cpu host \
    --cores $VM_CPU_CORES \
    --memory $VM_RAM \
    --net0 virtio,bridge=$PROXMOX_NETWORK_BRIDGE \
    --serial0 socket \
    --vga std \
    --agent enabled=1

echo "Importing disk image"
sudo qm importdisk $VM_ID $ubuntu_image_path $PROXMOX_STORAGE
sudo qm set $VM_ID --scsihw virtio-scsi-pci --scsi0 $PROXMOX_STORAGE:vm-$VM_ID-disk-0,discard=on
sudo qm set $VM_ID --boot order=scsi0

echo "Downloading GitHub SSH authorized keys"
if [ -e $GITHUB_SSH_AUTHORIZED_KEYS_PATH ]; then
    rm $GITHUB_SSH_AUTHORIZED_KEYS_PATH
fi
wget https://github.com/$GITHUB_SSH_AUTHORIZED_KEYS_USERNAME.keys --output-document=$GITHUB_SSH_AUTHORIZED_KEYS_PATH

echo "Configuring cloudinit"
sudo qm set $VM_ID --ide2 $PROXMOX_STORAGE:cloudinit
sudo qm set $VM_ID --ciuser $VM_CLOUDINIT_USERNAME
sudo qm set $VM_ID --sshkeys $GITHUB_SSH_AUTHORIZED_KEYS_PATH
sudo qm set $VM_ID --ipconfig0 ip=dhcp

echo "Convert to template"
sudo qm template $VM_ID

echo "Cleaning up"
rm $GITHUB_SSH_AUTHORIZED_KEYS_PATH
rm $ubuntu_image_path