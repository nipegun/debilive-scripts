#!/bin/bash

# Pongo a disposición pública este script bajo el término de "software de dominio público".
# Puedes hacer lo que quieras con él porque es libre de verdad; no libre con condiciones como las licencias GNU y otras patrañas similares.
# Si se te llena la boca hablando de libertad entonces hazlo realmente libre.
# No tienes que aceptar ningún tipo de términos de uso o licencia para utilizarlo o modificarlo porque va sin CopyLeft.

# ----------
#  Script de NiPeGun para instalar OpenWrt en una máquina virtual de ProxmoxVE inciando desde Debian Live 
#
# Ejecución remota:
# curl -s https://raw.githubusercontent.com/nipegun/debilive-scripts/main/OpenWrtX86-v21-InstalarEnMVDeProxmox.sh | bash
# ----------

ColorAzul="\033[0;34m"
ColorAzulClaro="\033[1;34m"
ColorVerde='\033[1;32m'
ColorRojo='\033[1;31m'
FinColor='\033[0m'

vFechaDeEjec=$(date +A%Y-M%m-D%d@%T)
vPrimerDisco="/dev/sda"

echo ""
echo -e "${ColorAzul}  Iniciando el script de instalación de OpenWrt X86 para máquinas virtuales de Proxmox...${FinColor}"
echo ""

# Comprobar si el paquete dialog está instalado. Si no lo está, instalarlo.
  if [[ $(dpkg-query -s dialog 2>/dev/null | grep installed) == "" ]]; then
    echo ""
    echo -e "${ColorRojo}    dialog no está instalado. Iniciando su instalación...${FinColor}"
    echo ""
    sudo apt-get -y update 2> /dev/null
    sudo apt-get -y install dialog
    echo ""
  fi

  # Cambiar resolución de la pantalla
    vNombreDisplay=$(xrandr | grep " connected" | cut -d" " -f1)
    xrandr --output $vNombreDisplay --mode 1024x768

menu=(dialog --checklist "Instalación de OpenWrt X86:" 30 100 20)
  opciones=(
     1 "Hacer copia de seguridad de la instalación anterior." on
     2 "Crear las particiones." on
     3 "Formatear las particiones." on
     4 "Marcar la partición OVMF como esp." on
     5 "Determinar la última versión de OpenWrt." on
     6 "Montar las particiones." on
     7 "Descargar Grub para EFI." on
     8 "Crear el archivo de configuración para Grub." on
     9 "Crear la estructura de carpetas y archivos en ext4." on
    10 "Configurar la MV para que pille IP por DHCP." on
    11 "Copiar el script de instalación de paquetes." on
    12 "Copiar el script de instalación de los o-scripts." on
    13 "Copiar el script de preparación de OpenWrt para funcionar como una MV de Proxmox." on
    14 "Copiar el script de activación de WiFi." on
    15 "Mover copia de seguridad de la instalación anterior a la nueva instalación." on
    16 "Instalar Midnight Commander para poder visualizar los cambios realizados." on
    17 "Apagar la máquina virtual." on
  )
  choices=$("${menu[@]}" "${opciones[@]}" 2>&1 >/dev/tty)
  clear

  for choice in $choices
    do
      case $choice in

        1)

          echo ""
          echo -e "${ColorAzulClaro}    Haciendo copia de seguridad de la instalación anterior...${FinColor}"
          echo ""
          # Desmontar discos, si es que están montados
            sudo umount $vPrimerDisco"1" 2> /dev/null
            sudo umount $vPrimerDisco"2" 2> /dev/null
            sudo umount $vPrimerDisco"3" 2> /dev/null
          # Crear particiones para montar
            sudo mkdir -p /OpenWrt/PartOVMF/
            sudo mount -t auto $vPrimerDisco"1" /OpenWrt/PartOVMF/
            sudo mkdir -p /OpenWrt/PartExt4/
            sudo mount -t auto $vPrimerDisco"2" /OpenWrt/PartExt4/
          # Crear carpeta donde guardar los archivos
            sudo mkdir -p /CopSegOpenWrt/$vFechaDeEjec/PartOVMF/
            sudo mkdir -p /CopSegOpenWrt/$vFechaDeEjec/PartExt4/
          # Copiar archivos
            sudo cp -r /OpenWrt/PartOVMF/* /CopSegOpenWrt/$vFechaDeEjec/PartOVMF/
            sudo cp -r /OpenWrt/PartExt4/* /CopSegOpenWrt/$vFechaDeEjec/PartExt4/
          # Desmontar partición 
            sudo umount /OpenWrt/PartOVMF/
            sudo rm -rf  /OpenWrt/PartOVMF/
            sudo umount /OpenWrt/PartExt4/
            sudo rm -rf  /OpenWrt/PartOVMF/
        ;;

        2)

          echo ""
          echo -e "${ColorAzulClaro}    Creando las particiones...${FinColor}"
          echo ""
          sudo rm -rf /OpenWrt/PartOVMF/*
          sudo rm -rf /OpenWrt/PartExt4/*
          sudo umount $vPrimerDisco"1" 2> /dev/null
          sudo umount $vPrimerDisco"2" 2> /dev/null
          sudo umount $vPrimerDisco"3" 2> /dev/null
          sudo swapoff -a
          # Comprobar si el paquete parted está instalado. Si no lo está, instalarlo.
            if [[ $(dpkg-query -s parted 2>/dev/null | grep installed) == "" ]]; then
              echo ""
              echo -e "${ColorRojo}      parted no está instalado. Iniciando su instalación...${FinColor}"
              echo ""
              sudo apt-get -y update 2> /dev/null
              sudo apt-get -y install parted
              echo ""
            fi
          # Crear tabla de particiones GPT
            sudo parted -s $vPrimerDisco mklabel gpt
          # Crear la partición OVMF
            sudo parted -s $vPrimerDisco mkpart OVMF ext4 1MiB 201MiB
          # Crear la partición ext4
            sudo parted -s $vPrimerDisco mkpart OpenWrt ext4 201MiB 24580MiB
          # Crear la partición de intercambio
            sudo parted -s $vPrimerDisco mkpart Intercambio ext4 24580MiB 100%

        ;;

        3)

          echo ""
          echo -e "${ColorAzulClaro}    Formateando las particiones...${FinColor}"
          echo ""
          # Comprobar si el paquete dosfstools está instalado. Si no lo está, instalarlo.
            if [[ $(dpkg-query -s dosfstools 2>/dev/null | grep installed) == "" ]]; then
              echo ""
              echo -e "${ColorRojo}      dosfstools no está instalado. Iniciando su instalación...${FinColor}"
              echo ""
              sudo apt-get -y update 2> /dev/null
              sudo apt-get -y install dosfstools
              echo ""
            fi
          # Formatear la partición para EFI como fat32
            sudo mkfs -t vfat -F 32 -n OVMF $vPrimerDisco"1"
          # Formatear la partición para OpenWrt como ext4
            sudo mkfs -t ext4 -L OpenWrt $vPrimerDisco"2"
          # Formatear la partición para Intercambio como swap
            sudo mkswap -L Intercambio $vPrimerDisco"3"

        ;;

        4)

          echo ""
          echo -e "${ColorAzulClaro}    Marcando la partición EFI como esp...${FinColor}"
          echo ""
          # Comprobar si el paquete parted está instalado. Si no lo está, instalarlo.
            if [[ $(dpkg-query -s parted 2>/dev/null | grep installed) == "" ]]; then
              echo ""
              echo -e "${ColorRojo}      parted no está instalado. Iniciando su instalación...${FinColor}"
              echo ""
              sudo apt-get -y update 2> /dev/null
              sudo apt-get -y install parted
              echo ""
            fi
          sudo parted -s $vPrimerDisco set 1 esp on

        ;;

        5)

          echo ""
          echo -e "${ColorAzulClaro}    Determinando la última versión de OpenWrt...${FinColor}"
          echo ""

          # Comprobar si el paquete curl está instalado. Si no lo está, instalarlo.
            if [[ $(dpkg-query -s curl 2>/dev/null | grep installed) == "" ]]; then
              echo ""
              echo -e "${ColorRojo}      curl no está instalado. Iniciando su instalación...${FinColor}"
              echo ""
              sudo apt-get -y update 2> /dev/null
              sudo apt-get -y install curl
              echo ""
            fi
  
          VersOpenWrt=$(curl --silent https://downloads.openwrt.org | grep rchive | grep eleases | grep OpenWrt | grep 21 | head -n 1 | cut -d'/' -f 5)

          echo ""
          echo -e "${ColorAzulClaro}      La última versión estable de OpenWrt 21 es la $VersOpenWrt.${FinColor}"
          echo ""

        ;;

        6)

          echo ""
          echo -e "${ColorAzulClaro}    Montando las particiones...${FinColor}"
          echo ""
          sudo mkdir -p /OpenWrt/PartOVMF/ 2> /dev/null
          sudo mount -t auto /dev/sda1 /OpenWrt/PartOVMF/
          sudo mkdir -p /OpenWrt/PartExt4/ 2> /dev/null
          sudo mount -t auto /dev/sda2 /OpenWrt/PartExt4/

        ;;

        7)

          echo ""
          echo -e "${ColorAzulClaro}    Descargando grub para efi...${FinColor}"
          echo ""
          sudo mkdir -p /OpenWrt/PartOVMF/EFI/Boot/ 2> /dev/null
          rm -rf /OpenWrt/PartOVMF/EFI/Boot/*
          # Comprobar si el paquete wget está instalado. Si no lo está, instalarlo.
            if [[ $(dpkg-query -s wget 2>/dev/null | grep installed) == "" ]]; then
              echo ""
              echo -e "${ColorRojo}      wget no está instalado. Iniciando su instalación...${FinColor}"
              echo ""
              sudo apt-get -y update 2> /dev/null
              sudo apt-get -y install wget
              echo ""
            fi
          # sudo wget http://hacks4geeks.com/_/premium/descargas/OpenWrtX86/PartEFI/EFI/Boot/bootx64.efi -O /OpenWrt/PartOVMF/EFI/Boot/bootx64.efi
          sudo wget https://raw.githubusercontent.com/nipegun/ubulive-scripts/main/Recursos/bootx64openwrt.efi -O /OpenWrt/PartOVMF/EFI/Boot/bootx64.efi
        ;;

        8)

          echo ""
          echo -e "${ColorAzulClaro}    Creando el archivo de configuración para Grub (grub.cfg)...${FinColor}"
          echo ""
          sudo mkdir -p /OpenWrt/PartOVMF/EFI/OpenWrt/ 2> /dev/null
          sudo su -c "echo 'serial --unit=0 --speed=115200 --word=8 --parity=no --stop=1 --rtscts=off'                                                            > /OpenWrt/PartOVMF/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo 'terminal_input console serial; terminal_output console serial'                                                                       >> /OpenWrt/PartOVMF/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo ''                                                                                                                                    >> /OpenWrt/PartOVMF/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo 'set default="'"0"'"'                                                                                                                 >> /OpenWrt/PartOVMF/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo 'set timeout="'"1"'"'                                                                                                                 >> /OpenWrt/PartOVMF/EFI/OpenWrt/grub.cfg"
          sudo su -c 'echo "set root='"'(hd0,2)'"'"                                                                                                              >> /OpenWrt/PartOVMF/EFI/OpenWrt/grub.cfg'
          sudo su -c "echo ''                                                                                                                                    >> /OpenWrt/PartOVMF/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo 'menuentry "'"OpenWrt"'" {'                                                                                                           >> /OpenWrt/PartOVMF/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo '  linux /boot/generic-kernel.bin root=/dev/sda2 rootfstype=ext4 rootwait console=tty0 console=ttyS0,115200n8 noinitrd'               >> /OpenWrt/PartOVMF/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo '}'                                                                                                                                   >> /OpenWrt/PartOVMF/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo 'menuentry "'"OpenWrt (failsafe)"'" {'                                                                                                >> /OpenWrt/PartOVMF/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo '  linux /boot/generic-kernel.bin failsafe=true root=/dev/sda2 rootfstype=ext4 rootwait console=tty0 console=ttyS0,115200n8 noinitrd' >> /OpenWrt/PartOVMF/EFI/OpenWrt/grub.cfg"
          sudo su -c "echo '}'                                                                                                                                   >> /OpenWrt/PartOVMF/EFI/OpenWrt/grub.cfg"

        ;;

        9)

          echo ""
          echo -e "${ColorAzulClaro}    Creando la estructura de carpetas y archivos en la partición ext4 con OpenWrt $VersOpenWrt...${FinColor}"          
          echo ""

          echo ""
          echo -e "${ColorAzulClaro}    Borrando el contenido de la partición ext4...${FinColor}"
          echo ""
          sudo rm -rf /OpenWrt/PartExt4/*

          echo ""
          echo -e "${ColorAzulClaro}    Descargando y posicionando el Kernel...${FinColor}"
          echo ""
          sudo mkdir -p /OpenWrt/PartExt4/boot 2> /dev/null
          # Comprobar si el paquete wget está instalado. Si no lo está, instalarlo.
            if [[ $(dpkg-query -s wget 2>/dev/null | grep installed) == "" ]]; then
              echo ""
              echo -e "${ColorRojo}      wget no está instalado. Iniciando su instalación...${FinColor}"
              echo ""
              sudo apt-get -y update 2> /dev/null
              sudo apt-get -y install wget
              echo ""
            fi
          sudo wget --no-check-certificate https://downloads.openwrt.org/releases/$VersOpenWrt/targets/x86/64/openwrt-$VersOpenWrt-x86-64-generic-kernel.bin -O /OpenWrt/PartExt4/boot/generic-kernel.bin

          echo ""
          echo -e "${ColorAzulClaro}    Descargando el archivo con el sistema root...${FinColor}"
          echo ""
          sudo rm -rf /OpenWrt/PartOVMF/rootfs.tar.gz
          sudo wget --no-check-certificate https://downloads.openwrt.org/releases/$VersOpenWrt/targets/x86/64/openwrt-$VersOpenWrt-x86-64-rootfs.tar.gz -O /OpenWrt/PartOVMF/rootfs.tar.gz

          echo ""
          echo -e "${ColorAzulClaro}    Descomprimiendo el sistema de archivos root en la partición ext4...${FinColor}"
          echo ""

          # Comprobar si el paquete tar está instalado. Si no lo está, instalarlo.
            if [[ $(dpkg-query -s tar 2>/dev/null | grep installed) == "" ]]; then
              echo ""
              echo -e "${ColorRojo}      tar no está instalado. Iniciando su instalación...${FinColor}"
              echo ""
              sudo apt-get -y update 2> /dev/null
              sudo apt-get -y install tar
              echo ""
            fi
          sudo tar -xf /OpenWrt/PartOVMF/rootfs.tar.gz -C /OpenWrt/PartExt4/

        ;;

        10)

          echo ""
          echo -e "${ColorAzulClaro}    Configurando la MV de OpenWrt para que pille IP por DHCP...${FinColor}"
          echo ""
          sudo mkdir /OpenWrt/PartOVMF/scripts/ 2> /dev/null
          sudo su -c 'echo "config interface loopback"         > /OpenWrt/PartOVMF/scripts/network'
          sudo su -c 'echo "  option ifname '"'lo'"'"         >> /OpenWrt/PartOVMF/scripts/network'
          sudo su -c 'echo "  option proto '"'static'"'"      >> /OpenWrt/PartOVMF/scripts/network'
          sudo su -c 'echo "  option ipaddr '"'127.0.0.1'"'"  >> /OpenWrt/PartOVMF/scripts/network'
          sudo su -c 'echo "  option netmask '"'255.0.0.0'"'" >> /OpenWrt/PartOVMF/scripts/network'
          sudo su -c 'echo ""                                 >> /OpenWrt/PartOVMF/scripts/network'
          sudo su -c 'echo "config interface '"'i_wan'"'"     >> /OpenWrt/PartOVMF/scripts/network'
          sudo su -c 'echo "  option ifname '"'eth0'"'"       >> /OpenWrt/PartOVMF/scripts/network'
          sudo su -c 'echo "  option proto '"'dhcp'"'"        >> /OpenWrt/PartOVMF/scripts/network'
          sudo rm -rf                               /OpenWrt/PartExt4/etc/config/network
          sudo cp /OpenWrt/PartOVMF/scripts/network /OpenWrt/PartExt4/etc/config/

        ;;

        11)

          echo ""
          echo -e "${ColorAzulClaro}    Copiando el script de instalación de paquetes...${FinColor}"
          echo ""
          sudo mkdir -p /OpenWrt/PartOVMF/scripts/ 2> /dev/null
          sudo su -c "echo '#!/bin/sh'                                          > /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh"
          sudo su -c 'echo ""                                                  >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "opkg update"                                       >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "  opkg install nano"                               >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "  opkg install mc"                                 >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "  opkg install pciutils"                           >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "  opkg install wget"                               >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "  opkg install git-http"                           >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "  opkg install tcpdump"                            >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "  opkg install msmtp"                              >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "  opkg install ca-bundle"                          >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "  opkg install ca-certificates"                    >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "  opkg install libustream-openssl"                 >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "opkg update"                                       >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "  # Controladores WiFi"                            >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "    opkg install hostapd-openssl"                  >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "    opkg install kmod-mac80211"                    >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "    opkg install kmod-ath"                         >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "    opkg install kmod-ath9k"                       >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "    # Adaptadores Wifi Compex a/b/g/n/ac Wave 2"   >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "      opkg install kmod-ath10k-ct"                 >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "      opkg install ath10k-firmware-qca9984-ct-htt" >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "  # Controladores ethernet"                        >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "    # Adaptador Intel 82575/82576"                 >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "      opkg install kmod-igb"                       >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "    # Adaptador Intel"                             >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "      #opkg install kmod-e1000"                    >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "opkg update"                                       >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "  # LUCI"                                          >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "    opkg install luci-i18n-base-es"                >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "    opkg install luci-i18n-firewall-es"            >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "    opkg install luci-i18n-adblock-es"             >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "    opkg install luci-i18n-qos-es"                 >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "    opkg install luci-i18n-wifischedule-es"        >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "    opkg install luci-i18n-wireguard-es"           >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "    opkg install luci-i18n-wol-es"                 >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo ""                                                  >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "  echo ..."                                        >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "  echo Reiniciando OpenWrt..."                     >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "  echo ..."                                        >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo ""                                                  >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo su -c 'echo "reboot"                                            >> /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh'
          sudo mkdir -p                                           /OpenWrt/PartExt4/root/scripts/
          sudo cp /OpenWrt/PartOVMF/scripts/1-InstalarPaquetes.sh /OpenWrt/PartExt4/root/scripts/1-InstalarPaquetes.sh
          sudo chmod +x                                           /OpenWrt/PartExt4/root/scripts/1-InstalarPaquetes.sh

        ;;

        12)

          echo ""
          echo -e "${ColorAzulClaro}    Copiando el script de instalación de los o-scripts...${FinColor}"
          echo ""
          sudo mkdir -p                                                                                                        /OpenWrt/PartOVMF/scripts/ 2> /dev/null
          sudo su -c "echo '#!/bin/sh'                                                                                       > /OpenWrt/PartOVMF/scripts/2-InstalarOScripts.sh"
          sudo su -c 'echo ""                                                                                               >> /OpenWrt/PartOVMF/scripts/2-InstalarOScripts.sh'
          sudo su -c 'echo "wget -O - https://raw.githubusercontent.com/nipegun/o-scripts/master/OScripts-Instalar.sh | sh" >> /OpenWrt/PartOVMF/scripts/2-InstalarOScripts.sh'
          sudo cp /OpenWrt/PartOVMF/scripts/2-InstalarOScripts.sh /OpenWrt/PartExt4/root/scripts/2-InstalarOScripts.sh
          sudo chmod +x                                           /OpenWrt/PartExt4/root/scripts/2-InstalarOScripts.sh

        ;;

        13)

          echo ""
          echo -e "${ColorAzulClaro}    Copiando el script de preparación de OpenWrt para funcionar como una MV de Proxmox...${FinColor}"
          echo ""
          sudo mkdir -p /OpenWrt/PartOVMF/scripts/ 2> /dev/null
          # Comprobar si el paquete wget está instalado. Si no lo está, instalarlo.
            if [[ $(dpkg-query -s wget 2>/dev/null | grep installed) == "" ]]; then
              echo ""
              echo -e "${ColorRojo}      wget no está instalado. Iniciando su instalación...${FinColor}"
              echo ""
              sudo apt-get -y update > /dev/null
              sudo apt-get -y install wget
              echo ""
            fi
          sudo wget https://raw.githubusercontent.com/nipegun/o-scripts/master/PostInst/ConfigurarOpenWrt21ComoMVdeProxmox.sh -O /OpenWrt/PartOVMF/scripts/3-PrepararOpenWrtParaMVDeProxmox.sh
          sudo cp /OpenWrt/PartOVMF/scripts/3-PrepararOpenWrtParaMVDeProxmox.sh /OpenWrt/PartExt4/root/scripts/3-PrepararOpenWrtParaMVDeProxmox.sh
          sudo chmod +x /OpenWrt/PartExt4/root/scripts/3-PrepararOpenWrtParaMVDeProxmox.sh

        ;;

        14)

          echo ""
          echo -e "${ColorAzulClaro}    Copiando el script de activación de Wifi...${FinColor}"
          echo ""
          sudo su -c 'echo "#!/bin/sh"                                                                                   > /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          sudo su -c 'echo "opkg update"                                                                                >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          sudo su -c 'echo "opkg install curl"                                                                          >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          sudo su -c 'echo ""                                                                                           >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          #sudo su -c 'echo "uci set wireless.radio0.country='ES'"                                                       >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          #sudo su -c 'echo "uci set wireless.radio0.channel='auto'"                                                     >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          #sudo su -c 'echo "uci set wireless.radio0.disabled='0'"                                                       >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          #sudo su -c 'echo "uci set wireless.radio1.country='ES'"                                                       >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          #sudo su -c 'echo "uci set wireless.radio1.channel='auto'"                                                     >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          #sudo su -c 'echo "uci set wireless.radio1.disabled='0'"                                                       >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          #sudo su -c 'echo "uci set wireless.default_radio0.disabled='0'"                                               >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          #sudo su -c 'echo "uci set wireless.default_radio1.disabled='0'"                                               >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          #sudo su -c 'echo "uci set wireless.inv_radio0.disabled='0'"                                                   >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          #sudo su -c 'echo "uci set wireless.inv_radio1.disabled='0'"                                                   >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          #sudo su -c 'echo "uci set wireless.iot_radio0.disabled='0'"                                                   >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          #sudo su -c 'echo "uci set wireless.iot_radio1.disabled='0'"                                                   >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          #sudo su -c 'echo "uci commit wireless"                                                                        >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          #sudo su -c 'echo "wifi reload"                                                                                >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          sudo su -c 'echo ""                                                                                           >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          sudo su -c 'echo "curl -s https://raw.githubusercontent.com/nipegun/o-scripts/master/WiFi-Configurar.sh | sh" >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          sudo su -c 'echo ""                                                                                           >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          sudo su -c 'echo "/sbin/wifi reload"                                                                          >> /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh'
          sudo chmod +x                                                                                                    /OpenWrt/PartExt4/root/scripts/4-ConfigurarWiFi.sh

        ;;

        15)

          echo ""
          echo -e "${ColorAzulClaro}    Moviendo copia de seguridad de la instalación anterior a la instalación nueva...${FinColor}"
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
          echo -e "${ColorAzulClaro}    Instalando Midnight Commander para poder visualizar los cambios realizados...${FinColor}"
          echo ""
          sudo apt-get -y install mc > /dev/null

        ;;


        17)

          echo ""
          echo -e "${ColorAzulClaro}    Apagando la máquina virtual...${FinColor}"
          echo ""
          #eject
          sudo shutdown -h now

        ;;

      esac

done

echo ""
echo " ----------"
echo "  Ejecución del script, finalizada."
echo "  Recuerda quitar el DVD de la unidad antes de que vuelva a arrancar la máquina virtual."
echo " ----------"
echo ""

