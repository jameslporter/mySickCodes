This is my quick redo of sick.codes osx docker/kvm os X VM. This uses docker-compose and a docker volume if you want to persist your os x image.

cd baseImages or mkdir -p baseImages
wget or curl https://images.sick.codes/BaseSystem_Monterey.dmg

docker-compose build
docker-compose up -d
OS X bootloader should startup shortly after

The docker volumes would be named like this, use docker volume ls:
mysickcodes_disk

to start over delete this volume