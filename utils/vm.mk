##@vm for different vm, can config by envrc_<data>-<build_num>

ifeq (yes,$(shell test -e envrc_${DATE}-${LAST_BUILD_NUM} && echo "yes" || echo "no"))
    include envrc_${DATE}-${LAST_BUILD_NUM}
    $(info include envrc_${DATE}-${LAST_BUILD_NUM})
endif

SEED ?= seed
META_DATA = $(SEED)/meta-data
USER_DATA = $(SEED)/user-data
# "virsh dominfo obsx" check vm instance status
HOST ?= $(DEFAULT_HOST)_${DATE}-${LAST_BUILD_NUM}
HOSTS = $(shell virsh list --all --name | grep ${DEFAULT_HOST}_)
PASSWORD ?= passw0rd

ifeq (yes,$(shell test -e ${OSTREE_REPO}/disk_$(DATE)-$(LAST_BUILD_NUM) && echo yes || echo no))
SEED_HASH ?= $(shell cat ${USER_DATA} ${META_DATA} | md5sum | head -c 4)
SEED_ISO ?= seed_$(SEED_HASH).iso
endif

$(USER_DATA): $(SEED)
	@printf "#cloud-config\npassword: $(PASSWORD) \
\nchpasswd: { expire: False }\
\nssh_pwauth: True\
\n" > $(USER_DATA)
	cat $(USER_DATA)

$(META_DATA): $(SEED)
	@printf "instance-id: $(HOST)\
\nlocal-hostname: escore\
\n" > $(META_DATA)
	cat $(META_DATA)


seed_iso: $(USER_DATA) $(META_DATA)  ##@vm create cloud-init seed image
ifneq ($(wildcard ${SEED}/*_data),)
	$(error user_data is not created)
endif
ifeq (no,$(shell test -e ${OSTREE_REPO}/disk_$(DATE)-$(LAST_BUILD_NUM) && echo yes || echo no))
	$(error ${OSTREE_REPO}/disk_$(DATE)-$(LAST_BUILD_NUM) is not created, please make iso first)
endif
	cd $(SEED); genisoimage -output $(OSTREE_REPO)/$(SEED_ISO) -volid cidata -joliet -rock user-data meta-data
ifneq (0,$(SUDO_UID))
	@chown -R $(SUDO_UID):$(SUDO_GID) $(OSTREE_REPO)/$(SEED_ISO) 
endif

build_seed:  ##@vm rebuild seed image
	echo envrc_${DATE}-${LAST_BUILD_NUM}
	rm -f $(USER_DATA) $(META_DATA)
	@make -s $(USER_DATA) $(META_DATA)

vm_create: IMG?=${OSTREE_REPO}/disk_${DATE}-${LAST_BUILD_NUM}/images/es-atomic-host-7.qcow2
vm_create: seed_iso  ##@vm create vm, use last image or IMG=<path> make vm_create
	@echo pass
	virt-install \
--name=$(HOST) \
--ram 1024 \
--disk path=$(IMG),size=8 \
--vcpus=1 \
--graphics none \
--noautoconsole \
--network bridge=virbr0 \
--cdrom=$(OSTREE_REPO)/$(SEED_ISO) \
--os-type=linux \
--os-variant=rhel7

vm_console:  ##@vm connect to current host, or HOST=<xxx> make vm_console
	virsh console $(HOST)

vm_list:  ##@vm list all atomic host vms
	@echo $(HOSTS)

vm_destroy:  ##@vm destroy current host
	virsh destroy $(HOST)
	virsh undefine $(HOST)

vm_destroy_all:  ##@vm destroy all atomic host vms
	@for i in $(HOSTS);      \
	do                       \
	  virsh destroy $$i;     \
	  virsh undefine $$i;    \
	done