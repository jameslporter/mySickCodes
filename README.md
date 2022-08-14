# This is my quick redo of sick.codes osx docker/kvm os X VM.

## This uses docker-compose and a docker volume to persist your os x image.


### Getting started
```
mkdir -p baseImages
cd baseImages
wget or curl https://images.sick.codes/BaseSystem_Monterey.dmg
cd ..
docker-compose build
docker-compose up -d
```
OS X bootloader should startup shortly after

The docker volumes would be named something like mysickcodes_disk. Use ```docker volume ls``` to verify.

To start over delete this volume ```docker volume delete mysickcodes_disk```
