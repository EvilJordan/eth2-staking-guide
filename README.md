# ETH2 Self-Staking Guide - TEKU/GETH

This guide is built with a combination of information from:
- https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-testnet-prater
- https://www.coincashew.com/coins/overview-eth/guide-or-security-best-practices-for-a-eth2-validator-beaconchain-node
- https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet/monitoring-your-validator-with-grafana-and-prometheus
- https://someresat.medium.com/guide-to-staking-on-ethereum-2-0-ubuntu-prater-teku-3249f1922385
- https://docs.teku.consensys.net/en/stable/
- https://ethereum.org/en/eth2/staking/
- https://launchpad.ethereum.org/en/

---
This guide has references to "Prater," an Ethereum Testnet. Mainnet setup is nearly identical with only a few configurations and parameters changed. Make sure any external interactions through Metamask, Launchpad, beaconcha.in, etc. match your network expectations.

---

## Prerequisites
- [Set BIOS to power-on on power restore](https://www.intel.com/content/www/us/en/support/articles/000054773/intel-nuc/intel-nuc-mini-pcs.html)
- Disable Intel&reg; TurboBoost[^turboboost] in BIOS (Performance -> Power Settings)
- Install Ubuntu from USB: https://ubuntu.com/download/server
  - You probably want Option 2, Manual Installation
  - Prepare a bootable USB on [Windows](https://ubuntu.com/tutorials/create-a-usb-stick-on-windows) or [Mac](https://ubuntu.com/tutorials/create-a-usb-stick-on-macos)
- SFTP and SSH clients for remote administration
  - Windows: [CyberDuck](https://cyberduck.io/download/) and [puTTY](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html)
    - For puTTY, you probably want the "MSI (‘Windows Installer’)" version, in 64-bit x86. Probably.
  - Mac: [Cyberduck](https://cyberduck.io/download/) and the built-in [Console](https://support.apple.com/guide/console/welcome/mac)
- Additional USB to transfer files from key-generating machine to staking machine if not using local network
- [Goerli Testnet ETH](https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-testnet-prater#1.-obtain-testnet-eth)
- [Validator keys and deposit files](https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-testnet-prater#2.-signup-to-be-a-validator-at-the-launchpad) - Steps 1 and 2 OR you can skip all the hard stuff and use the [Wagyu](https://wagyu.gg/) GUI. No matter what process you pick, please generate these validator keys on a secure machine.

## Set up Router
- Assign a static IP to your staking machine.
- Open ports on router for SSH access (default port 22) (optional if not managing locally), p2p (9000), and eth1 (30303)

## Set up Staking Machine

### SSH into server and install lolcat (optional)
***This is personal thing, – no one else needs this.***
```console
git clone https://github.com/jaseg/lolcat.git
cd lolcat
sudo apt install make
sudo apt install gcc
make
sudo make install
cd ..
rm -rf lolcat
```
### SFTP into server and replace bash files and authorized_keys

### Update server
Running this command for the first time after a new install is always smart. It will be necessary to update your machine regularly (and manually, repeating these steps) to keep abreast of security and critical package updates.
```console
sudo apt-get update -y && sudo apt dist-upgrade -y
sudo apt-get autoremove
sudo apt-get autoclean
```

### Disable root account
```console
sudo passwd -l root
```

### Set up the Firewall
By default, deny all incoming and outgoing traffic
```console
sudo ufw default deny incoming
sudo ufw default allow outgoing
```
Allow ssh access
```console
sudo ufw allow ssh #22/tcp
```
Allow p2p ports
```console
sudo ufw allow 9000/tcp comment p2p
sudo ufw allow 9000/udp comment p2p
```
Allow eth1 port
```console
sudo ufw allow 30303/tcp comment eth1
sudo ufw allow 30303/udp comment eth1
```
Allow grafana web server port
```console
sudo ufw allow 3000/tcp comment grafana
```
Enable prometheus endpoint port
```console
sudo ufw allow 9090/tcp comment prometheus
```
Enable teku api
```console
sudo ufw allow 5051 comment teku-rest-api
```
Enable firewall
```console
sudo ufw enable
```
Check firewall status:
```console
sudo ufw status numbered
```
Output should look like:
```console
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    Anywhere                  
[ 2] 9000/tcp                   ALLOW IN    Anywhere                   # p2p
[ 3] 9000/udp                   ALLOW IN    Anywhere                   # p2p
[ 4] 30303/tcp                  ALLOW IN    Anywhere                   # eth1
[ 5] 30303/udp                  ALLOW IN    Anywhere                   # eth1
[ 6] 3000/tcp                   ALLOW IN    Anywhere                   # grafana
[ 7] 9090/tcp                   ALLOW IN    Anywhere                   # prometheus
[ 8] 5051                       ALLOW IN    Anywhere                   # teku-rest-api
[ 9] 22/tcp (v6)                ALLOW IN    Anywhere (v6)             
[10] 9000/tcp (v6)              ALLOW IN    Anywhere (v6)              # p2p
[11] 9000/udp (v6)              ALLOW IN    Anywhere (v6)              # p2p
[12] 30303/tcp (v6)             ALLOW IN    Anywhere (v6)              # eth1
[13] 30303/udp (v6)             ALLOW IN    Anywhere (v6)              # eth1
[14] 3000/tcp (v6)              ALLOW IN    Anywhere (v6)              # grafana
[15] 9090/tcp (v6)              ALLOW IN    Anywhere (v6)              # prometheus
[16] 5051 (v6)                  ALLOW IN    Anywhere (v6)              # teku-rest-api
```

### Fix SSD Storage
Check current configuration:
```console
df -h #
sudo lvdisplay #
```
Change configuration:
```console
sudo lvm
lvm> lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
lvm> lvextend -l +100%FREE -r /dev/ubuntu-vg/ubuntu-lv
lvm> exit
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
```
Check new configuration:
```console
df -h #
sudo lvdisplay #
```
### Nano
`nano`, a command you will see referenced from here on out, is a text editor. Here are some basics you will need to know:
- The bottom bar once you launch nano shows possible commands, based on context. The carrot symbol (`^`) means the "Control" key on your keyboard. So, `^X` means press the `Control` key _and_ the `x` key at the same time to exit.
- To save a file, or as nano calls it, "Write Out", `^O` (Control + O).
- Navigation is accomplished with the arrow keys, or `^Y` for page-up, `^V` for page-down.
- To search, press `^W` ("Where Is"), then type in your search and hit Enter.
- To exit nano, `^X`. If changes have been made, but not yet saved, nano will prompt to confirm changes, or if you want to discard or cancel the exit operation altogether.

### Install apcupsd (optional for UPS backups - requires USB cable)
If you do not have a UPS skip this step.  
If your UPS does not have a USB connection to allow it to be plugged into the staking machine, skip this step.
```console
sudo apt-get install apcupsd
```
Edit the name and device in `apcupsd.conf` configuration:
```console
sudo nano /etc/apcupsd/apcupsd.conf
```
Reboot the machine:
```console
sudo reboot
```

### SSH Lockdown
```console
sudo nano /etc/ssh/sshd_config
```
Edit `sshd_config`:

```properties
ChallengeResponseAuthentication no
PasswordAuthentication no
PermitRootLogin prohibit-password
PermitEmptyPasswords no
```
Confirm `sshd`'s configuration is error-free (there should be no output from this command):
```console
sudo sshd -t
```

### Secure Shared Memory
```console
sudo nano /etc/fstab
```
Add the following line to `fstab`:
```properties
tmpfs	/run/shm	tmpfs	ro,noexec,nosuid	0	0
```
Reboot the machine:
```console
sudo reboot
```

### Install Fail2Ban
```console
sudo apt-get install fail2ban -y
sudo nano /etc/fail2ban/jail.local
```
Add the following to `jail.local`:
```properties
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
ignoreip = 127.0.0.0/8 10.0.0.0/8 192.168.0.0/16
```
```console
sudo systemctl restart fail2ban
```

### Install SSH 2FA (optional)
This is Two-Factor Authentication for use with an app like Google Authenticator or Authy for an added layer of security to access the machine. The first layer, is, of course, SSH keys – a process not explained in this guide. Supplemental information about this process can be found [here](https://www.digitalocean.com/community/tutorials/how-to-set-up-multi-factor-authentication-for-ssh-on-ubuntu-18-04).
```console
sudo apt install libpam-google-authenticator -y
```
Edit the `sshd` file:
```console
sudo nano /etc/pam.d/sshd
```
Add the following to the `sshd` file:
```properties
auth required pam_google_authenticator.so
```
Find and comment out the below line by adding # in front of it:
```propeties
#@include common-auth
```
Restart the `sshd` service:
```console
sudo systemctl restart sshd.service
```
Edit the `sshd_config` file:
```console
sudo nano /etc/ssh/sshd_config
```
Find and set the following within the `sshd_config` file:
```properties
ChallengeResponseAuthentication yes
UsePAM yes
```
Add the following to the `sshd_config` file:
```properties
AuthenticationMethods publickey,keyboard-interactive
```
Confirm `sshd`'s configuration is error-free (there should be no output from this command):
```console
sudo sshd -t
```
Set up 2FA:
```console
google-authenticator
```
Answers to `google-authenticator` setup:
- yes
- yes
- yes
- no
- yes

Restart the `sshd` service:
```console
sudo systemctl restart sshd.service
```
Log out of the server:
```console
exit
```
Log back in to server via SSH to see 2FA in action.

### Install Java
Since we are running Teku (and possibly Besu) we need to install Java:
```console
sudo apt install default-jre default-jdk
```

## Install Prometheus/Grafana
### Install Prometheus
Determine the latest release version by visiting: https://github.com/prometheus/prometheus/releases

As of this writing, the latest release is `v2.32.1`

Replace any occurance of an incorrect release version below with the latest.

```console
sudo useradd --no-create-home --shell /bin/false prometheus
sudo useradd --no-create-home --shell /bin/false node_exporter
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown -R prometheus:prometheus /var/lib/prometheus
cd ~
curl -LO https://github.com/prometheus/prometheus/releases/download/v2.32.1/prometheus-2.32.1.linux-amd64.tar.gz
tar xvf prometheus-2.32.1.linux-amd64.tar.gz
sudo cp prometheus-2.32.1.linux-amd64/prometheus /usr/local/bin/
sudo cp prometheus-2.32.1.linux-amd64/promtool /usr/local/bin/
sudo cp -r prometheus-2.32.1.linux-amd64/consoles /etc/prometheus
sudo cp -r prometheus-2.32.1.linux-amd64/console_libraries /etc/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
rm -rf prometheus-2.32.1.linux-amd64
rm prometheus-2.32.1.linux-amd64.tar.gz
```
Edit the `prometheus.yml` file:
```console
sudo nano /etc/prometheus/prometheus.yml
```
Make sure the `prometheus.yml` file includes the below configuration. Pay special attention to spacing. Two _spaces_ are required for each indentation.

Optionally, change `scrape_interval: 5s` and `scape_timeout: 3s` for faster metrics updating at the expense of CPU load.

Also note, you probably aren't running `geth` _and_ `besu`. Both configurations are included here as an example, however.
```yaml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: "prometheus"
    static_configs:
    - targets: ["localhost:9090"]
  - job_name: "node_exporter"
    static_configs:
    - targets: ["localhost:9100"]
  - job_name: "geth"
    scrape_timeout: 10s
    metrics_path: /debug/metrics/prometheus
    scheme: http
    static_configs:
    - targets: ['localhost:6060']
  - job_name: "besu"
    scrape_timeout: 3s
    metrics_path: /metrics
    scheme: http
    static_configs:
    - targets:
      - localhost:9545
  - job_name: "teku"
    scrape_timeout: 10s
    metrics_path: /metrics
    scheme: http
    static_configs:
    - targets: ["localhost:8008"]
  - job_name: "json_exporter"
    static_configs:
    - targets:
      - 127.0.0.1:7979
  - job_name: "json"
    metrics_path: /probe
    static_configs:
    - targets:
      - https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd
    relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: 127.0.0.1:7979
```
Change permissions on the `prometheus.yml` file:
```console
sudo chown -R prometheus:prometheus /etc/prometheus/prometheus.yml
```
Edit the `prometheus.service` file:
```console
sudo nano /etc/systemd/system/prometheus.service
```
Add the following to the `prometheus.service` file:
```properties
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target
[Service]
Type=simple
User=prometheus
Group=prometheus
Restart=always
RestartSec=5
ExecStart=/usr/local/bin/prometheus \
	--config.file /etc/prometheus/prometheus.yml \
	--storage.tsdb.path /var/lib/prometheus/ \
	--web.console.templates=/etc/prometheus/consoles \
	--web.console.libraries=/etc/prometheus/console_libraries
[Install]
WantedBy=multi-user.target
```
Reload prometheus:
```console
sudo systemctl daemon-reload
sudo systemctl start prometheus
```
Check the status. There should be a green `active` in the output:
```console
sudo systemctl status prometheus
```
Enable the service:
```console
sudo systemctl enable prometheus
```
### Install Node Exporter
Determine the latest release version by visiting: https://github.com/prometheus/node_exporter/releases

As of this writing, the latest release is `v1.3.1`

Replace any occurance of an incorrect release version below with the latest.
```console
cd ~
curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz
tar xvf node_exporter-1.3.1.linux-amd64.tar.gz
sudo cp node_exporter-1.3.1.linux-amd64/node_exporter /usr/local/bin
sudo chown -R node_exporter:node_exporter /usr/local/bin/node_exporter
rm -rf node_exporter-1.3.1.linux-amd64
rm node_exporter-1.3.1.linux-amd64.tar.gz
sudo nano /etc/systemd/system/node_exporter.service
```
Add the following to the `node_exporter.service` file:
```properties
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target
[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter
[Install]
WantedBy=multi-user.target
```
Reload node exporter:
```console
sudo systemctl daemon-reload
sudo systemctl start node_exporter
```
Check the status. There should be a green `active` in the output:
```console
sudo systemctl status node_exporter
```
Enable the service:
```console
sudo systemctl enable node_exporter
```

### Install json_exporter
#### Install go:
Visit https://go.dev/dl/ to grab the latest version of go. As of this writing, that version is 1.17.6:
```console
cd ~
curl -OL https://go.dev/dl/go1.17.6.linux-amd64.tar.gz
```
Extract and install go:
```console
sudo tar -C /usr/local -xvf go1.17.6.linux-amd64.tar.gz
sudo ln -s /usr/local/go/bin/go /usr/bin/go
```
#### Create User Account
```console
sudo adduser --system json_exporter --group --no-create-home
```
#### Install json_exporter
```console
cd ~
git clone https://github.com/prometheus-community/json_exporter.git
cd json_exporter
make build
sudo cp json_exporter /usr/local/bin/
cd ~
rm -rf json_exporter
sudo chown json_exporter:json_exporter /usr/local/bin/json_exporter
```
#### Configure json_exporter
Create a directory for the json_exporter configuration file, and make it owned by the json_exporter account:

```console
sudo mkdir /etc/json_exporter
sudo chown json_exporter:json_exporter /etc/json_exporter
```
Edit the `json_exporter.yml` configuration file:
```console
sudo nano /etc/json_exporter/json_exporter.yml
```
Add the following text into the `json_exporter.yml` file. 
```yaml
metrics:
- name: ethusd
  path: "{.ethereum.usd}"
  help: Ethereum (ETH) price in USD
```
Change ownership of the configuration file to the json_exporter account.
```console
sudo chown json_exporter:json_exporter /etc/json_exporter/json_exporter.yml
```

#### Set Up System Service
Set up systemd to automatically start json_exporter. It will also restart the software if it stops.
```console
sudo nano /etc/systemd/system/json_exporter.service
```
Add the following text into the `json_exporter.service` file:
```properties
[Unit]
Description=JSON Exporter
[Service]
Type=simple
Restart=always
RestartSec=5
User=json_exporter
ExecStart=/usr/local/bin/json_exporter --config.file /etc/json_exporter/json_exporter.yml
[Install]
WantedBy=multi-user.target
```
Reload the systemd service file configurations, start node_exporter, then enable the json_exporter service to have it start automatically on reboot.

```console
sudo systemctl daemon-reload
sudo systemctl start json_exporter.service
```
Check the status. There should be a green `active` in the output:
```console
sudo systemctl status json_exporter.service
```
Enable the service:
```console
sudo systemctl enable json_exporter.service
```

### Install Grafana:
```console
curl -s -0 https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
sudo apt update
sudo apt install grafana
sudo systemctl start grafana-server
```
Check the status. There should be a green `active` in the output:
```console
sudo systemctl status grafana-server
```
Enable the service:
```console
sudo systemctl enable grafana-server
```

#### Modify Grafana.ini to allow higher rate:
```console
sudo nano /etc/grafana/grafana.ini
;min_refresh_interval = 1s
sudo systemctl restart grafana-server
```

#### Grafana Dashboards
1. Open `http://localhost:3000` or `http://<your validator's ip address or name>:3000` in your local browser.
2. Login with `admin` / `admin`
3. Change password
4. Click the `configuration gear` icon, then `Add Data Source`
5. Select `Prometheus`
6. Set Name to "Prometheus"
7. Set URL to `http://localhost:9090`
8. Click `Save & Test`
9. Download and save your consensus client's json file: [Teku](https://grafana.com/api/dashboards/13457/revisions/2/download)
10. Download and save your execution client's json file: [Geth](https://gist.githubusercontent.com/karalabe/e7ca79abdec54755ceae09c08bd090cd/raw/3a400ab90f9402f2233280afd086cb9d6aac2111/dashboard.json)
11. Download and save a [node-exporter dashboard](https://grafana.com/api/dashboards/11074/revisions/9/download) for general system monitoring.
12. Click Create `+` icon > `Import`
13. Add the consensus client dashboard via `Upload JSON file`
14. If needed, select Prometheus as `Data Source`.
15. Click the `Import` button.
16. Repeat steps 12-15 for the execution client dashboard.
17. Repeat steps 12-15 for the node-exporter dashboard.

## Install the Consensus (Teku) and Execution (Geth or Besu) Layers
### Generate a JWT
```console
sudo mkdir -p /var/lib/ethereum
openssl rand -hex 32 | tr -d "\n" | sudo tee /var/lib/ethereum/jwttoken
sudo chmod +r /var/lib/ethereum/jwttoken
```
> **Warning**
> Only install Geth _or_ Besu. Not both.

### Install Geth
```console
sudo add-apt-repository -y ppa:ethereum/ethereum
sudo apt-get update -y
sudo apt dist-upgrade -y
sudo apt install geth -y
```
Set permissions for geth:
```console
sudo useradd --no-create-home --shell /bin/false goeth
sudo mkdir -p /var/lib/goethereum
sudo chown -R goeth:goeth /var/lib/goethereum
```
Configure geth:
```console
sudo nano /etc/systemd/system/geth.service
```
Add the following to the `geth.service` file:
```properties
[Unit]
Description=Ethereum go client
After=network.target 
Wants=network.target

[Service]
User=goeth 
Group=goeth
Type=simple
Restart=always
RestartSec=5
ExecStart=geth --goerli --http --datadir /var/lib/goethereum --metrics --pprof

[Install]
WantedBy=default.target
```
Reload geth:
```console
sudo systemctl daemon-reload
sudo systemctl start geth
```
Check the status. There should be a green `active` in the output:
```console
sudo systemctl status geth
```
Enable the service:
```console
sudo systemctl enable geth
```
Wait for Geth to sync and monitor with:

```console
sudo journalctl -fu geth.service -o cat
```
Monitoring of the sync process **which must be complete before proceeding** can also be performed with the following commmands and looking for a return value of `false`. Anything else means syncing is still in progress
```console
geth attach http://127.0.0.1:8545
> eth.syncing
```

### Install Besu
Download the [latest](https://github.com/hyperledger/besu/releases) version of Besu and extract:
```console
cd ~
wget https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/22.7.0/besu-22.7.0.tar.gz
tar xvf besu-22.7.0.tar.gz
rm besu-22.7.0.tar.gz
sudo cp -a ./besu-22.7.0 /usr/local/bin/besu
rm -rf ./besu-22.7.0
```
Create a user for besu:
```console
sudo useradd --no-create-home --shell /bin/false besu
sudo mkdir -p /var/lib/besu
sudo chown -R besu:besu /var/lib/besu
```
Create the Besu configuration:
```
sudo nano /etc/systemd/system/besu.service
```
Add the following to the `besu.service` definition:
```properties
[Unit]
Description=Besu Ethereum Client
After=network.target
Wants=network.target

[Service]
User=besu
Group=besu
Type=simple
Restart=always
RestartSec=5
ExecStart=/usr/local/bin/besu/bin/besu \
    --network=goerli \
    --sync-mode=X_CHECKPOINT \
    --rpc-http-enabled=true \
    --engine-rpc-port=8551 \
    --engine-host-allowlist=localhost,127.0.0.1 \
    --data-path=/var/lib/besu \
    --data-storage-format=BONSAI \
    --metrics-enabled=true \
    --engine-jwt-secret=/var/lib/ethereum/jwttoken

[Install]
WantedBy=default.target
```
Re/Start Besu:
```console
sudo systemctl daemon-reload
sudo systemctl start besu.service
```
Check the status. There should be a green `active` in the output:
```console
sudo systemctl status besu.service
```
Enable the service:
```console
sudo systemctl enable besu.service
```
Monitor Beacon Chain syncing progress, peers, and other information:
```console
sudo journalctl -fu besu.service -o cat
```

### Install Teku
```console
cd ~
git clone https://github.com/Consensys/teku.git
cd teku
sudo ./gradlew installDist
cd ~
sudo cp -a teku/build/install/teku/. /usr/local/bin/teku
sudo useradd --no-create-home --shell /bin/false teku
sudo mkdir -p /var/lib/teku
sudo mkdir -p /etc/teku
sudo chown $(whoami):$(whoami) /var/lib/teku
```
#### Generate and Handle Validator Keys - External to this guide

1. [Generate Validator keys and deposit files](https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-testnet-prater#2.-signup-to-be-a-validator-at-the-launchpad) - Steps 1 and 2 OR you can skip all the hard stuff and use the [Wagyu](https://wagyu.gg/) GUI. No matter what process you pick, please generate these validator keys on a secure machine.
2. Create password files for validator keys:
	- Copy every `keystore-m*.json` file and rename the copies to have `.txt` as the file extension
	- Open each file and replace all contents with the keystore password created in Step 1.
3. Use an SFTP program or a USB key to move files to the NUC in your home folder

Move validator keys from your home folder to Teku:
```console
sudo cp -r $HOME/validator_keys /var/lib/teku
sudo rm /var/lib/teku/validator_keys/deposit_data*
```

Set permissions for keys:
```console
sudo chown -R teku:teku /var/lib/teku
sudo chown -R teku:teku /etc/teku
sudo chmod -R 700 /var/lib/teku/validator_keys
```

#### Configure Teku
👉 You will need to sign up for a free Infura (https://www.infura.io) account and create a new ETH1 project and a new ETH2 project.

Create the Teku configuration:
```console
sudo nano /etc/teku/teku.yaml
```
Add the following to `teku.yaml`:
```yaml
# EXAMPLE FILE - DO NOT CUT AND PASTE WITHOUT CHANGES
data-base-path: "/var/lib/teku"
network: "prater"
# if a backup ETH1 node is desired, replace the endpoint with your information from Infura
eth1-endpoint: ["http://127.0.0.1:8545/", "https://goerli.infura.io/v3/XXX"]
# if quick-sync is desired, replace the state URL with your information from Infura
initial-state: "https://XXX:XXX@eth2-beacon-prater.infura.io/eth/v1/debug/beacon/states/finalized"
validator-keys: "/var/lib/teku/validator_keys:/var/lib/teku/validator_keys"
# change this to your Ethereum withdrawal address (or any other address you'd like proposal fees to go
validators-proposer-default-fee-recipient: "0x..."
validators-graffiti: "XXX"
# optionally use a file for graffiti, but make sure it is world-readable
# validators-graffiti-file: "/home/USERDIR/graffiti.txt"
p2p-port: 9000
p2p-peer-upper-bound: 100
log-destination: "CONSOLE"
metrics-enabled: true
metrics-port: 8008
# if you are using beaconcha.in to monitor your machine, include the appropriate URL below
metrics-publish-endpoint: "https://beaconcha.in/api/v1/client/metrics?apikey=APIKEY&machine=MACHINENAME"
# replace hostname with the name of your staking machine
rest-api-host-allowlist: ["localhost", "127.0.0.1", "hostname"]
rest-api-enabled: true
rest-api-docs-enabled: true
ee-jwt-secret-file: "/var/lib/ethereum/jwttoken"
```
Create the Teku service definition:
```console
sudo nano /etc/systemd/system/teku.service
```
Add the following to `teku.service`:
```properties
[Unit]
Description=Teku Client
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=teku
Group=teku
Restart=always
RestartSec=5
Environment="JAVA_OPTS=-Xmx5g"
ExecStart=/usr/local/bin/teku/bin/teku --config-file=/etc/teku/teku.yaml

[Install]
WantedBy=multi-user.target
```
Re/Start Teku:
```console
sudo systemctl daemon-reload
sudo systemctl start teku
```
Check the status. There should be a green `active` in the output:
```console
sudo systemctl status teku
```
Enable the service:
```console
sudo systemctl enable teku
```
Monitor Beacon Chain syncing progress, peers, and other information:
```console
sudo journalctl -fu teku.service -o cat
```
**Teku needs to sync to the Beacon Chain before proceeding with the funding of validators.**

If an `initial-state` is set in the `teku.yaml` configuration file, syncing should happen very rapidly.

### Monitoring
https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet/monitoring-your-validator-with-grafana-and-prometheus#6.2-setting-up-grafana-dashboards

### Fund Validator Keys
This is an external process describe in various referenced guides. Please follow directions at https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-testnet-prater#2.-signup-to-be-a-validator-at-the-launchpad, steps 3-6.

Watch [prater.beachoncha.in](https://prater.beachoncha.in) and wait for deposits to clear.

### You’re done! 🎉

## Maintenance
The staking machine requires regular _manual_ maintanence.

### Geth Pruning
https://gist.github.com/yorickdowne/3323759b4cbf2022e191ab058a4276b2

### Geth Updates
https://github.com/ethereum/go-ethereum/releases  
Just in case, update the installed geth package to make sure it sees the latest stable version:
```console
sudo apt update
```
Now, update geth!
```console
sudo apt upgrade -y
sudo apt autoremove
sudo apt autoclean
```
Restart geth:
```console
sudo systemctl restart geth
```
Make sure geth is ok (should see a green "active" message):
```console
sudo systemctl status geth
```

### Teku Updates
#### Review release notes and check for breaking changes/features.
https://github.com/ConsenSys/teku/releases  
Pull the latest source and build it.
```console
cd ~/teku
git pull
./gradlew distTar installDist
```
Verify the build completed by checking the new version number.
```console
cd ~/teku/build/install/teku/bin
./teku --version
```
Restart beacon chain and validator as per normal operating procedures.  
**Make sure the validators are in an acceptable state to be stopped before proceeding**[^status]
```console
cd ~
sudo systemctl stop teku
sudo cp -a teku/build/install/teku/. /usr/local/bin/teku
sudo systemctl start teku
```
### System Updates
**Make sure the validators are in an acceptable state to be stopped before proceeding**[^status]
```console
sudo apt update -y && sudo apt upgrade -y
sudo apt autoremove
sudo apt autoclean
```
A reboot may be necessary: `sudo reboot`

[^turboboost]: TurboBoost seems unnecessary and will make your NUC run hot and loud.

[^status]: Install [ethdo](https://github.com/wealdtech/ethdo) and then use the [status script](https://github.com/EvilJordan/eth2-staking-guide/blob/main/status.sh) to make sure timing is ok for a restart or update.
