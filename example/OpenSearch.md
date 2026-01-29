- ### Setup
	- In diesem Beispiel richten Sie den System-Hostnamen mit **os-node-1** und den fqdn **os-node-1.hq.stgt.etes.de** ein. Stellen Sie außerdem sicher, dass Sie die IP-Adresse im folgenden Befehl durch die IP-Adresse Ihres Servers ersetzen.
	-
	  ```bash
	  sudo hostnamectl set-hostname os-node-1
	  echo '172.16.42.178  os-node-1.hq.stgt.etes.de  os-node-1' >> /etc/hosts
	  ```
	- Melden Sie sich von Ihrer aktuellen Sitzung ab und melden Sie sich erneut an. Überprüfen Sie dann fqdn mit dem unten stehenden Befehl.
	-
	  ```bash
	  sudo hostname -f
	  ```
	- Als nächstes müssen Sie Memory Paging und SWAP auf Ihrem Rocky Linux-Host deaktivieren. Die Deaktivierung von Memory Paging und SWAP wird die Leistung Ihres OpenSearch-Servers erhöhen.
	    
	  Geben Sie den folgenden Befehl ein, um SWAP auf Ihrem System zu deaktivieren. Der erste Befehl deaktiviert SWAP dauerhaft, indem er die SWAP-Konfiguration in der Datei '/etc/fstab' auskommentiert. Das zweite Kommando wird verwendet, um SWAP für die aktuelle Sitzung zu deaktivieren.  
	-
	  ```bash
	  sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
	  sudo swapoff -a
	  ```
	- Überprüfen Sie den Status von SWAP auf Ihrem System mit dem folgenden Befehl.
	-
	  ```bash
	  free -m
	  ```
	- Zu guter Letzt müssen Sie den max maps memory auf Ihrem System für OpenSearch erhöhen. Dies kann über die Datei „/etc/sysctl.conf“ erfolgen.
	    
	  Geben Sie den folgenden Befehl ein, um den max maps memory auf „262144“ zu erhöhen, und übernehmen Sie die Änderungen. Damit fügen Sie eine neue Konfiguration „vm.max_map_count=262144“ zur Datei „/etc/sysctl.conf“ hinzu und wenden die Änderungen auf Ihrem System mit dem Befehl „sysctl -p“ an.  
	-
	  ```bash
	  sudo echo "vm.max_map_count=262144" >> /etc/sysctl.conf
	  sudo sysctl -p
	  ```
	- Mit dem folgendem befehl können Sie überprüfen ob die Änderung korrekt übernommen wurde:
	-
	  ```bash
	  cat /proc/sys/vm/max_map_count
	  ```
- ## OpenSearch installieren
	- Geben Sie den unten stehenden curl-Befehl ein, um das OpenSearch-Repository auf Ihr System herunterzuladen. Überprüfen Sie dann die Liste der verfügbaren Repositories mit dem unten stehenden Befehl.
	-
	  ```bash
	  sudo curl -SL https://artifacts.opensearch.org/releases/bundle/opensearch/2.x/opensearch-2.x.repo -o /etc/yum.repos.d/opensearch-2.x.repo
	  sudo dnf repolist
	  ```
	- Sie können auch die verfügbaren Pakete von 'opensearch' überprüfen, indem Sie den folgenden Befehl eingeben.
	-
	  ```bash
	  sudo dnf info opensearch
	  sudo dnf info opensearch-dashboards
	  ```
	- Rufen Sie das folgende dnf-Kommando auf, um OpenSearch auf Ihrem Rocky-Linux-Server zu installieren. Wenn Sie zur Bestätigung aufgefordert werden, geben Sie y zur Bestätigung ein und drücken Sie ENTER, um fortzufahren.
	-
	  ```bash
	  sudo dnf install opensearch
	  ```
	- Sobald OpenSearch erfolgreich installiert ist, laden Sie den systemd manager neu und wenden Sie die neuen Änderungen mit dem unten stehenden systemctl-Befehl an.
	-
	  ```bash
	  sudo systemctl daemon-reload
	  ```
	- Starten und aktivieren Sie nun OpenSearch mit dem unten stehenden Befehl. Damit sollte die OpenSearch mit den Standardkonfigurationen laufen und sie ist auch aktiviert, was bedeutet, dass die OpenSearch beim Systemstart automatisch startet.
	-
	  ```bash
	  sudo systemctl start opensearch
	  sudo systemctl enable opensearch
	  ```
	- Um sicherzustellen, dass OpenSearch funktioniert und läuft, können Sie dies mit dem folgenden systemctl-Befehl überprüfen.
	-
	  ```bash
	  sudo systemctl status opensearch
	  ```
- ### OpenSearch konfigurieren
	- Standardmäßig werden OpenSearch-Konfigurationen im Verzeichnis „/etc/opensearch“ gespeichert. In diesem Schritt führen Sie die Grundkonfiguration von OpenSearch im Single-Node-Modus durch. Sie werden auch den maximalen Heap-Speicher auf Ihrem System erhöhen, um eine bessere Leistung des OpenSearch-Servers zu erreichen.
	- Öffnen Sie die OpenSearch-Konfigurationsdatei '/etc/opensearch/opensearch.yml' mit dem unten stehenden vim-Editor-Befehl.
	-
	  ```bash
	  sudo vim /etc/opensearch/opensearch.yml
	  ```
	- Passen Sie die Standardparameter von OpenSearch mit den folgenden Zeilen an, um OpenSearch in einem bestimmten Netzwerk mit der IP-Adresse „172.16.42.178“ im Deployment-Typ „single-node“ auszuführen.
	-
	  ```yml
	  # Bind OpenSearch to the correct network interface. Use 0.0.0.0
	  # to include all available interfaces or specify an IP address
	  # assigned to a specific interface.
	  network.host: 172.16.42.178
	  
	  # Unless you have already configured a cluster, you should set
	  # discovery.type to single-node, or the bootstrap checks will
	  # fail when you try to start the service.
	  discovery.type: single-node
	  
	  # If you previously disabled the security plugin in opensearch.yml,
	  # be sure to re-enable it. Otherwise you can skip this setting.
	  plugins.security.disabled: false
	  ```
	- Speichern und schließen Sie die Datei „/etc/opensearch/opensearch.yml“, wenn Sie fertig sind.
	- Als nächstes öffnen Sie die Standard-JVM-Optionen-Datei für OpenSearch '/etc/opensearch/jvm.options' mit dem folgenden vim-Editor-Befehl.
	-
	  ```bash
	  sudo vim /etc/opensearch/jvm.options
	  ```
	- Passen Sie den standardmäßigen maximalen Heap-Speicher mit den folgenden Zeilen an. Die Größe hängt vom verfügbaren Arbeitsspeicher Ihres Servers ab. Bei ausreichendem RAM können Sie OpenSearch mehr als 2 GB zuweisen. Es wird empfohlen, etwa 50 % des maximalen Arbeitsspeichers zu nutzen.
	-
	  ```
	  -Xms2g
	  -Xmx2g
	  ```
	- Führen Sie abschließend das folgende systemctl-Befehlsprogramm aus, um den OpenSearch-Dienst neu zu starten und die Änderungen zu übernehmen.
	-
	  ```bash
	  sudo systemctl restart opensearch
	  ```
	-
- ### Absicherung von OpenSearch mit TLS-Zertifikaten
	- In diesem Schritt werden Sie mehrere Zertifikate generieren, die zur Sicherung der OpenSearch-Bereitstellung verwendet werden. Sie werden die Node-zu-Node-Kommunikation mit TLS-Zertifikaten und den REST-layer-traffic zwischen Client und Server über TLS sichern.
	- Im Folgenden finden Sie eine Liste der Zertifikate, die generiert werden sollen:
	- 1. Root-CA-Zertifikate: Diese Zertifikate werden zum Signieren anderer Zertifikate verwendet.
	- 2. Admin-Zertifikate: Diese Zertifikate werden verwendet, um administrative Rechte zu erhalten und alle Aufgaben im Zusammenhang mit dem Sicherheits-Plugin durchzuführen.
	- 3. Node- und Client-Zertifikate: Diese Zertifikate werden von Nodes und Clients innerhalb des OpenSearch-Clusters verwendet.
	-
---
	- Bevor wir neue TLS-Zertifikate erzeugen, müssen wir einige Standardzertifikate und Standardkonfigurationen von OpenSearch entfernen.
	- Führen Sie das folgende Kommando aus, um die Standard-OpenSearch-TLS-Zertifikate zu entfernen. Öffnen Sie dann die OpenSearch-Konfiguration „/etc/opensearch/opensearch.yml“ mit dem folgenden Vim-Editor-Befehl und kommentieren Sie unten in der Zeile die Standardkonfiguration für die OpenSearch Security Demo aus.
	-
	  ```bash
	  rm -f /etc/opensearch/{esnode-key.pem,esnode.pem,kirk-key.pem,kirk.pem,root-ca.pem}
	  sudo vim /etc/opensearch/opensearch.yml
	  ```
	- ![delete demo certs](https://www.howtoforge.com/images/how_to_install_opensearch_on_rocky_linux_9/22-delete-demo-certs.png?ezimgfmt=rs:750x421/rscb10/ngcb9/notWebP)
	- Geben Sie als nächstes den folgenden Befehl ein, um ein neues Verzeichnis „/etc/opensearch/certs“ zu erstellen. In diesem Verzeichnis werden die neu erzeugten TLS-Zertifikate gespeichert.
	-
	  ```bash
	  mkdir -p /etc/opensearch/certs; cd /etc/opensearch/certs
	  ```
- ### Erzeugen von Root-CA-Zertifikaten
	- Erzeugen Sie einen privaten Schlüssel für die Root-CA-Zertifikate wie folgt.
	-
	  ```bash
	  openssl genrsa -out root-ca-key.pem 2048
	  ```
	- Erzeugen Sie nun ein selbstsigniertes Root-CA-Zertifikat mit dem unten stehenden Befehl. Sie können auch die Werte des Parameters „-subj“ nach Ihren Wünschen ändern.
	-
	  ```bash
	  openssl req -new -x509 -sha256 -key root-ca-key.pem -subj "/C=DE/ST=BW/L=STUTTGART/O=ETES/OU=INF/CN=ROOT" -out root-ca.pem -days 730
	  ```
	-
---
	- #### Admin Zertifikate generieren
	- Erzeugen Sie den neuen privaten Schlüssel des Admin-Zertifikats „admin-key-temp.pem“ mit dem folgenden Befehl.
	  ```bash
	  openssl genrsa -out admin-key-temp.pem 2048
	  ```
	- Konvertieren Sie den standardmäßigen privaten Schlüssel des Administrators in das PKCS#8-Format. Für die Java-Anwendung müssen Sie den standardmäßigen privaten Schlüssel in einen PKCS#12-kompatiblen Algorithmus (3DES) umwandeln. Damit sollte Ihr privater Administratorschlüssel „admin-key.pem“ heißen.
	-
	  ```bash
	  openssl pkcs8 -inform PEM -outform PEM -in admin-key-temp.pem -topk8 -nocrypt -v1 PBE-SHA1-3DES -out admin-key.pem
	  ```
	- Führen Sie als Nächstes den folgenden Befehl aus, um die CSR (Certificate Signing Request) aus dem privaten Schlüssel „admin-key.pem“ zu erzeugen. Ihre generierte CSR sollte nun die Datei „admin.csr“ sein.
	    
	  Da dieses Zertifikat für die Authentifizierung des erweiterten Zugriffs verwendet wird und nicht an einen Host gebunden ist, können Sie in der „CN“-Konfiguration alles verwenden.  
	-
	  ```bash
	  openssl req -new -key admin-key.pem -subj "/C=DE/ST=BW/L=STUTTGART/O=ETES/OU=INF/CN=A" -out admin.csr
	  ```
	- Führen Sie schließlich den folgenden Befehl aus, um die Admin-CSR mit dem Root-CA-Zertifikat und dem privaten Schlüssel zu signieren. Die Ausgabe des Admin-Zertifikats ist die Datei `admin.pem“`.
	-
	  ```bash
	  openssl x509 -req -in admin.csr -CA root-ca.pem -CAkey root-ca-key.pem -CAcreateserial -sha256 -out admin.pem -days 730
	  ```
	- Ihre Admin-Zertifikat sollte nun als **admin.pem**-Datei vorhanden sein und ist von den Root-CA-Zertifikaten signiert worden.
	  Der entsprechende Admin-Privat-Schlüssel trägt den Namen **admin-key.pem** und wurde in das `PKCS#8-Format` konvertiert.  
- ### Node Zertifikate generieren
	- Der Vorgang des Erstellens von Knotenzertifikaten ist ähnlich wie bei Admin-Zertifikaten. Beim Erstellen können Sie jedoch den Common Name (CN)-Wert mit dem Hostname oder der IP-Adresse Ihres Knotens festlegen.
	  Erstellen Sie den privaten Knoten-Schlüssel mit dem folgenden Befehl:  
	-
	  ```bash
	  openssl genrsa -out os-node-1-key-temp.pem 2048
	  ```
	- Konvertieren Sie den privaten Knotenschlüssel in das `PKCS#8-Format`. Ihr privater Knotenschlüssel sollte jetzt *os-node-1-key.pem* sein.
	-
	  ```bash
	  openssl pkcs8 -inform PEM -outform PEM -in os-node-1-key-temp.pem -topk8 -nocrypt -v1 PBE-SHA1-3DES -out os-node-1-key.pem
	  ```
	- Als nächstes erstellen Sie eine neue Zertifikatsanforderung (CSR) für 
	  das Knotenzertifikat. Stellen Sie sicher, dass Sie den Wert von '**CN**' mit dem Hostnamen Ihres Knotens ändern. Dieses Zertifikat ist an Hosts gebunden und Sie müssen den CN-Wert mit dem Hostnamen oder der IP-Adresse Ihres OpenSearch-Knotens angeben.  
	-
	  ```bash
	  openssl req -new -key os-node-1-key.pem -subj "/C=DE/ST=BW/L=STUTTGART/O=ETES/OU=INF/CN=os-node-1.hq.stgt.etes.de" -out os-node-1.csr
	  ```
	- Bevor Sie das Knotenzertifikat signieren, führen Sie den folgenden Befehl aus, um eine Erweiterungsdatei 'node-rock1.ext ' für Subject Alternative Name (SAN) zu erstellen. Diese Datei wird den Hostnamen oder den vollständig qualifizierten Domain-Namen (FQDN) oder die IP-Adresse des Knotens enthalten:
	-
	  ```bash
	  echo "subjectAltName=IP:172.16.42.178" > os-node-1.ext
	  ```
	- Signieren Sie schließlich die CSR-Datei des Knotenzertifikats mit dem Root-CA-Zertifikat und dem privaten Zertifikat mit dem folgenden Befehl.
	-
	  ```bash
	  openssl x509 -req -in os-node-1.csr -CA root-ca.pem -CAkey root-ca-key.pem -CAcreateserial -sha256 -out os-node-1.pem -days 730 -extfile os-node-1.ext
	  ```
- ### Zertifikate einrichten
	- Führen Sie den folgenden Befehl aus, um die temporären Zertifikatsanforderung (CSR) und die `.ext`-Datei mit der Subject Alternative Name (SAN)-Erweiterung zu entfernen:
	-
	  ```bash
	  rm *temp.pem *csr *ext
	  ls
	  ```
	- Das root CA Zertifikat wird in das .crt format konvertiert:
	-
	  ```bash
	  openssl x509 -outform der -in root-ca.pem -out root-ca.crt
	  ```
	- Fügen Sie das Root-CA-Zertifikat mit dem folgenden Befehl zu Ihrem Rocky-Linux-System hinzu.
	  Danach führen Sie den Befehl `update-ca-trust` aus, um die Vertrauensliste zu aktualisieren und das neue Root-CA-Zertifikat in Ihr System zu laden.  
	-
	  ```bash
	  sudo cp root-ca.crt /etc/pki/ca-trust/source/anchors/
	  sudo update-ca-trust
	  ```
	- Schließlich führen Sie den folgenden Befehl aus, um die Berechtigungen und Eigentümer Ihrer Zertifikate einzurichten. Das Verzeichnis '/etc/opensearch/certs' sollte dem Benutzer 'opensearch' mit der Berechtigung **0700** gehören. Und für alle Zertifikatsdateien sollten die Berechtigungen **0600** betragen.
	-
	  ```bash
	  sudo chown -R opensearch:opensearch /etc/opensearch/certs
	  sudo chmod 0700 /etc/opensearch/certs
	  ```
	-
	  ```bash
	  sudo chmod 0600 /etc/opensearch/certs/*.pem
	  sudo chmod 0600 /etc/opensearch/certs/*.crt
	  ```
- ### Zertifikate zu Openseach hinzugefügen
	- Nachdem Sie die TLS-Zertifikate generiert haben, besitzen Sie das Root CA-, Admin- und Node-Zertifikat. Als nächstes werden Sie Zertifikate in die OpenSearch-Konfigurationsdatei '/etc/opensearch/opensearch.yml' hinzufügen. In diesem Beispiel erstellen Sie ein neues Bash-Skript, mit dem Sie Zertifikate und TLS-Sicherheits-Plug-in-Einstellungen zu OpenSearch hinzufügen.
	  Erstellen Sie eine neue Datei 'add.sh', indem Sie den folgenden Vim-Befehl verwenden:  
	-
	  ```bash
	  vim add.sh
	  ```
	- Fügen Sie die folgenden Zeilen zur Datei hinzu. Stellen Sie sicher, dass Sie den korrekten Pfad Ihrer Zertifikatsdateien und der Ziel-OpenSearch-Konfigurationsdatei verwenden.
	-
	  ```bash
	  #! /bin/bash
	  
	  # Before running this script, make sure to replace the CN in the 
	  # node's distinguished name with a real DNS A record.
	  
	  echo "plugins.security.ssl.transport.pemcert_filepath: /etc/opensearch/certs/os-node-1.pem" | sudo tee -a /etc/opensearch/opensearch.yml
	  echo "plugins.security.ssl.transport.pemkey_filepath: /etc/opensearch/certs/os-node-1-key.pem" | sudo tee -a /etc/opensearch/opensearch.yml
	  echo "plugins.security.ssl.transport.pemtrustedcas_filepath: /etc/opensearch/certs/root-ca.pem" | sudo tee -a /etc/opensearch/opensearch.yml
	  echo "plugins.security.ssl.http.enabled: true" | sudo tee -a /etc/opensearch/opensearch.yml
	  echo "plugins.security.ssl.http.pemcert_filepath: /etc/opensearch/certs/os-node-1.pem" | sudo tee -a /etc/opensearch/opensearch.yml
	  echo "plugins.security.ssl.http.pemkey_filepath: /etc/opensearch/certs/os-node-1-key.pem" | sudo tee -a /etc/opensearch/opensearch.yml
	  echo "plugins.security.ssl.http.pemtrustedcas_filepath: /etc/opensearch/certs/root-ca.pem" | sudo tee -a /etc/opensearch/opensearch.yml
	  echo "plugins.security.allow_default_init_securityindex: true" | sudo tee -a /etc/opensearch/opensearch.yml
	  echo "plugins.security.authcz.admin_dn:" | sudo tee -a /etc/opensearch/opensearch.yml
	  echo "  - 'CN=A,OU=INF,O=ETES,L=STUTTGART,ST=BW,C=DE'" | sudo tee -a /etc/opensearch/opensearch.yml
	  echo "plugins.security.nodes_dn:" | sudo tee -a /etc/opensearch/opensearch.yml
	  echo "  - 'CN=os-node-1.hq.stgt.etes.de,OU=INF,O=ETES,L=STUTTGART,ST=BW,C=DE'" | sudo tee -a /etc/opensearch/opensearch.yml
	  echo "plugins.security.audit.type: internal_opensearch" | sudo tee -a /etc/opensearch/opensearch.yml
	  echo "plugins.security.enable_snapshot_restore_privilege: true" | sudo tee -a /etc/opensearch/opensearch.yml
	  echo "plugins.security.check_snapshot_restore_write_privileges: true" | sudo tee -a /etc/opensearch/opensearch.yml
	  echo "plugins.security.restapi.roles_enabled: [\"all_access\", \"security_rest_api_access\"]" | sudo tee -a /etc/opensearch/opensearch.yml
	  ```
- ### Admin User für OpenSeach einrichten
	- Zunächst wechseln Sie mit dem folgenden `cd`-Befehl in das Arbeitsverzeichnis zu '/usr/share/opensearch/plugins/opensearch-security/tools'.
	-
	  ```bash
	  cd /usr/share/opensearch/plugins/opensearch-security/tools
	  ```
	- Führen Sie das Skript '**hash.sh**' aus, um ein neues Passwort-Hash für OpenSearch zu generieren. Geben Sie das Passwort ein, das Sie erstellen werden und drücken Sie die Eingabetaste.
	-
	  ```bash
	  ./hash.sh
	  ```
	- Sie sollten den generierten Hash Ihres Passwortes erhalten. Kopieren Sie
	   diesen Hash, da Sie ihn später für die Konfiguration von OpenSearch   
	  benötigen werden.  
	- Wir lassen das Script noch einmal laufen um noch ein Password für Dashboards zu erstellen.
	-
	  ```
	  $2y$12$uqgL1zY5cQwk/zhozPO/sekJ4DnZ4mqLHTo/rEGK1XE6xSPABuDKm
	  
	  $2y$12$FCg2/vsCfonRJn5jNvaSLOSe6ge.pkm3AJaGBb7.9tBUW4rt7p2SS
	  
	  
	  ```
	- Als nächstes öffnen Sie die OpenSearch-Benutzerkonfigurationsdatei '/etc/opensearch/opensearch-security/internal_users.yml' mit dem folgenden VIM-Editor-Befehl. Sie werden nun Benutzer für OpenSearch über OpenSearch Security einrichten.
	-
	  ```bash
	  sudo vim /etc/opensearch/opensearch-security/internal_users.yml
	  ```
	- Löschen Sie alle Standard-OpenSearch-Benutzer und ersetzen Sie sie durch die folgenden Zeilen. Stellen Sie sicher, dass Sie das generierte Passwort durch **Ihr eigenes Hash-Passwort ersetzen.**
	-
	  ```yaml
	  ---
	  _meta:
	    type: "internalusers"
	    config_version: 2
	      
	  admin:
	     hash: "$2y$12$uqgL1zY5cQwk/zhozPO/sekJ4DnZ4mqLHTo/rEGK1XE6xSPABuDKm"
	     reserved: true
	     backend_roles:
	     - "admin"
	     description: "Admin user"
	  
	  kibanaserver:
	    hash: "$2y$12$FCg2/vsCfonRJn5jNvaSLOSe6ge.pkm3AJaGBb7.9tBUW4rt7p2SS"
	    reserved: true
	  
	  ```
	- Speichern und schließen Sie die Datei.
	- Geben Sie nun das folgende `systemctl`-Befehl aus, um den OpenSearch-Dienst neu zu starten und die Änderungen anzuwenden.
	-
	  ```bash
	  sudo systemctl restart opensearch
	  ```
	- Wechseln Sie nun in das Verzeichnis '/usr/share/opensearch/plugins/opensearch-security/tools' und führen Sie das Skript 'securityadmin.sh' aus, um die neuen Änderungen auf OpenSearch Security anzuwenden.
	-
	  ```bash
	  cd /usr/share/opensearch/plugins/opensearch-security/tools
	  OPENSEARCH_JAVA_HOME=/usr/share/opensearch/jdk ./securityadmin.sh -h 172.16.42.178 -p 9200 -cd /etc/opensearch/opensearch-security/ -cacert /etc/opensearch/certs/root-ca.pem -cert /etc/opensearch/certs/admin.pem -key /etc/opensearch/certs/admin-key.pem -icl -nhnv
	  ```
	- Das Skript 'securityadmin.sh' wird sich mit dem OpenSearch-Server verbinden, der auf der IP-Adresse **172.16.42.178** und dem Standardport **9200** läuft. Dann werden die neuen Benutzer, die Sie in der Datei '/etc/opensearch/opensearch-security/internal_users.yml' konfiguriert haben, auf den OpenSearch-Einsatz angewendet. Output sollte so aussehen:
	  ![](https://www.howtoforge.com/images/how_to_install_opensearch_on_rocky_linux_9/big/20-apply-admin-user.png)  
	- Falls der Fehler `java.io.IOException: Unrecognized SSL message, plaintext connection?` kommt, prüfen ob in /etc/opensearch/opensearch.yml das security.plugin auf true, statt false steht.
	- Abschließend werden Sie mit den neuen Benutzern, die über das Skript 'securityadmin.sh' hinzugefügt und angewendet wurden, die OpenSearch-Benutzer mithilfe des folgenden curl-Befehls überprüfen. Stellen Sie sicher, dass Sie den Hostnamen oder die IP-Adresse sowie den Benutzernamen und das Passwort für OpenSearch ändern.
	-
	  ```bash
	  curl https://os-node-1:9200 -u admin:password -k
	  curl https://os-node-1:9200 -u kibanaserver:kibanapass -k
	  ```
	- An diesem Punkt haben Sie die Installation von OpenSearch über RPM-Pakete auf dem Rocky Linux 9-Server abgeschlossen und auch den OpenSearch-Einsatz über TLS-Zertifikate gesichert sowie Benutzerauthentisierung und -autorisierung über OpenSearch Security-Plug-Ins aktiviert.
	- Im nächsten Schritt werden Sie OpenSearch Dashboards installieren und Ihren OpenSearch-Server mithilfe des neuen Benutzers, den Sie erstellt haben ('kibanaserver'), in dieses einbinden.
	-
- ## Installing OpenSearch Dashboard
	- Weil das OpenSearch-Repository immer noch den veralteten SHA1-Hash zum Verifizieren des OpenSearch Dashboard-Pakets verwendet, müssen Sie die Standard-Crypto-Policies auf Ihrem Rocky Linux in LEGACY ändern.
	  Führen Sie den folgenden Befehl aus, um die Standard-Crypto-Policy auf LEGACY zu aktualisieren.  
	-
	  ```bash
	  sudo update-crypto-policies --set LEGACY
	  ```
	  Als nächstes fügen Sie das OpenSearch Dashboards-Repository zu Ihrem System über den folgenden `curl`-Befehl hinzu.  
	  ```bash
	  sudo curl -SL https://artifacts.opensearch.org/releases/bundle/opensearch-dashboards/2.x/opensearch-dashboards-2.x.repo -o /etc/yum.repos.d/opensearch-dashboards-2.x.repo
	  ```
	  Danach überprüfen Sie die Liste der verfügbaren Repositorys auf Ihrem System. Sie sollten das Repository "OpenSearch Dashboard 2.x" in der Repository-Liste sehen.  
	  ```bash
	  sudo dnf repolist
	  ```
	  Ausgabe:  
	  Rufen Sie den folgenden `dnf`-Befehl auf, um das OpenSearch Dashboards-Paket zu installieren. Wenn Sie dazu aufgefordert werden, geben Sie y ein, um zu bestätigen und drücken Sie die EINGABETASTE, um fortzufahren.  
	  ```bash
	  sudo dnf install opensearch-dashboards
	  ```
	- Während der Installation werden Sie auch aufgefordert, den GPG-Schlüssel des OpenSearch Dashboards-Repositorys zu akzeptieren. Geben Sie y ein und drücken Sie die EINGABETASTE, um zu bestätigen.
	- Sobald OpenSearch Dashboards installiert ist, führen Sie das folgende `systemctl`-Befehlsnutility aus, um den 'opensearch-dashboard'-Dienst zu starten und zu aktivieren. Das OpenSearch Dashboard sollte nun mit der Standardkonfiguration gestartet werden und es sollte aktiviert sein, was bedeutet, dass der Dienst automatisch beim Systemstart gestartet wird.
	-
	  ```bash
	  sudo systemctl start opensearch-dashboards
	  sudo systemctl enable opensearch-dashboards
	  ```
	- Vergewissern Sie sich, dass der OpenSearch Dashboard-Dienst gestartet wird, indem Sie den folgenden Befehl ausführen:
	-
	  ```bash
	  sudo systemctl status opensearch-dashboards
	  ```
	- Sie sollten eine Ausgabe wie folgt erhalten: Der Status des OpenSearch Dashboard-Dienstes ist "laufend", und er ist auch aktiviert, so dass er automatisch beim Systemstart gestartet wird.
	- ### Dashboards konfigurieren
		- In diesem Schritt werden Sie den OpenSearch Dashboards auf der IP-Adresse und dem Port einrichten, auf denen das OpenSearch Dashboard gestartet werden soll. Außerdem wird eine Verbindung zum OpenSearch-Server eingerichtet.
		    
		  Öffnen Sie die OpenSearch Dashboard-Konfigurationsdatei "**/etc/opensearch-dashboards/opensearch-dashboard.yml**" mit dem folgenden `vim`-Befehl:  
		-
		  ```bash
		  vim /etc/opensearch-dashboards/opensearch_dashboards.yml 
		  ```
		- **OpenSearch Dashboards-Konfiguration:**
		    
		  Passen Sie die folgenden Parameter im OpenSearch Dashboards-Config an, um den Server-Port und -Host einzustellen:  
		-
		  ```yaml
		  # Der Port, auf dem das OpenSearch Dashboard gestartet wird (Standard: 5601)
		  server.port: 5601
		  
		  # Die IP-Adresse oder der Hostname des Servers, an den das Dashboard gebunden ist. Passen Sie diese Einstellung an Ihre Server-IP-Adresse an.
		  server.host: "Ihre_Server_IP"
		  ```
		  Scrollen Sie nach unten und passen Sie die OpenSearch-Serverdetails an:  
		    
		  ```yaml
		  # Array von URL(s) zu den OpenSearch-Instanzen (z.B. für clustering).
		  opensearch.hosts: ["https://Ihre_Server_IP:9200"]
		  
		  # SSL-Verifikationsmodus (Standard: 'none')
		  opensearch.ssl.verificationMode: none
		  
		  # Benutzername und Passwort für die Verbindung zum OpenSearch-Server
		  opensearch.username: "kibanaserver"
		  opensearch.password: "kibanapass"
		  ```
		    
		  Speichern Sie die Datei und beenden Sie den Editor, wenn Sie mit der Bearbeitung fertig sind.  
- ### FluentBit installieren
	- Um jegliche Art von Logs, Metrics oder Traces von unserer **Ziel-Maschine** an OpenSearch zu senden, installieren und konfigurieren wir FluentBit:
	-
	  ```bash
	  sudo yum install fluent-bit
	  ```
	- Danach
	-
	  ```bash
	  sudo systemctl daemon-reload
	  sudo systemctl start fluent-bit
	  sudo systemctl enable fluent-bit
	  ```
	- Fluent bit wird in der Regel unter /etc/fluent-bit/ installiert. Unter diesem Pfad finden wir auch die fluent-bit.conf datei, in der wir unsere Log-Pipelines definieren, um zu bestimmen, was alles & wohin unsere Logs geschickt werden sollen. BSP:
	-
	  ```conf
	  [SERVICE]
	      Log_Level        info
	  
	  [INPUT]
	      Name            cpu
	      Tag             connor.cpu
	      Interval_Sec    300  # Collect every 5 minutes
	  
	  [INPUT]
	      Name            mem
	      Tag             connor.memory
	      Interval_Sec    300  # Collect every 5 minutes
	  
	  [INPUT]
	      Name            tail
	      Path            /var/log/messages,/var/log/messages-*
	      Tag             connor.system.messages
	      Read_from_Head  On
	      Parser          syslog-rfc3164
	  
	  [INPUT]
	      Name            tail
	      Path            /var/log/secure,/var/log/secure-*
	      Tag             connor.system.secure
	      Read_from_Head  On
	      Parser          syslog-rfc3164
	  
	  [OUTPUT]
	      Name            opensearch
	      Match           *
	      Host            172.16.42.178
	      Port            9200
	      TLS             On
	      tls.verify      On
	      tls.ca_file     /etc/fluent-bit/certs/root-ca.pem
	      Index           connor-logs-%Y.%m.%d
	      HTTP_User       admin
	      HTTP_Passwd     Developer@123
	      Suppress_Type_Name On
	  ```
	-
