#!/bin/bash

#This script is used to install the matrix-synapse server. This is going to be a base script of installing Postgres, generate the files needed for matrix, then run matrix
#For documentation, please go to https://wiki.antwons.com/en/matrix

#Part 1 - A friendly start
clear
echo "Welome to Antwons Matrix Install script!"
sleep 2
clear
echo "In this script we are going to install a few things. So please read all prompts completely."
sleep 3
clear

#Part 2 - Docker download & portainer install
#In this section we will ask the user if they already have docker installed. If they do not have docker already installed, it will install the latest version
#of docker and docker-compose and all its dependencies.
#After that installation, it will ask the user if they want to install portainer. If yes, it will ask them if they want portainer agent or CE.

read -p "Do you want to install Docker? (y/n): " answer

if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
    # We will update our repositories and get certificaties and GPG keys needed
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
     $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
     tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    
    # beign installing docker & docker compose 
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    clear
    sleep 3
    echo "Docker has been successfully installed."
    sleep 3
fi

clear
sleep 1

#Now we are going to ask if the user wants to install portainer
# Function to install portainer CE
install_portainer_ce() {
    echo "Installing Portainer-CE..."
    sleep 2
    sudo docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
    sleep 2
    clear
    echo "Portainer-CE installed successfully!"
    sleep 2
}

# Function to install Portainer Agent
install_portainer_agent() {
    echo "Installing Portainer Agent..."
    sleep 2
    sudo docker run -d -p 9001:9001 --name portainer_agent --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker/volumes:/var/lib/docker/volumes portainer/agent:latest
    sleep 2
    clear
    echo "Portainer Agent installed successfully!"
    sleep 2
}

read -p "Do you want to install Portainer? (y/n): " install_portainer

if [ "$install_portainer" == "y" ]; then
    read -p "Do you want to install Portainer-CE or Portainer Agent? (portainer-ce/portainer-agent): " install_type

    if [ "$install_type" == "portainer-ce" ]; then
        install_portainer_ce
    elif [ "$install_type" == "portainer-agent" ]; then
        install_portainer_agent
    else
        echo "The Option you selected was incorrect. Please run this script again."
        sleep 2
        exit 1
    fi
else
    echo "You've opted out of downloading Portainer. Continuing with the script."
    sleep 2
fi

#Now that Docker is installed and portainer is installed, we wil continue with running the docker for Matrix

read -p "Do you want to install PostgreSQL? (y/n): " answer

if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
    read -p "Enter the PostgreSQL password: " postgresPassword
    echo

    # Run PostgreSQL Docker container with the provided password
    sudo docker run -d --name postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=$postgresPassword -e POSTGRES_DB=matrix -e POSTGRES_INITDB_ARGS="--encoding=UTF8 --lc-collate=C --lc-ctype=C" -v /home/postgres/data:/var/lib/postgresql/data -p 5432:5432 postgres:latest
    clear
    echo "The PostgreSQL container has been successfully started with the provided password."
    sleep 2
    clear
else
    echo "Skipping PostgreSQL Docker installation."
    sleep 2
fi

clear

#Now we will start the matrix server install
echo "Now we are going to install Matrix, please hold!"
sleep 2
clear
 read -p "Enter the fully qualified domain name (FQDN) for matrix: " domain
echo
sudo docker run -it --rm \
--mount type=volume,src=synapse-data,dst=/data \
-e SYNAPSE_SERVER_NAME=$domain \
-e SYNAPSE_REPORT_STATS=yes \
matrixdotorg/synapse:latest generate
clear
sleep 5
echo "Now we will move the homeserver.yaml file that you've completed over to this directory"
sleep 2
 read -p "Enter the subdomain name for matrix: " subdomain
echo
clear
 read -p "Enter the IP address of your PostgreSQL instance: " postgres_ip
echo
clear
random_hex=$(openssl rand -hex 16)
echo "Random Hex Code: $random_hex"
clear
echo "server_name: \"$domain\" #This is your top-level domain name
pid_file: /data/homeserver.pid
public_baseurl: \"https://$subdomain.$domain/\" #We need this in order for OAUTH to work
listeners:
  - port: 8448
    type: http
    tls: false
    resouces:
      - names: [client,federation]
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    resources:
      - names: [client, federation]
        compress: false
#You do not need to federate, if you do not have any other servers to federate with.
#If you don't want to use this, just comment it out.
#federation_domain_whitelist:
#  - domain.net
# - subdomain.domain.net
database:
  name: psycopg2
  args:
    user: postgres
    password: $postgresPassword #This is the password we set up earlier in postgresql
    database: matrix
    host: $postgres_ip #This is the IP address of the server your PostgreSQL container is at
    port: 5432
    cp_min: 5
    cp_max: 10
#log_config: \"/data/$subdomain.$domain.log.config\"
media_store_path: /data/media_store
turn_shared_secret: \"$random_hex\"
enable_registration: true
enable_registration_without_verification: true
#registrations_require_3pid:
#  - email
registration_shared_secret: \"$random_hex\"
enable_set_displayname: true
#The following is to ensure that when a new user joins, they automatically join home chat!
#auto_join_rooms:
#  - \"#home:$domain.com\"
autocreate_auto_join_rooms: true
report_stats: false
account_validity:
  enabled: true
  period: 12w
  renew_at: 1w
  renew_email_subject: \"Renew your %(app)s account\"
macaroon_secret_key: \"$random_hex\"
form_secret: \"$random_hex\"
signing_key_path: \"/data/$subdomain.$domain.signing.key\"
trusted_key_servers:
  - server_name: \"matrix.org\"
suppress_key_server_warning: true
#For more information on how to set up OIDC go to the following site https://matrix-org.github.io/synapse/latest/openid.html#google
#If you do not want OIDC set up, just comment the following out
#oidc_providers:
#  - idp_id: google
#    idp_name: Google
#    idp_brand: \"google\"
#    issuer: \"https://accounts.google.com/\"
#    client_id: \"INSERT CLIENT ID\"
#    client_secret: \"INSERT CLIENT SECRET\"
#    scopes: [\"openid\", \"profile\", \"email\"]
#    user_mapping_provider:
#      config:
#        localpart_template: \"{{ user.name }}\"
#        display_name_template: \"{{ user.given_name|lower }}\"
#        email_template: \"{{ user.email }}\"
#For more information on how to set up SMTP go to https://support.cloudways.com/en/articles/5131076-how-to-configure-gmail-smtp
#Follow steps 1-3 as it shows you how to get the information needed below
#email:
#  smtp_host: smtp.gmail.com
#  smtp_port: 587
#  smtp_user: \"username@domain.com\"
#  smtp_pass: \"password\"
#  require_transport_security: true
#  notif_from: \"%(app)s <user@domain.com>\"
#  app_name: \"Matrix Chat\"
#  enable_notifs: true
#  invite_client_location: https://subdomain.domain.com
#subjects:
#  message_from_person_in_room: \"[%(app)s] You have a message on %(app)s from %(person)s in the %(room)s room...\"
#  message_from_person: \"[%(app)s] You have a message on %(app)s from %(person)s...\"
#  messages_from_person: \"[%(app)s] You have messages on %(app)s from %(person)s...\"
#  messages_in_room: \"[%(app)s] You have messages on %(app)s in the %(room)s room...\"
#  messages_in_room_and_others: \"[%(app)s] You have messages on %(app)s in the %(room)s room and others...\"
#  messages_from_person_and_others: \"[%(app)s] You have messages on %(app)s from %(person)s and others...\"
#  invite_from_person_to_room: \"[%(app)s] %(person)s has invited you to join the %(room)s room on %(app)s...\"
#  invite_from_person: \"[%(app)s] %(person)s has invited you to chat on %(app)s...\"
#  password_reset: \"[%(server_name)s] Password reset\"
#  email_validation: \"[%(server_name)s] Validate your email\"
#server_notices:
# system_mxid_localpart: notices
# system_mxid_display_name: \"Server Notices\"
# system_mxid_avatar_url: \"mxc://server.com/oumMVlgDnLYFaPVkExemNVVZ\"
# room_name: \"Server Notices:\"" >> homeserver.yaml
sleep 2
sudo mv -f homeserver.yaml /var/lib/docker/volumes/synapse-data/_data
clear
sleep 1
echo "Now we will start the Matrix docker container"
sleep 2
clear
sudo docker run -d --name synapse \
    --mount type=volume,src=synapse-data,dst=/data \
    -p 8008:8008 \
    matrixdotorg/synapse:latest
clear
sleep 1
echo "please wait as it finishes installing"
sleep 4
clear

#Now we get the IP address and point the users where to go!
local_ip=$(hostname -I | awk '{print $1}')
clear
echo "Awesome! We are installed, now lets create an admin user"
sleep 2
sudo docker exec -it synapse register_new_matrix_user http://$local_ip:8008 -c /data/homeserver.yaml
sleep 2
clear
echo "Now that we have made the user, head over to https://app.element.io/ to begin with your server!"
sleep 2
echo
echo "your homeserver domain is https://$subdomain.$domain & your IP is $local_ip"
sleep 2
echo
echo "Thank you for using our script!"
sleep 2

#END OF SCRIPT 
