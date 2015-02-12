# DevStack extras script to install Sheepdog

# Dependencies:
#
# - ``functions`` file
# - ``SHEEPDOG_DATA_DIR`` must be defined

# ``stack.sh`` calls the entry points in this order (via ``extras.d/60-sheepdog.sh``):
#
# - install_sheepdog
# - configure_sheepdog
# - init_sheepdog
# - start_sheepdog
# - stop_sheepdog
# - cleanup_sheepdog

# Defaults
# --------

# Set ``SHEEPDOG_DATA_DIR`` to the location of Sheepdog drives and objects.
# Default is the common DevStack data directory.
SHEEPDOG_DATA_DIR=${SHEEPDOG_DATA_DIR:-/var/lib/sheepdog}
SHEEPDOG_DISK_IMAGE=${SHEEPDOG_DATA_DIR}/sheepdog.img

# DevStack will create a loop-back disk formatted as XFS to store the
# Sheepdog data. Set ``SHEEPDOG_LOOPBACK_DISK_SIZE`` to the disk size in
# kilobytes.
# Default is 8 gigabyte.
SHEEPDOG_LOOPBACK_DISK_SIZE_DEFAULT=8G
SHEEPDOG_LOOPBACK_DISK_SIZE=${SHEEPDOG_LOOPBACK_DISK_SIZE:-$SHEEPDOG_LOOPBACK_DISK_SIZE_DEFAULT}

# Functions
# ------------

# check_os_support_sheepdog() - Check if the operating system provides a decent version of Sheepdog
function check_os_support_sheepdog {
    if [[ ! ${DISTRO} =~ (trusty) ]]; then
        echo "WARNING: your distro $DISTRO does not provide (at least) the Firefly release. Please use Ubuntu Trusty"
        if [[ "$FORCE_SHEEPDOG_INSTALL" != "yes" ]]; then
            die $LINENO "If you wish to install Sheepdog on this distribution anyway run with FORCE_SHEEPDOG_INSTALL=yes"
        fi
        NO_UPDATE_REPOS=False
    fi
}

# stop_sheepdog() - Stop running processes (non-screen)
function stop_sheepdog {
    sudo pkill -f sheep
    sleep 3

    if egrep -q ${SHEEPDOG_DATA_DIR} /proc/mounts; then
        sudo umount ${SHEEPDOG_DATA_DIR}
    fi
}

# cleanup_sheepdog() - Remove residual data files, anything left over from previous
# runs that a clean run would need to clean up
function cleanup_sheepdog {
    stop_sheepdog

    if [[ -e ${SHEEPDOG_DISK_IMAGE} ]]; then
        sudo rm -f ${SHEEPDOG_DISK_IMAGE}
    fi
    uninstall_package sheepdog > /dev/null 2>&1
}

# configure_sheepdog() - Set config files, create data dirs, etc
function configure_sheepdog {
    # create a backing file disk
    create_disk ${SHEEPDOG_DISK_IMAGE} ${SHEEPDOG_DATA_DIR} ${SHEEPDOG_LOOPBACK_DISK_SIZE}
}

# install_sheepdog() - Collect source and prepare
function install_sheepdog {
    if [[ ${os_CODENAME} =~ trusty ]]; then
        NO_UPDATE_REPOS=False
        install_package sheepdog
        install_package xfsprogs
    else
        exit_distro_not_supported "Sheepdog since your distro doesn't provide (at least) the Firefly release. Please use Ubuntu Trusty."
    fi
}

# start_sheepdog() - Start running processes, including screen
function start_sheepdog {
    # clean up from previous (possibly aborted) runs
    # make sure to kill all sheepdog processes first
    sudo pkill -f sheep || true
    sleep 3

    sudo sheep -l 7 -c local ${SHEEPDOG_DATA_DIR}
    sleep 3

    sudo dog cluster format -c 1
}

if [[ "$1" == "source" ]]; then
    # Initial source
    source $TOP_DIR/lib/sheepdog
elif [[ "$1" == "stack" && "$2" == "install" ]]; then
    echo_summary "Installing Sheepdog"
    check_os_support_sheepdog
    install_sheepdog
elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
    echo_summary "Configuring Sheepdog"
    configure_sheepdog

    # We need to have Sheepdog started before the main OpenStack components.
    start_sheepdog
fi

if [[ "$1" == "unstack" ]]; then
    stop_sheepdog
fi

if [[ "$1" == "clean" ]]; then
    cleanup_sheepdog
fi

## Local variables:
## mode: shell-script
## End:
