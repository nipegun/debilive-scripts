#!/bin/bash

# Pongo a disposición pública este script bajo el término de "software de dominio público".
# Puedes hacer lo que quieras con él porque es libre de verdad; no libre con condiciones como las licencias GNU y otras patrañas similares.
# Si se te llena la boca hablando de libertad entonces hazlo realmente libre.
# No tienes que aceptar ningún tipo de términos de uso o licencia para utilizarlo o modificarlo porque va sin CopyLeft.

# ----------
#  Script de NiPeGun para instalar OpenWrt en una máquina virtual de ProxmoxVE inciando desde Debian Live 
#
# Ejecución remota:
#   curl -sL https://raw.githubusercontent.com/nipegun/debilive-scripts/main/InstSO/OpenWrtX86-Instalar.sh | bash
#   curl -sL https://raw.githubusercontent.com/nipegun/debilive-scripts/main/InstSO/OpenWrtX86-Instalar.sh | sed 's-/dev/sda-/dev/vda-g' | bash
# ----------

vNumUltVer=$(curl -sL openwrt.org | grep urrent | grep "stable" | grep ":" | cut -d":" -f2 | cut -d"." -f1 | sed 's- --g' | cut -d"t" -f2)
#vNumUltVer="22"

vFechaDeEjec=$(date +A%Y-M%m-D%d@%T)
vPrimerDisco="/dev/sda"

# Declaración de las variables de color
  vColorAzul="\033[0;34m"
  vColorAzulClaro="\033[1;34m"
  vColorVerde='\033[1;32m'
  vColorRojo='\033[1;31m'
  vFinColor='\033[0m'

echo ""
echo -e "${vColorAzulClaro}  Iniciando el script de instalación de OpenWrt X86 para máquinas virtuales de Proxmox...${vFinColor}"
echo ""

# Comprobar si el paquete dialog está instalado. Si no lo está, instalarlo.
  if [[ $(dpkg-query -s dialog 2>/dev/null | grep installed) == "" ]]; then
    echo ""
    echo -e "${vColorRojo}    El paquete dialog no está instalado. Iniciando su instalación...${vFinColor}"
    echo ""
    sudo sed -i -e 's|main restricted|main universe restricted|g' /etc/apt/sources.list
    sudo apt-get -y update && sudo apt-get -y install dialog
    echo ""
  fi

  # Cambiar resolución de la pantalla
    vNombreDisplay=$(xrandr | grep " connected" | cut -d" " -f1)
    xrandr --output $vNombreDisplay --mode 1024x768

menu=(dialog --checklist "Instalación de OpenWrt X86:" 30 100 20)
  opciones=(
     1 "Hacer copia de seguridad de la instalación anterior" on
     2 "Crear las particiones" on
     3 "Formatear las particiones" on
     4 "Marcar la partición EFI como esp" on
     5 "Determinar la última versión de OpenWrt" on
     6 "Montar las particiones" on
     7 "Descargar Grub para EFI" on
     8 "Crear el archivo de configuración para Grub" on
     9 "Crear la estructura de carpetas y archivos en ext4" on
    10 "Configurar la MV para que pille IP por DHCP" on
    11 "Copiar el script de instalación de paquetes" on
    12 "Copiar el script de instalación de los o-scripts" on
    13 "Copiar el script de preparación de OpenWrt para funcionar como una MV de Proxmox" on
    14 "Copiar el script de preparación de OpenWrt para funcionar como un laboratorio de ciberseguridad" on
    15 "Mover copia de seguridad de la instalación anterior a la nueva instalación" on
    16 "Instalar GPartEd y Midnight Commander para poder visualizar los cambios realizados" on
    17 "Apagar la máquina virtual" off
  )
  choices=$("${menu[@]}" "${opciones[@]}" 2>&1 >/dev/tty)

  for choice in $choices
    do
      case $choice in

        1)

          echo ""
          echo "  Haciendo copia de seguridad de la instalación anterior..."
          echo ""
          # Desmontar discos, si es que están montados
            sudo umount $vPrimerDisco"1" 2> /dev/null
            sudo umount $vPrimerDisco"2" 2> /dev/null
            sudo umount $vPrimerDisco"3" 2> /dev/null
          # Crear particiones para montar
            sudo mkdir -p /OpenWrt/PartEFI/
            sudo mount -t auto $vPrimerDisco"1" /OpenWrt/PartEFI/
            sudo mkdir -p /OpenWrt/PartExt4/
            sudo mount -t auto $vPrimerDisco"2" /OpenWrt/PartExt4/
          # Crear carpeta donde guardar los archivos
            sudo mkdir -p /CopSegOpenWrt/$vFechaDeEjec/PartEFI/
            sudo mkdir -p /CopSegOpenWrt/$vFechaDeEjec/PartExt4/
          # Copiar archivos
            sudo cp -r /OpenWrt/PartEFI/*  /CopSegOpenWrt/$vFechaDeEjec/PartEFI/
            sudo cp -r /OpenWrt/PartExt4/* /CopSegOpenWrt/$vFechaDeEjec/PartExt4/
          # Desmontar partición 
            sudo umount /OpenWrt/PartEFI/
            sudo rm -rf  /OpenWrt/PartEFI/
            sudo umount /OpenWrt/PartExt4/
            sudo rm -rf  /OpenWrt/PartExt4/

        ;;

        2)

          echo ""
          echo "  Creando las particiones..."
          echo ""
          sudo rm -rf /OpenWrt/PartEFI/*
          sudo rm -rf /OpenWrt/PartExt4/*
          sudo umount $vPrimerDisco"1" 2> /dev/null
          sudo umount $vPrimerDisco"2" 2> /dev/null
          sudo umount $vPrimerDisco"3" 2> /dev/null
          sudo swapoff -a
          # Crear tabla de particiones GPT
            sudo parted -s $vPrimerDisco mklabel gpt
          # Crear la partición EFI
            sudo parted -s $vPrimerDisco mkpart PartEFI ext4 1MiB 1025MiB
          # Crear la partición ext4
            sudo parted -s "$vPrimerDisco" mkpart PartOpenWrt ext4 1025MiB 3073MiB
          # Crear la partición de intercambio
            #sudo parted -s $vPrimerDisco mkpart Intercambio ext4 3072MiB 100%
            sudo parted -s $vPrimerDisco mkpart PartIntercambio ext4 3073MiB 4097MiB

        ;;

        3)

          echo ""
          echo "  Formateando las particiones..."
          echo ""
          # Formatear la partición para EFI como fat32
            sudo mkfs -t vfat -F 32 -n EFI $vPrimerDisco"1"
          # Formatear la partición para OpenWrt como ext4
            sudo mkfs -t ext4 -L OpenWrt $vPrimerDisco"2"
          # Formatear la partición para Intercambio como swap
            sudo mkswap -L Intercambio $vPrimerDisco"3"

        ;;

        4)

          echo ""
          echo "  Marcando la partición EFI como esp..."
          echo ""
          sudo parted -s $vPrimerDisco set 1 esp on

        ;;

        5)

          echo ""
          echo "  Determinando la última versión de OpenWrt..."
          echo ""

          # Comprobar si el paquete curl está instalado. Si no lo está, instalarlo.
            if [[ $(dpkg-query -s curl 2>/dev/null | grep installed) == "" ]]; then
              echo ""
              echo "    El paquete curl no está instalado. Iniciando su instalación..."
              echo ""
              sudo apt-get -y update && sudo apt-get -y install curl
              echo ""
            fi
  
          VersOpenWrt=$(curl --silent https://downloads.openwrt.org | grep rchive | grep eleases | grep OpenWrt | grep $vNumUltVer | head -n 1 | cut -d'/' -f 5)

          echo ""
          echo "    La última versión estable de OpenWrt es la $VersOpenWrt."
          echo ""

        ;;

        6)

          echo ""
          echo "  Montando las particiones..."
          echo ""
          sudo mkdir -p /OpenWrt/PartEFI/ 2> /dev/null
          sudo mount -t auto /dev/sda1 /OpenWrt/PartEFI/
          sudo mkdir -p /OpenWrt/PartExt4/ 2> /dev/null
          sudo mount -t auto /dev/sda2 /OpenWrt/PartExt4/

        ;;

        7)

          echo ""
          echo "  Descargando grub para efi..."
          echo ""
          sudo mkdir -p /OpenWrt/PartEFI/EFI/Boot/ 2> /dev/null
          rm -rf /OpenWrt/PartEFI/EFI/Boot/*
          # Comprobar si el paquete wget está instalado. Si no lo está, instalarlo.
            if [[ $(dpkg-query -s wget 2>/dev/null | grep installed) == "" ]]; then
              echo ""
              echo "    El paquete wget no está instalado. Iniciando su instalación..."
              echo ""
              sudo apt-get -y update && sudo apt-get -y install wget
              echo ""
            fi
          # sudo wget http://hacks4geeks.com/_/premium/descargas/OpenWrtX86/PartEFI/EFI/Boot/bootx64.efi -O /OpenWrt/PartEFI/EFI/Boot/bootx64.efi
          sudo wget https://raw.githubusercontent.com/nipegun/debilive-scripts/main/InstSO/Recursos/bootx64openwrt.efi -O /OpenWrt/PartEFI/EFI/Boot/bootx64.efi

        ;;

        8)

          echo ""
          echo "  Creando el archivo de configuración para Grub (grub.cfg)..."
          echo ""
          # Determinar el PartUUID de la partición ext4
            vPartUUID=$(blkid -s PARTUUID -o value "$vPrimerDisco"2)
          sudo mkdir -p /OpenWrt/PartEFI/EFI/OpenWrt/ 2> /dev/null
          sudo su -c "echo 'serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1 --rtscts=off'                                                       > /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo 'terminal_input console serial; terminal_output console serial'                                                                  >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo ''                                                                                                                               >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo 'set default="'"0"'"'                                                                                                            >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo 'set timeout="'"1"'"'                                                                                                            >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c 'echo "set root='"'(hd0,2)'"'"                                                                                                         >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg'
          sudo su -c "echo ''                                                                                                                               >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo 'menuentry "'"OpenWrt desde PARTUUID"'" {'                                                                                       >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo '  linux /generic-kernel.bin root=PARTUUID=$vPartUUID rootfstype=ext4 rootwait console=tty0 console=ttyS0,115200n8 noinitrd'     >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo '}'                                                                                                                              >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo ''                                                                                                                               >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo 'menuentry "'"OpenWrt desde /dev/sda2"'" {'                                                                                      >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo '  #linux /generic-kernel.bin root=/dev/sda2 rootfstype=ext4 rootwait console=tty0 console=ttyS0,115200n8 noinitrd'              >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo '}'                                                                                                                              >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo ''                                                                                                                               >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo 'menuentry "'"OpenWrt desde /dev/vda2"'" {'                                                                                      >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo '  #linux /generic-kernel.bin root=/dev/vda2 rootfstype=ext4 rootwait console=tty0 console=ttyS0,115200n8 noinitrd'              >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo '}'                                                                                                                              >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo ''                                                                                                                               >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo 'menuentry "'"OpenWrt (failsafe)"'" {'                                                                                           >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo '  linux /generic-kernel.bin failsafe=true root=/dev/sda2 rootfstype=ext4 rootwait console=tty0 console=ttyS0,115200n8 noinitrd' >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo '}'                                                                                                                              >> /OpenWrt/PartEFI/EFI/OpenWrt/grub.cfg"

        ;;

        9)

          echo ""
          echo "  Creando la estructura de carpetas y archivos en la partición ext4 con OpenWrt $VersOpenWrt..."
          echo ""
          echo ""
          echo "    Borrando el contenido de la partición ext4..."
          echo ""
          sudo rm -rf /OpenWrt/PartExt4/*

          echo ""
          echo "    Bajando y posicionando el Kernel..."
          echo ""
          sudo mkdir -p /OpenWrt/PartExt4/boot 2> /dev/null
          # Comprobar si el paquete wget está instalado. Si no lo está, instalarlo.
            if [[ $(dpkg-query -s wget 2>/dev/null | grep installed) == "" ]]; then
              echo ""
              echo "      El paquete wget no está instalado. Iniciando su instalación..."
              echo ""
              sudo apt-get -y update && sudo apt-get -y install wget
              echo ""
            fi
          sudo wget --no-check-certificate https://downloads.openwrt.org/releases/$VersOpenWrt/targets/x86/64/openwrt-$VersOpenWrt-x86-64-generic-kernel.bin -O /OpenWrt/PartExt4/generic-kernel.bin

          echo ""
          echo "    Bajando el archivo con el sistema root..."
          echo ""
          sudo rm -rf /OpenWrt/PartEFI/rootfs.tar.gz
          sudo wget --no-check-certificate https://downloads.openwrt.org/releases/$VersOpenWrt/targets/x86/64/openwrt-$VersOpenWrt-x86-64-rootfs.tar.gz -O /OpenWrt/PartEFI/rootfs.tar.gz

          echo ""
          echo "    Descomprimiendo el sistema de archivos root en la partición ext4..."
          echo ""

          # Comprobar si el paquete tar está instalado. Si no lo está, instalarlo.
            if [[ $(dpkg-query -s tar 2>/dev/null | grep installed) == "" ]]; then
              echo ""
              echo "      El paquete tar no está instalado. Iniciando su instalación..."
              echo ""
              sudo apt-get -y update && sudo apt-get -y install tar
              echo ""
            fi
          sudo tar -xf /OpenWrt/PartEFI/rootfs.tar.gz -C /OpenWrt/PartExt4/
          #sudo mkdir /OpenWrt/PartExt4/boot/efi/

          #echo "config global"                 > /OpenWrt/PartExt4/etc/config/fstab
          #echo "  option anon_swap '0'"       >> /OpenWrt/PartExt4/etc/config/fstab
          #echo "  option anon_mount '0'"      >> /OpenWrt/PartExt4/etc/config/fstab
          #echo "  option auto_swap '1'"       >> /OpenWrt/PartExt4/etc/config/fstab
          #echo "  option auto_mount '1'"      >> /OpenWrt/PartExt4/etc/config/fstab
          #echo "  option delay_root '5'"      >> /OpenWrt/PartExt4/etc/config/fstab
          #echo "  option check_fs '0'"        >> /OpenWrt/PartExt4/etc/config/fstab
          #echo ""                             >> /OpenWrt/PartExt4/etc/config/fstab
          #echo "config mount"                 >> /OpenWrt/PartExt4/etc/config/fstab
          #echo "  option target '/boot/efi'"  >> /OpenWrt/PartExt4/etc/config/fstab
          #echo "  option device 'UUIDEFI=x'"  >> /OpenWrt/PartExt4/etc/config/fstab
          #echo "  option fstype 'vfat'"       >> /OpenWrt/PartExt4/etc/config/fstab
          #echo "  option enabled '1'"         >> /OpenWrt/PartExt4/etc/config/fstab
          #echo ""                             >> /OpenWrt/PartExt4/etc/config/fstab
          #echo "config swap"                  >> /OpenWrt/PartExt4/etc/config/fstab
          #echo "  option device 'UUIDSWAP=x'" >> /OpenWrt/PartExt4/etc/config/fstab
          #echo "  option enabled '1'"         >> /OpenWrt/PartExt4/etc/config/fstab
          #echo ""                             >> /OpenWrt/PartExt4/etc/config/fstab
          # Determinar el PARTUUID de la partición EFI
            #vPartUUIDefi=$(blkid -s PARTUUID -o value "$vPrimerDisco"1)
          #sed -i -e "s|UUIDEFI=x|PARTUUID=$vPartUUIDefi|g"  /OpenWrt/PartExt4/etc/config/fstab
          # Determinar el PARTUUID de la partición swap
            #vPartUUIDswap=$(blkid -s PARTUUID -o value "$vPrimerDisco"3)
          #sed -i -e "s|UUIDSWAP=x|PARTUUID=$vPartUUIDswap|g" /OpenWrt/PartExt4/etc/config/fstab

        ;;

        10)

          echo ""
          echo "  Configurando la MV de OpenWrt para que pille IP por DHCP..."
          echo ""
          sudo mkdir /OpenWrt/PartEFI/scripts/ 2> /dev/null
          sudo su -c 'echo "config interface loopback"         > /OpenWrt/PartEFI/scripts/network'
          sudo su -c 'echo "  option ifname '"'lo'"'"         >> /OpenWrt/PartEFI/scripts/network'
          sudo su -c 'echo "  option proto '"'static'"'"      >> /OpenWrt/PartEFI/scripts/network'
          sudo su -c 'echo "  option ipaddr '"'127.0.0.1'"'"  >> /OpenWrt/PartEFI/scripts/network'
          sudo su -c 'echo "  option netmask '"'255.0.0.0'"'" >> /OpenWrt/PartEFI/scripts/network'
          sudo su -c 'echo ""                                 >> /OpenWrt/PartEFI/scripts/network'
          sudo su -c 'echo "config interface '"'wan'"'"       >> /OpenWrt/PartEFI/scripts/network'
          sudo su -c 'echo "  option ifname '"'eth0'"'"       >> /OpenWrt/PartEFI/scripts/network'
          sudo su -c 'echo "  option proto '"'dhcp'"'"        >> /OpenWrt/PartEFI/scripts/network'
          sudo rm -f                               /OpenWrt/PartExt4/etc/config/network
          sudo mv /OpenWrt/PartEFI/scripts/network /OpenWrt/PartExt4/etc/config/
          sudo rm -rf /OpenWrt/PartEFI/scripts/

        ;;

        11)

          echo ""
          echo "  Copiando el script de instalación de paquetes..."
          echo ""
          sudo mkdir -p /OpenWrt/PartExt4/root/scripts/ 2> /dev/null
          # Comprobar si el paquete wget está instalado. Si no lo está, instalarlo.
            if [[ $(dpkg-query -s wget 2>/dev/null | grep installed) == "" ]]; then
              echo ""
              echo "  wget no está instalado. Iniciando su instalación..."
              echo ""
              sudo apt-get -y update && sudo apt-get -y install wget
              echo ""
            fi
          sudo su -c "wget https://raw.githubusercontent.com/nipegun/o-scripts/master/PostInst/MVdeProxmox-InstalarPaquetes.sh -O /OpenWrt/PartExt4/root/scripts/1-InstalarPaquetes.sh"
          echo "rm -rf /root/scripts/1-InstalarPaquetes.sh"                                                                    >> /OpenWrt/PartExt4/root/scripts/1-InstalarPaquetes.sh
          echo "reboot"                                                                                                        >> /OpenWrt/PartExt4/root/scripts/1-InstalarPaquetes.sh
          sudo chmod +x                                                                                                           /OpenWrt/PartExt4/root/scripts/1-InstalarPaquetes.sh
        ;;

        12)

          echo ""
          echo "  Copiando el script de instalación de los o-scripts..."
          echo ""
          sudo su -c "echo '#!/bin/sh'                                                                                       > /OpenWrt/PartExt4/root/scripts/2-InstalarOScripts.sh"
          sudo su -c 'echo ""                                                                                               >> /OpenWrt/PartExt4/root/scripts/2-InstalarOScripts.sh'
          sudo su -c 'echo "wget -O - https://raw.githubusercontent.com/nipegun/o-scripts/master/OScripts-Instalar.sh | sh" >> /OpenWrt/PartExt4/root/scripts/2-InstalarOScripts.sh'
          sudo su -c 'echo "rm -rf /root/scripts/2-InstalarOScripts.sh"                                                     >> /OpenWrt/PartExt4/root/scripts/2-InstalarOScripts.sh'
          sudo chmod +x                                                                                                        /OpenWrt/PartExt4/root/scripts/2-InstalarOScripts.sh

        ;;

        13)

          echo ""
          echo "  Copiando el script de preparación de OpenWrt para funcionar como una MV de Proxmox..."
          echo ""
          # Comprobar si el paquete wget está instalado. Si no lo está, instalarlo.
            if [[ $(dpkg-query -s wget 2>/dev/null | grep installed) == "" ]]; then
              echo ""
              echo "    El paquete wget no está instalado. Iniciando su instalación..."
              echo ""
              sudo apt-get -y update && sudo apt-get -y install wget
              echo ""
            fi
          sudo wget https://raw.githubusercontent.com/nipegun/o-scripts/master/PostInst/ConfigurarComo-MVdeProxmox.sh -O /OpenWrt/PartExt4/root/scripts/3-PrepararOpenWrtParaMVDeProxmox.sh
          sudo chmod +x                                                                                                  /OpenWrt/PartExt4/root/scripts/3-PrepararOpenWrtParaMVDeProxmox.sh

        ;;


        14)

          echo ""
          echo "  Copiando el script de preparación de OpenWrt para funcionar como un laboratorio de ciberseguridad..."
          echo ""
          # Comprobar si el paquete wget está instalado. Si no lo está, instalarlo.
            if [[ $(dpkg-query -s wget 2>/dev/null | grep installed) == "" ]]; then
              echo ""
              echo "    El paquete wget no está instalado. Iniciando su instalación..."
              echo ""
              sudo apt-get -y update && sudo apt-get -y install wget
              echo ""
            fi
          sudo wget https://raw.githubusercontent.com/nipegun/o-scripts/master/PostInst/ConfigurarComo-CyberLab.sh -O /OpenWrt/PartExt4/root/scripts/3-PrepararOpenWrtParaCyberLab.sh
          sudo chmod +x                                                                                               /OpenWrt/PartExt4/root/scripts/3-PrepararOpenWrtParaCyberLab.sh

        ;;



        15)

          echo ""
          echo "  Moviendo copia de seguridad de la instalación anterior a la instalación nueva..."
          echo ""
          # Crear carpeta en la nueva partición
          sudo mkdir -p /OpenWrt/PartExt4/CopSeg/
          # Mover archivos
            sudo mv /CopSegOpenWrt/$vFechaDeEjec/ /OpenWrt/PartExt4/CopSeg/
          # Borrar carpeta de copia de seguridad de la partición de Debian Live
            sudo rm -rf  /CopSegOpenWrt/
        ;;

        16)

          echo ""
          echo "  Instalando paquetes para poder visualizar los cambios realizados..."
          echo ""
          sudo apt-get -y install mc
          sudo apt-get -y install gparted

        ;;

        17)

          echo ""
          echo "  Apagando la máquina virtual..."
          echo ""
          #eject
          sudo shutdown -h now

        ;;

      esac

done

echo ""
echo " ----------"
echo "  Ejecución del script, finalizada."
echo ""
echo "  Reinicia el sistema con:"
echo "  sudo shutdown -r now"
echo ""
echo "  Recuerda quitar el DVD de la unidad antes de que vuelva a arrancar la máquina virtual."
echo " ----------"
echo ""

