# Digital Ocean CIS Setup

This repository provides a quick setup for hardening a Debian based Linux server. The configuration is designed to be simple and easy to set up on a Digital Ocean droplet or similar server environments.

## Prerequisites

-A server running Debian based system
-Locally generated SSH keypair
-Access to the server via SSH

## Configuration

-None

## Quickstart

Create your SSH keypair locally with the specified comment:

    ssh-keygen -t ed25519 client_ssh_public_key_ed25519

Set your SSH public key (.pub) in the `.env` file and uncomment the line.

Paste the single line command:

    sudo apt install git -y && \
    cd ~ && \
    git clone https://github.com/Amarjit/digital_ocean_cis.git && \
    cd digital_ocean_cis && \
    chmod +x setup.sh && \
    ./setup.sh
