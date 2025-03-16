# Digital Ocean CIS Setup

This repository provides a quick setup for a Debian Linux server. The configuration is designed to be simple and easy to set up on a DigitalOcean droplet or similar server environments.

## Prerequisites

-A server running Debian 12
-Access to the server via SSH

## Configuration

-None

## Quickstart

Paste the single line command. It will prompt to enter domain and email address:

    sudo apt install git -y && \
    cd ~ && \
    git clone https://github.com/Amarjit/digital_ocean_cis.git && \
    cd digital_ocean_cis && \
    chmod +x setup.sh && \
    ./setup.sh
