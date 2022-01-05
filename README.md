# ETH2 Staking Guide - PRATER/TEKU/GETH

This guide built with a combination of:
- https://www.coincashew.com/coins/overview-eth/guide-or-security-best-practices-for-a-eth2-validator-beaconchain-node
- https://someresat.medium.com/guide-to-staking-on-ethereum-2-0-ubuntu-prater-teku-3249f1922385
- https://docs.teku.consensys.net/en/stable/
- https://ethereum.org/en/eth2/staking/

## Prerequisites
- Set bios to power-on on power restore (hold F2 during power-on to enter BIOS)
- Install Ubuntu from USB: https://ubuntu.com/download/server
- SFTP and SSH clients for remote administration.
- Additional USB to transfer files from key-generating machine to staking machine if not using local network

## Set up Router
- Assign a static IP to your staking machine.
- Open ports on router for SSH access (default port 22) (optional if not managing locally), p2p (9000), and eth1 (30303)

## Set up Staking Machine
### SSH into server and install lolcat (optional)
This is personal thing, – no one else needs this.
```console
git clone https://github.com/jaseg/lolcat.git
cd lolcat
sudo apt install make
sudo apt install gcc
make
sudo make install
rm -rf lolcat
```
SFTP into server and replace bash files and authorized_keys (optional)

### Update server
```console
sudo apt-get update -y && sudo apt dist-upgrade -y
sudo apt-get autoremove
sudo apt-get autoclean
```

### Enable automatic upgrades
```console
sudo apt-get install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### Install apcupsd (optional for UPS backups - requires USB cable):
```console
sudo apt-get install apcupsd
sudo nano /etc/apcupsd/apcupsd.conf
```
Edit name and device in `apceupsd.conf`:

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
Confirm `sshd`'s configuration is error-free:
```console
sudo sshd -t
```

### Disable root account
```console
sudo passwd -l root
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
> lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
> lvextend -l +100%FREE -r /dev/ubuntu-vg/ubuntu-lv
> exit
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
```
Check new configuration:
```console
df -h #
sudo lvdisplay #
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
AuthenticationMethods publickey,password publickey,keyboard-interactive
```
Confirm `sshd`'s configuration is error-free:
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

## Install Prometheus/Grafana/Eth1/Teku
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
Make sure the `prometheus.yml` file includes this configuration.

Optionally, change `scrape_interval: 3s` and `scape_timeout: 2s` for faster metrics updating at the expense of CPU load.
```properties
global:
	scrape_interval: 15s
scrape_configs:
	- job_name: "prometheus"
		static_configs:
		- targets: ["localhost:9090"]
	- job_name: "node_exporter"
		static_configs:
		- targets: ["localhost:9100"]
	- job_name: "teku"
		scrape_timeout: 10s
		metrics_path: /metrics
		scheme: http
		static_configs:
		- targets: ["localhost:8008"]
	- job_name: json_exporter
		static_configs:
		- targets:
		- 127.0.0.1:7979
	- job_name: json
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
sudo systemctl status prometheus
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
sudo systemctl status node_exporter
sudo systemctl enable node_exporter
```

### Install json_exporter
#### Install go:
```console
sudo apt-get install golang-1.14-go
# Create a symlink from /usr/bin/go to the new go installation:
sudo ln -s /usr/lib/go-1.14/bin/go /usr/bin/go
```
#### Create User Account
```console
sudo adduser --system json_exporter --group --no-create-home
```
#### Install json_exporter
```console
cd
git clone https://github.com/prometheus-community/json_exporter.git
cd json_exporter
make build
sudo cp json_exporter /usr/local/bin/
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
```propeties
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
sudo systemctl enable json_exporter.service
```

### Install Grafana:
```console
curl -s -0 https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
sudo apt update
sudo apt install grafana
sudo systemctl start grafana-server
sudo systemctl status grafana-server
sudo systemctl enable grafana-server
```

#### Modify Grafana.ini to allow higher rate:
```console
sudo nano /etc/grafana/grafana.ini
;min_refresh_interval = 1s
sudo systemctl restart grafana-server
```

### Install GETH
```console
sudo add-apt-repository -y ppa:ethereum/ethereum
sudo apt update
sudo apt install geth
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
ExecStart=geth --goerli --http --datadir /var/lib/goethereum
[Install]
WantedBy=default.target
```
Reload geth:
```console
sudo systemctl daemon-reload
sudo systemctl start geth
sudo systemctl enable geth
```
Wait for Geth to sync and monitor with:

```console
sudo journalctl -fu geth.service
```
Monitoring of the sync process **which must be complete before proceeding** can also be performed with:
```console
geth attach http://127.0.0.1:8545
> eth.syncing
```
And looking for a return value of `false`

### Install Teku:
```console
sudo apt install default-jre default-jdk
cd ~
git clone https://github.com/Consensys/teku.git
cd teku
sudo ./gradlew installDist
cd ~
sudo cp -a teku/build/install/teku/. /usr/local/bin/teku
sudo useradd --no-create-home --shell /bin/false teku
```
#### Generate and Handle Validator Keys - External to this guide
```console
directory location: /var/lib/teku/validator_keys
sudo chown -R teku:teku /var/lib/teku
sudo chown -R teku:teku /etc/teku
sudo chmod -R 700 /var/lib/teku/validator_keys
```

#### Configure Teku:
👉 You will need to sign up for a free Infura (https://www.infura.io) account and create a new ETH1 project and a new ETH2 project.
```console
sudo nano /etc/teku/teku.yaml
```
Add the following to `teku.yaml`:
```properties
# EXAMPLE FILE
data-base-path: "/var/lib/teku"
network: "prater"
eth1-endpoint: ["http://127.0.0.1:8545/", "https://goerli.infura.io/v3/XXX"]
initial-state: "https://XXX:XXX@eth2-beacon-prater.infura.io/eth/v1/debug/beacon/states/finalized"
validator-keys: "/var/lib/teku/validator_keys:/var/lib/teku/validator_keys"
validators-graffiti: "XXX"
p2p-port: 9000
p2p-peer-upper-bound: 100
log-destination: "CONSOLE"
metrics-enabled: true
metrics-port: 8008
rest-api-host-allowlist: ["hostname"]
rest-api-enabled: true
rest-api-docs-enabled: true
```
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
```console
sudo systemctl daemon-reload
sudo systemctl start teku
sudo systemctl status teku
sudo systemctl enable teku
sudo journalctl -fu teku.service
```

## Fund Validator Keys

### Watch prater.beachoncha.in and wait

## You’re done!
