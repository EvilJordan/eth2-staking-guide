# ETH2 Staking Guide - PRATER/TEKU/GETH

Set bios to power-on on power restore (hold F2 during power-on to enter BIOS)

Install Ubuntu from USB: https://ubuntu.com/download/server

Will need SFTP and SSH clients for remote administration.

This guide built with a combination of:
- https://www.coincashew.com/coins/overview-eth/guide-or-security-best-practices-for-a-eth2-validator-beaconchain-node
- https://someresat.medium.com/guide-to-staking-on-ethereum-2-0-ubuntu-prater-teku-3249f1922385
- https://docs.teku.consensys.net/en/stable/
- https://ethereum.org/en/eth2/staking/

Open remote port on router for SSH access (optional), p2p, and eth1

SSH into server and install lolcat (optional):
```properties
git clone https://github.com/jaseg/lolcat.git
cd lolcat
sudo apt install make
sudo apt install gcc
make
sudo make install
rm -rf lolcat
```

SFTP into server and replace bash files and authorized_keys (optional)

Update server: https://www.coincashew.com/coins/overview-eth/guide-or-security-best-practices-for-a-eth2-validator-beaconchain-node#update-your-system
```properties
sudo apt-get update -y && sudo apt dist-upgrade -y
sudo apt-get autoremove
sudo apt-get autoclean
```

Enable automatic upgrades: https://www.coincashew.com/coins/overview-eth/guide-or-security-best-practices-for-a-eth2-validator-beaconchain-node#update-your-system
```properties
sudo apt-get install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

Install apcupsd (optional for UPS backups - requires USB cable):
```properties
sudo apt-get install apcupsd
sudo nano /etc/apcupsd/apcupsd.conf
	Edit name and device
sudo reboot
```

SSH Lockdown: https://www.coincashew.com/coins/overview-eth/guide-or-security-best-practices-for-a-eth2-validator-beaconchain-node#disable-ssh-password-authentication-and-use-ssh-keys-only
```properties
sudo nano /etc/ssh/sshd_config
	ChallengeResponseAuthentication no
	PasswordAuthentication no
	PermitRootLogin prohibit-password
	PermitEmptyPasswords no
sudo sshd -t
```

Disable root account: https://www.coincashew.com/coins/overview-eth/guide-or-security-best-practices-for-a-eth2-validator-beaconchain-node#disable-root-account
```properties
sudo passwd -l root
```

Secure Shared Memory: https://www.coincashew.com/coins/overview-eth/guide-or-security-best-practices-for-a-eth2-validator-beaconchain-node#secure-shared-memory
```properties
sudo nano /etc/fstab
	tmpfs	/run/shm	tmpfs	ro,noexec,nosuid	0	0
sudo reboot
```

Install Fail2Ban: https://www.coincashew.com/coins/overview-eth/guide-or-security-best-practices-for-a-eth2-validator-beaconchain-node#install-fail2ban
```properties
sudo apt-get install fail2ban -y
sudo nano /etc/fail2ban/jail.local
	[sshd]
	enabled = true
	port = 22
	filter = sshd
	logpath = /var/log/auth.log
	maxretry = 3
	ignoreip = 127.0.0.0/8 10.0.0.0/8 192.168.0.0/16
sudo systemctl restart fail2ban
```

Firewall:
```bash
# By default, deny all incoming and outgoing traffic
sudo ufw default deny incoming
sudo ufw default allow outgoing
# Allow ssh access
sudo ufw allow ssh #22/tcp
# Allow p2p ports
sudo ufw allow 9000/tcp comment p2p
sudo ufw allow 9000/udp comment p2p
# Allow eth1 port
sudo ufw allow 30303/tcp comment eth1
sudo ufw allow 30303/udp comment eth1
# Allow grafana web server port
sudo ufw allow 3000/tcp comment grafana
# Enable prometheus endpoint port
sudo ufw allow 9090/tcp comment prometheus
# Enable teku api
sudo ufw allow 5051 comment teku-rest-api
# Enable firewall
sudo ufw enable
```
Fix SSD Storage:
```properties
sudo lvdisplay #
sudo lvm
> lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
> lvextend -l +100%FREE -r /dev/ubuntu-vg/ubuntu-lv
> exit
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv
df -h #
sudo lvdisplay #
```

SSH 2FA (optional): https://www.coincashew.com/coins/overview-eth/guide-or-security-best-practices-for-a-eth2-validator-beaconchain-node#setup-two-factor-authentication-for-ssh-optional and https://www.digitalocean.com/community/tutorials/how-to-set-up-multi-factor-authentication-for-ssh-on-ubuntu-18-04

This is Two-Factor Authentication for use with an app like Google Authenticator or Authy for an added layer of security to access the machine. The first layer, is, of course, SSH keys – a process not explained in this guide.
```properties
sudo apt install libpam-google-authenticator -y
sudo nano /etc/pam.d/sshd
	Add:
		auth required pam_google_authenticator.so
	Comment out the below line by adding # in front of it:
		@include common-auth
sudo systemctl restart sshd.service
sudo nano /etc/ssh/sshd_config
	Set:
		ChallengeResponseAuthentication yes
		UsePAM yes
	Add:
		AuthenticationMethods publickey,password publickey,keyboard-interactive
google-authenticator
	Answers: yes, yes, no, yes
sudo systemctl restart sshd.service
exit
```
Log back in to server via SSH to see 2FA in action.

Install Prometheus/Grafana/Eth1/Teku: https://someresat.medium.com/guide-to-staking-on-ethereum-2-0-ubuntu-prater-teku-3249f1922385


Install Prometheus (Modify prometheus to scrape at 3s [optional]):
```properties
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
sudo nano /etc/prometheus/prometheus.yml
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
sudo chown -R prometheus:prometheus /etc/prometheus/prometheus.yml
sudo nano /etc/systemd/system/prometheus.service
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
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl status prometheus
sudo systemctl enable prometheus
```
Install Node Exporter:
```properties
cd ~
curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz
tar xvf node_exporter-1.3.1.linux-amd64.tar.gz
sudo cp node_exporter-1.3.1.linux-amd64/node_exporter /usr/local/bin
sudo chown -R node_exporter:node_exporter /usr/local/bin/node_exporter
rm -rf node_exporter-1.3.1.linux-amd64
rm node_exporter-1.3.1.linux-amd64.tar.gz
sudo nano /etc/systemd/system/node_exporter.service
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
sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl status node_exporter
sudo systemctl enable node_exporter
```

Install Grafana:
```properties
curl -s -0 https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
sudo apt update
sudo apt install grafana
sudo systemctl start grafana-server
sudo systemctl status grafana-server
sudo systemctl enable grafana-server
```

Modify Grafana.ini to allow higher rate:
```properties
sudo nano /etc/grafana/grafana.ini
;min_refresh_interval = 1s
sudo systemctl restart grafana-server
```
Install json-exporter to obtain ethusd in Grafana (optional)

Install GETH
```properties
sudo add-apt-repository -y ppa:ethereum/ethereum
sudo apt update
sudo apt install geth
sudo useradd --no-create-home --shell /bin/false goeth
sudo mkdir -p /var/lib/goethereum
sudo chown -R goeth:goeth /var/lib/goethereum
sudo nano /etc/systemd/system/geth.service
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
sudo systemctl daemon-reload
sudo systemctl start geth
sudo systemctl enable geth
```
Wait for Geth to sync and monitor with:

```properties
sudo journalctl -fu geth.service
```

Install Teku:
```properties
sudo apt install default-jre default-jdk
cd ~
git clone https://github.com/Consensys/teku.git
cd teku
sudo ./gradlew installDist
cd ~
sudo cp -a teku/build/install/teku/. /usr/local/bin/teku
sudo useradd --no-create-home --shell /bin/false teku
```

Generate and Handle Validator Keys - External to this guide
```properties
directory location: /var/lib/teku/validator_keys
sudo chown -R teku:teku /var/lib/teku
sudo chown -R teku:teku /etc/teku
sudo chmod -R 700 /var/lib/teku/validator_keys
```

Configure Teku:

👉 You will need to sign up for a free Infura (https://www.infura.io) account and create a new ETH1 project and a new ETH2 project.
```properties
sudo nano /etc/teku/teku.yaml
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
sudo nano /etc/systemd/system/teku.service
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
sudo systemctl daemon-reload
sudo systemctl start teku
sudo systemctl status teku
sudo systemctl enable teku
sudo journalctl -fu teku.service
```

Fund Validator Keys

Watch prater.beachoncha.in and wait

You’re done!
