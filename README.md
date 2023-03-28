<<<<<<< HEAD
Projet (Proxmox)
=======
# Projet-Infra #

### Sujet ###

Créer un serveur de virutalisation (créer des VMs) avec une interface de monitring. Sur les VMs, il y aura un service web avec docker.
Pour automatiser la création de VMs, on utilisera Cloud-init et Terraform. Et on pouura se connecter à distance avec un VPN.

### Installation du projet ###

#### Partie I - Proxmox ####

- 1 : Installation du serveur (choix : Proxmox) :
  - La première partie est de télécharger l'iso de proxmox 6.0 et de le booter sur une clé usb. Et ensuite booter sur la clé pour installer proxmox. L'iso de proxmox se trouve sur leur site officiel.

  - Une fois lancé sur l'install de proxmox, il suffit de suivre les indications sur l'interface. Une fois la configuration fini, il suffit de reboot proxmox en enlevant la clé.

  - Une fois demarré, le proxmox vous dit de vous connecter en ligne grâce à l'adresse qu'il vous donne.

  ![Proxmox en ligne](img/proxmox.png)

  - Avant de toucher au proxmox, il va falloir faire des mises à jour pour pouvoir installer des paquets. Pour cela, il faut ajouter dans etc/apt/sources.list :

  ```
  deb http://download.proxmox.com/debian/pve buster pve-no-subscription
  ```

  - Commentez dans /etc/apt/sources.list.d/pve-entreprise.list la seule phrase.

  - On va ensuite ajouter les clés pour les paquets et leur données les droits :

  ```
  wget http://download.proxmox.com/debian/proxmox-ve-release-6.x.gpg -O /etc/apt/trusted.gpg.d/proxmox-ve-release-6.x.gpg
  chmod +r /etc/apt/trusted.gpg.d/proxmox-ve-release-6.x.gpg  # optional, if you have a non-default umask
  ```

  - Une fois fait, on peut faire un : ``` apt update -y ``` pour mettre à jour le système.
  > NE SURTOUT PAS FAIRE DE FULL UPGRADE !! (cloud-init pas supporté sur 6.1 ou risque de bug ou crash).

  - Proxmox est donc au point ! Il ne reste pas qu'à créer des VMs (à la main pour tester ou à automatiser (voir suite).


#### Partie 2 - Terraform et cloud-init ####

- 1 : Création de template avec cloud-init et installation de Terraform:

  - 1.1 : Créer un Template avec Coud-init (ISO - Centos)

    - Aller sur le Proxmox (cli) en ssh et commencer par télécharger l'iso centos pour cloud-init avec la commande suivante :

    ```
    wget https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud-1907.qcow2
    ```

    - Une fois l'iso téléchargé, on créer la VM et la configure avec les commandes suivantes :

    ```
    ## Créer la VM avec les caracteristiques que l'on souhaite.
    qm create 9000 --memory 2048 --net0 virtio,bridge=vmbr0
    ```
    ```
    ## Importe le disque téléchargé dans l'espace de stockage local-lvm (la où sont stocké toutes nos vms).
    qm importdisk 9000 CentOS-7-x86_64-GenericCloud-1907.qcow2 local-lvm
    ```
    ```
    ## Attache la Vm avec le nouveau disque de la vm avec le drive.
    qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
    ```
    ```
    ## On ajoute les options de cloud-init.
    qm set 9000 --ide2 local-lvm:cloudinit
    ```
    ```
    qm set 9000 --boot c --bootdisk scsi0
    ```
    ```
    qm set 9000 --serial0 socket --vga serial0
    ```
    ```
    ## On créer un template qu'on utilisera par la suite pour Terraform.
    qm template 9000
    ```

  - 1.2 : Utilisation de Terraform :

    -  Installer Terraform :

      - Se rendre sur le cli de proxmox et suivre les commandes suivantes :

      ```
      ## On commence par télécharger Terraform depuis le site officiel
      wget https://releases.hashicorp.com/terraform/12.0.21/terraform_12.0.21_linux_amd64.zip
      ```
      ```
      ## On extrait notre zip
      unzip terraform_12.0.21_linux_amd64.zip
      ```
      ```
      ## On déplace terraform dans le bin pour pouvoir l'executer depuis n'importe ou
      sudo mv terraform /usr/local/bin/
      ```

    - Terraform est ensuite prêt pour utilisation.


  - 1.3 : Installer le provider de terraform pour proxmox pour pouvoir l'utiliser et appeler le cloud-init :

    - Si vous souhaitez voir la documentation, voici le lien du provider proxmox pour Terraform : https://github.com/Telmate/terraform-provider-proxmox

    - Pour l'installer, il faut comencer par installer golang, pour celui suivez les commandes suivantes :

    > Ne pas installer golang avec le repository car il n'est pas sous la dernière mise à jour. Le provider de proxmox est compatible qu'avec une version de golang supérieur ou égal à 1.13. Vérifier votre version.

    ```
    # On télécharge la dernière version de golang
    wget https://dl.google.com/go/go1.13.4.linux-amd64.tar.gz
    ```
    ```
    # On l'installe et configure le path

    sudo tar -C /usr/local -xzf go1.13.4.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> $HOME/.profile
    source $HOME/.profile
    ```
    ```
    # On supprime le tar.gz
    rm go1.13.4.linux-amd64.tar.gz
    ```
    ```
    # On regarde si on a bien la dernière version
    go version
    ```
    - On a aussi besoin de télécharger le paquet git pour pouvoir "cloner / installer le provider" depuis github :

    ```
    apt install git -y
    ```
    - Une fois cela fait, il suffit d'installer le provider avec les commandes suivantes :

    ```
    go get -v github.com/Telmate/terraform-provider-proxmox/cmd/terraform-provider-proxmox
    ```
    ```
    go get -v github.com/Telmate/terraform-provider-proxmox/cmd/terraform-provisioner-proxmox
    ```

    - Une fois le provider installé, un dossier go s'est créé.

    - Pour génerer les puglins (provider et provisioner), il suffit de se rendre dans le dossier go/src/github.com/Telmate/terraform-provider-proxmox
      - Une fois à l'intérieur, il suffit d'éxecuter deux commandes pour build le projet et créer les plugins pour Terraform :

      ```
      make
      make install
      ```

      - Une fois cela fait, deux fichiers ont été créé (ils apparaissent dans le dossier go/bin) : terraform-provider-proxmox et terraform-provisioner-proxmox. C'est deux fichiers sont des puglins que va appeler terraform pour pouvoir utiliser proxmox.

- 2 : Configuration de terraform pour la création de VM avec cloud-init

  - Une fois le Template créé + terraform installé + le provider pour proxmox installé, la configuration peut commencer.

  - Pour que terraform execute notre fichier de configuration et utilise proxmox pour créer les VMs, il faut se rendre dans le dossier .terraform.d/ . Dans ce dossier on va ajouter les plugins proxmox pour pouvoir utiliser terraform avec proxmox. Pour cela, faites les commandes suivantes.

  ```
  ## On créer le dossier plugins dans .terraform.d
  mkdir plugins
  ```
  ```
  ## On se rend dans le dossier
  cd plugins
  ```
  ```
  ## Et on copie nos fichiers (plugins de proxmox) que l'on a géneré plus haut
  cp ~/go/bin/terraform-provider-proxmox .
  cp ~/go/bin/terraform-provisioner-proxmox .
  ```

  - Une fois cela fait, il nous manque plus qu'à créer notre fichier de configuration et l'executer.

  - Pour cela, on créer un fichier main.tf avec la commande :
  ```
  touch main.tf
  ```

  - Dans ce fichier on configure les vms que l'on souhaite créer et appele le template cloud-init que l'on souhaite utiliser.

  - Voici un exemple de fichier de configuration :

  ```
  provider "proxmox" {
  pm_tls_insecure = true
  /*
    // Credentials here or environment
    pm_api_url = "https://192.168.1.34:8006/api2/json"
    pm_password = "password"
    pm_user = "root@pam"
    //Optional
    pm_otp = "otpcode"
  */
  }

  resource "proxmox_vm_qemu" "cloudinit-test" {

    // Nom de la VM que l'on souahite créer
    name = "terraform-cloud-init"

    // Description
    desc = "test de terraform avec cloud-init"

    // Nom du node (notre serveur)
    target_node = "pve"

    // Nom du Template cloud-init qu'on va utiliser
    clone = "Template-Centos"

    // Les caracteristiques de la VM
    storage = "local-lvm"
    cores = 2
    sockets = 1
    memory = 1024
    nic = "virtio"
    bridge = "vmbr0"

    ssh_user = "root"
    ssh_private_key = <<EOF
    -----BEGIN RSA PRIVATE KEY-----
    private ssh key root
    -----END RSA PRIVATE KEY-----
    EOF

    os_type = "cloud-init"

    // Configure l'adresse IP en DHCP, il est possible de la mettre en static
    os_network_config = <<EOF
    auto eth0
    iface eth0 inet dhcp
    EOF


    // On peut ajouter les clés ssh pour se connecter si besoin
      sshkeys = <<EOF
    EOF

      provisioner "remote-exec" {
       inline = [
         "ip a"
       ]
     }

    }

  ```

  - Pour la création de plusieurs VM, il suffit de rajouter une "resource" en dessous de la première.

- 3 : Executer le fichier de configuration pour pouvoir créer nos VMs.

  - Avant d'executer le fichier on va devoir exporter nos données de notre api en modifiant nos données de connexion :

  ```
  export PM_API_URL="https://192.168.1.34:8006/api2/json"
  export PM_USER=root@pam
  export PM_PASS=password
  ```

  - Petit problème, lorsqu'on reboot, les données (export) ne se sauvegarde pas. Pour ma part je les ai déclaré dans le .bashrc.

  - Pour executer, il suffit d'aller la où est situé le fichier de configuration et d'appliquer les 3 commandes suivantes :

    ```
    ## Cette commande va voir si un fichier de configuration est présent
    Terraform init
    ```
    ```
    ## Cette commande va vérifier si notre fichier de configuration contient des erreurs
    Terraform plan
    ```
    ```
    ## Si le fichier ne contient aucune erreur, alors il nous reste plus qu'à l'appliquer pour créer les Vms.
    Terraform apply
    ```

    - Cette commande met quelques minutes à s'executer, le temps que les VMs se créent. Une fois fait, un retour dans la console affiche les informations de la Vm : si elle contient un user, password, des clés ssh ... Une fois cela afficher, vous pouvez ctrl+c le terminal pour arrêter le retour d'informations. En allant sur notre proxmox (interface), on peut remarquer que nos VMs se sont bien crée.

    - Pour configurer un user et un password si cela n'est pas fait dans le terraform, il suffit de se rendre sur la vm, aller sur l'option cloud-init et remplir les champs que l'on souhaite renseigner.

    - Nos VMs sont créer et utilisent cloud-init !!!!!!


#### Partie 3 - Interface de monitoring  ####

- 1 : Installation de zabbix (interface de monitring) :
  - Pour l'installation de zabbix, suivez la doc suivante en précisant sous quel OS on l'installe. Exemple : J'installe Zabbix sous une vm centos 7 :
  https://www.zabbix.com/download?zabbix=4.4&os_distribution=centos&os_version=7&db=mysql&ws=apache

  - Une fois l'installation fini, il va falloir configurer zabbix pour qu'il aille monitorer proxmox. Normalement sans Proxmox, vous devez avoir qu'un hôte, votre propre VM (zabbix).

  - Pour relier proxmox à zabbix, il suffit de se rendre sur le cli de proxmox et d'installer le zabbix-agent.

  ```
  apt install zabbix-agent
  ```

  - Une fois le zabbix-agent installé, on va aller le configurer pour que proxmox se relie au zabbix. Pour cela, il faut se rendre dans /etc/zabbix et modifier le fichier zabbix_agentd.conf

  ```
  ## Remplacer la ligne Server=127.0.0.1 par Server=(l'adresse ip de votre vm (zabbix)). ex :
  Server=192.168.1.68
  ```
  ```
  ## Faire la même chose pour ServerActive
  ServerActive=192.168.1.68
  ```

  - Une fois fait, relancez le zabbix-agent :

  ```
  systemctl restart zabbix-agent
  ```

- 2 : Configuration de proxmox sur le zabbix :

  - Lorsqu'on a restart le zabbix-agent après l'avoir configuré, on peut remarquer qu'un host non avaible ou unknow est apparu sur zabbix. Vu que l'hôte proxmox n'est pas crée, zabbix ne le reconnais pas. Pour cela, il suffit de se rendre dans configuration/hosts et de créer un nouveau host.

  - Configuration de mon hôte proxmox :

  ![Hôte proxmox](img/hotezabbix.png)

  - L'adresse ip à renseigner est celle du proxmox.

  - Il manque plus qu'à ajouter un template pour pouvoir ajouter des graph et pleins d'items à notre proxmox.

  - Pour cela modifier l'hosts en cliquant dessus et se rendre dans la rubrique template et choisir le template que l'on veut. Pour ma part j'ai choisis le template OS Linux by Zabbix-agent.

  - Une fois le template choisi, il suffit d'attendre quelques secondes et de rafraichir la page pour que notre host proxmox devienne avaible (valide).

  - Il reste plus qu'à ajouter des widgets à notre interface (directement accessible sur le dashboard en edit) et choisir les items que l'on souhaite monitorer.

  - Voici un exemple de mon dashboard :

  ![Dashboard](img/dashboard.png)

#### Partie 4 - VPN  

- 1 : Installation de OpenVPN

  - Pour ma part, j'ai installé OpenVPN sur une VM CentOS. Une fois la Vm créer et configurer, on peut installer un script automatique d'openVPN.

  - En cli, executez les commandes suivantes pour installer le script :

  ```
  curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
  chmod +x openvpn-install.sh
  ```

  - Un script ./openvpn-install.sh s'est installé.

  - Pour configurer le Openvpn, il suffit juste d'executer le script, renseigner l'adresse IP public, les configurations que l'on souhaite et le tour est joué. Un fichier .ovpn a été crée. Ce fichier est à placer sur votre ordinateur pour pouvoir se connecter à distance.

  - Il est important par la suite de configurer le port 1194 sur votre livebox (l'ajouter en NAT/PAT pour pouvoir y accéder depuis l'exterieur). EX :

    ![Ports](img/liveports.png)

  - Et en dernier, de vérifiersi le firewall est activé. S'il est activé, il ne laissera pas passer la connexion. Pour cela, vous pouvez le désactiver en faisant un :

  ```
  systemctl stop firewalld
  systemctl enable firewalld
  ```

  - Ou activer le port 1194 sur le firewall en executant :

  ```
  sudo firewall-cmd --zone=trusted --add-service openvpn --permanent

  ## reload le firewalld
  sudo firewall-cmd --reload
  ```

  - La connexion VPN pour se connecter à distance est configuré !!!


#### Partie 5 - Service web sur VM

- 1 : Installer docker et docker-compose sur notre VM :

  - Documentation officielle pour centos : https://docs.docker.com/install/linux/docker-ce/centos/

- 2 : Les fichiers de configuration

  - Une fois installé, on va créer un dossier docker où dedans il y aura notre fichier de configuration pour créer les containeurs, un dossier contenant le fichier de configuration de nginx et un dossier contenant nos sites web.

  > Le dossier avec les configuration sont données plus haut dans la racine du projet.

  - Le fichier docker-compose.yml va créer 3 containeurs, un mysql, un phpmyadmin et le plus important le nginx. Il est tout a fait possiblede le modifier pour ses soins : le mot de passe de mysql ou les ports.

  - Le fichier de configuration nginx va appeler le site.

- 3 : Lancer le docker

  - Pour lancer le docker il faut se placer dans le répertoire où est situé le yml et executer : ``` docker-compose up -d ```. On peut vérifier avec la commande : ```docker ps -a ``` si nos containeurs se sont bien créent.

  - On peut ensuite se rendre sur l'adresse IP de notre machine et notre site apparaît. Pour kill le service web, il suffit d'executer la commande : ```docker-compose down ```.
>>>>>>> d4e1068 (add files to repo)
