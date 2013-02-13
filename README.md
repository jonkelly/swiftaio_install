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
