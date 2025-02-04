#!/bin/bash
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
#
set -e
INSALLED_FILE=/etc/azslurm-bins.installed
if [ -e $INSALLED_FILE ]; then
    exit 0
fi

SLURM_ROLE=$1
SLURM_VERSION=$2
DISABLE_PMC=$3
OS_VERSION=$(cat /etc/os-release  | grep VERSION_ID | cut -d= -f2 | cut -d\" -f2 | cut -d. -f1)

yum -y install epel-release
yum -y install munge
if [ "$OS_VERSION" -gt "7" ]; then
    dnf -y --enablerepo=powertools install -y perl-Switch
    PACKAGE_DIR=slurm-pkgs-rhel8
else
    yum -y install python3
    PACKAGE_DIR=slurm-pkgs-centos7
fi

slurm_packages="slurm slurm-slurmrestd slurm-libpmi slurm-devel slurm-pam_slurm slurm-perlapi slurm-torque slurm-openlava slurm-example-configs"
sched_packages="slurm-slurmctld slurm-slurmdbd"
execute_packages="slurm-slurmd"


if [ "$DISABLE_PMC" == "False" ]; then

    if [ "$OS_VERSION" -gt "7" ]; then
        cp slurmel8.repo /etc/yum.repos.d/slurm.repo
    else
        cp slurmel7.repo /etc/yum.repos.d/slurm.repo
    fi

    ## This package is pre-installed in all hpc images used by cyclecloud, but if customer wants to
    ## build an image from generic marketplace images then this package sets up the right gpg keys for PMC.
    if [ ! -e /etc/yum.repos.d/microsoft-prod.repo ];then
        curl -sSL -O https://packages.microsoft.com/config/rhel/$OS_VERSION/packages-microsoft-prod.rpm
        rpm -i packages-microsoft-prod.rpm
        rm packages-microsoft-prod.rpm
    fi
    for pkg in $slurm_packages; do
        yum -y install $pkg-${SLURM_VERSION}.el${OS_VERSION} --disableexcludes slurm
    done
    if [ ${SLURM_ROLE} == "scheduler" ]; then
        for pkg in $sched_packages; do
            yum -y install $pkg-${SLURM_VERSION}.el${OS_VERSION} --disableexcludes slurm
        done
    fi

    if [ ${SLURM_ROLE} == "execute" ]; then
        for pkg in $execute_packages; do
            yum -y install $pkg-${SLURM_VERSION}.el${OS_VERSION} --disableexcludes slurm
        done
    fi
    touch $INSALLED_FILE

    exit
fi


for pkg in $slurm_packages; do
    yum -y install $PACKAGE_DIR/slurm-$SLURM_VERSION/RPMS/$pkg-${SLURM_VERSION}.el${OS_VERSION}*.rpm
done

if [ ${SLURM_ROLE} == "scheduler" ]; then
    for pkg in $sched_packages; do
        yum  -y install $PACKAGE_DIR/slurm-$SLURM_VERSION/RPMS/$pkg-${SLURM_VERSION}.el${OS_VERSION}*.rpm
    done
fi

if [ ${SLURM_ROLE} == "execute" ]; then
    for pkg in $execute_packages; do
        yum  -y install $PACKAGE_DIR/slurm-$SLURM_VERSION/RPMS/$pkg-${SLURM_VERSION}.el${OS_VERSION}*.rpm
    done
fi

touch $INSALLED_FILE
