swiftaio_install
================

Easily create a swift all-in-one install

NOTE: Tested on Ubuntu 12.04, probably won't work on anything else.

swiftaio_install.sh: Creates a standalone swift install per http://docs.openstack.org/developer/swift/development_saio.html

In order to use, create a non-root user as which swift will run.
Grant that user ALL=NOPASSWD:ALL privs in sudoers, e.g.

    swift	ALL=NOPASSWD:ALL

Become the swift user, and run the script with bash.

In a few minutes, you should have a working swift install!

If this does not make sense to you, just run:

    sudo su -
    useradd -m -s /bin/bash swift
    echo "swift    ALL=NOPASSWD:ALL" >> /etc/sudoers
    su - swift
    wget https://raw.github.com/jonkelly/swiftaio_install/master/swiftaio_install.sh
    bash swiftaio_install.sh
    
    
