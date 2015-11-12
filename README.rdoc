== README

Openstack api emulator provides minimum required openstack API to build VMWare VSphere images using [Packer](https://www.packer.io/)

### Prerequisites
* VMWare VSphere 5.1 or greater
* Ruby 2.0 or greater

### Installation
* `bundle install`
* `cp config/vsphere.yml.template config/vsphere.yml`

### Configuration
* Update `config/vsphere.yml` to point to your vsphere installation

  Configuration parameters
  api:
    url         - public url which is used to access this api e.g. http://openstack-api:9000
    private_key - private key file name relative to config/ssh-keys/.
                  Public key is expected to be in the same location with .pub postfix
  vsphere:
    host              VSphere host name of ip address
    datacenter        datacenter name
    cluster           compute cluster name
    datastore_cluster datastore cluster name
    base_folder:      folder where to deploy VMs
    templates_folder: folder where to put created templates

    vm_flavors:
      standard:
        cpu: 1
        memory: 2
        disk: 10

* Since VMware has no concept of user data it's not possible to dynamically pass
ssh keys to newly created VM. To make it work with packer add public key from `config/ssh-keys/default.pem.pub`
to authorized keys of source VM

* Current implemetation looks VM only in configured template folder.
Move your source VM to this folder so api can find it

### Running packer
* Create packer file `mypacker.json`
  ```
  {
    "builders": [{
      "type": "openstack",
      "ssh_username": "root",
      "image_name": "my-new-image",
      "source_image": "my-source-image-with-default-authorized-key",
      "networks": ["<existing network switch name>"],
      "flavor": "standard"
    }],
    "provisioners": [
      {
        "type": "shell",
        "inline": [
          "echo 'Provisioning Works!'",
          "sleep 10"
        ]
      }
    ]
  }
  ```

* Run packer
  ```
    ~/packer/packer build vmware.json
    openstack output will be in this color.

    ==> openstack: Discovering enabled extensions...
    ==> openstack: Loading flavor: standard
        openstack: Verified flavor. ID: standard
    ==> openstack: Creating temporary keypair for this instance...
    ==> openstack: Launching server...
        openstack: Server ID: 502b8c9f-8ead-80dc-4e94-49c5afa2d8ae
    ==> openstack: Waiting for server to become ready...
    ==> openstack: Waiting for SSH to become available...
    ==> openstack: Connected to SSH!
    ==> openstack: Provisioning with shell script: /tmp/packer-shell556141298
        openstack: Provisioning Works!
    ==> openstack: OpenStack cluster doesn't support stop, skipping...
    ==> openstack: Creating the image: my-new-image
        openstack: Image: 502b8c9f-8ead-80dc-4e94-49c5afa2d8ae
    ==> openstack: Waiting for image to become ready...
    ==> openstack: Terminating the source server...
    ==> openstack: Deleting temporary keypair...
    Build 'openstack' finished.

    ==> Builds finished. The artifacts of successful builds are:
    --> openstack: An image was created: 502b8c9f-8ead-80dc-4e94-49c5afa2d8ae
  ```




