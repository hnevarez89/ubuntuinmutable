#!/bin/bash

# =================================================================
# Script de configuración para Veeam Hardened Repository
# Ubuntu 25.10 | LVM 4 Discos | XFS Reflink | Sudo Temporal
# =================================================================

# 1. VARIABLES
DISCOS=("/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde")
VG_NAME="vg_veeam"
LV_NAME="lv_repository"
MOUNT_POINT="/mnt/veeam_repository"
VEEAM_USER="veeamuser"

echo "--- Iniciando configuración de almacenamiento ---"

# 2. INSTALACIÓN DE DEPENDENCIAS
sudo apt update && sudo apt install -y lvm2 xfsprogs

# 3. CREACIÓN DE LVM
echo "Configurando LVM..."
sudo pvcreate "${DISCOS[@]}"
sudo vgcreate $VG_NAME "${DISCOS[@]}"
sudo lvcreate -l 100%FREE -n $LV_NAME $VG_NAME

# 4. FORMATEO XFS CON REFLINK (Requerido para Fast Clone)
echo "Formateando XFS con reflink..."
sudo mkfs.xfs -b size=4096 -m reflink=1,crc=1 /dev/$VG_NAME/$LV_NAME

# 5. MONTAJE PERSISTENTE
echo "Configurando montaje en $MOUNT_POINT..."
sudo mkdir -p $MOUNT_POINT
UUID=$(sudo blkid -s UUID -o value /dev/$VG_NAME/$LV_NAME)
echo "UUID=$UUID $MOUNT_POINT xfs defaults,nodev,nosuid 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# 6. USUARIO VEEAM Y PERMISOS DE DIRECTORIO
if ! id "$VEEAM_USER" &>/dev/null; then
    sudo useradd -m -s /bin/bash $VEEAM_USER
    echo "Establece la contraseña para $VEEAM_USER:"
    sudo passwd $VEEAM_USER
fi

sudo chown -R $VEEAM_USER:$VEEAM_USER $MOUNT_POINT
sudo chmod 700 $MOUNT_POINT

# 7. CONFIGURACIÓN DE SUDO TEMPORAL (Para evitar el error de elevación)
echo "Habilitando sudo temporal para el despliegue de Veeam..."
echo "$VEEAM_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/veeamuser

echo ""
echo "============================================================"
echo "¡LISTO PARA AGREGAR EN VEEAM!"
echo "1. En Veeam, usa el usuario: $VEEAM_USER"
echo "2. En 'Advanced SSH', activa 'Elevate to root' y 'Use sudo'."
echo "3. IMPORTANTE: Una vez que el repo esté listo en Veeam, ejecuta:"
echo "   sudo rm /etc/sudoers.d/veeamuser"
echo "============================================================"
