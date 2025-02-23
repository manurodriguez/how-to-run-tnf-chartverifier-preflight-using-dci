ARG OPENSHIFT_CLIENT_VERSION=4.9.25
FROM registry.access.redhat.com/ubi8/ubi:8.4-213
LABEL name="DCI runs TNF, Preflight and ChartVerifier" \
      maintainer="dcicontainer.scm@redhat.com" \
      vendor="Red Hat, Inc." \
      version="1" \
      release="" \
      summary="Use DCI to run preflight, chart-verifier and tnf" \
      description="Use DCI to run Preflight, Chart-Verifier and TNF Test Suite inside a container"

RUN mkdir -p /licenses
COPY License.txt /licenses/License.txt

RUN dnf -y  update --disablerepo=* --enablerepo=ubi-8-appstream --enablerepo=ubi-8-baseos

RUN dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
RUN dnf -y install https://packages.distributed-ci.io/dci-release.el8.noarch.rpm

RUN dnf install python3-kubernetes -y
RUN dnf -y install dci-openshift-app-agent
#dnf upgrade --refresh --repo dci -y

RUN dnf -y install net-tools ; dnf -y install wget; dnf -y install procps;

RUN rm -rf /var/log/*
RUN dnf -y update; yum -y reinstall shadow-utils; yum -y install crun; yum -y install iputils iproute bzip2 iptables; yum -y install net-tools; yum -y install openscap-utils; \
yum -y install podman fuse-overlayfs --exclude container-selinux; \
rm -rf /var/cache /var/log/dnf* /var/log/yum.*

RUN useradd podman; \
echo podman:10000:5000 > /etc/subuid; \
echo podman:10000:5000 > /etc/subgid; \
echo dci-openshift-app-agent:100000:65536 >> /etc/subuid; \
echo dci-openshift-app-agent:100000:65536 >> /etc/subgid;

VOLUME /var/lib/containers
VOLUME /home/podman/.local/share/containers

ADD https://raw.githubusercontent.com/containers/libpod/master/contrib/podmanimage/stable/containers.conf /etc/containers/containers.conf
ADD https://raw.githubusercontent.com/containers/libpod/master/contrib/podmanimage/stable/podman-containers.conf /home/podman/.config/containers/containers.conf

RUN chown podman:podman -R /home/podman

# chmod containers.conf and adjust storage.conf to enable Fuse storage.
RUN chmod 644 /etc/containers/containers.conf; sed -i -e 's|^#mount_program|mount_program|g' -e '/additionalimage.*/a "/var/lib/shared",' -e 's|^mountopt[[:space:]]*=.*$|mountopt = "nodev,fsync=0"|g' /etc/containers/storage.conf
RUN mkdir -p /var/lib/shared/overlay-images /var/lib/shared/overlay-layers /var/lib/shared/vfs-images /var/lib/shared/vfs-layers; touch /var/lib/shared/overlay-images/images.lock; touch /var/lib/shared/overlay-layers/layers.lock; touch /var/lib/shared/vfs-images/images.lock; touch /var/lib/shared/vfs-layers/layers.lock

ENV _CONTAINERS_USERNS_CONFIGURED=""

# Install OpenShift client binary
ARG OPENSHIFT_CLIENT_VERSION
RUN curl --fail -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${OPENSHIFT_CLIENT_VERSION}/openshift-client-linux-${OPENSHIFT_CLIENT_VERSION}.tar.gz | tar -xzv -C /usr/local/bin oc

RUN pip3 install --force-reinstall ansible

RUN dnf clean all; yum clean all

#rhbz 1609043
RUN mkdir -p /var/log/rhsm; rm -rf /var/cache/dnf
