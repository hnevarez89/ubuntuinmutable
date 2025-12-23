#!/bin/bash

# =================================================================
# Script de configuración para Veeam Hardened Repository
# Sistema: Ubuntu 25.10 | FS: XFS con Reflink | LVM: 4 Discos
# =================================================================

# 1. DEFINICIÓN DE VARIABLES (Ajusta los discos según tu 'lsblk')
DISCOS=("/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd")
VG_NAME="vg_veeam"
LV_NAME="lv_repository"
MOUNT_POINT="/mnt/veeam_repository"
VEEAM_USER="veeamuser"

echo "Iniciando configuración de almacenamiento..."

# 2. INSTALACIÓN DE DEPENDENCIAS
sudo apt update && sudo apt install -o Dpkg::Options::="--force-confold" -y lvm2 xfsprogs

# 3. CREACIÓN DE LVM
echo "Creando Physical Volumes..."
sudo pvcreate "${DISCOS[@]}"

echo "Creando Volume Group $VG_NAME..."
sudo vgcreate $VG_NAME "${DISCOS[@]}"

echo "Creando Logical Volume $LV_NAME (100% de espacio)..."
sudo lvcreate -l 100%FREE -n $LV_NAME $VG_NAME

# 4. FORMATEO XFS (Optimizado para Fast Clone)
echo "Formateando con XFS (reflink=1)..."
sudo mkfs.xfs -b size=4096 -m reflink=1,crc=1 /dev/$VG_NAME/$LV_NAME

# 5. CONFIGURACIÓN DE MONTAJE PERSISTENTE
echo "Configurando montaje en $MOUNT_POINT..."
sudo mkdir -p $MOUNT_POINT
UUID=$(sudo blkid -s UUID -o value /dev/$VG_NAME/$LV_NAME)
echo "UUID=$UUID $MOUNT_POINT xfs defaults,nodev,nosuid 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# 6. CREACIÓN DE USUARIO Y PERMISOS
echo "Configurando usuario para Veeam..."
if ! id "$VEEAM_USER" &>/dev/null; then
    sudo useradd -m -s /bin/bash $VEEAM_USER
    echo "Por favor, establece una contraseña para el usuario $VEEAM_USER:"
    sudo passwd $VEEAM_USER
fi

# Permisos críticos para el repositorio
sudo chown -R $VEEAM_USER:$VEEAM_USER $MOUNT_POINT
sudo chmod 700 $MOUNT_POINT

echo "========================================================"
echo "¡PROCESO COMPLETADO!"
echo "Punto de montaje: $MOUNT_POINT"
echo "Usuario creado: $VEEAM_USER"
echo "Recuerda usar este usuario al añadir el repo en Veeam."
echo "========================================================"