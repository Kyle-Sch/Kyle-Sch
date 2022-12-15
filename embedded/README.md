Development 
 - on vm
 - install cmake, make, git
Transfer files
 - scp
 - usb stick
 - plugin in an ide
Cross compile
 - cant use embedded environment for development
 - dev on your destkop
 - compile on your pc and transfer binaries to embedded devices
Package feeds
 - 
Network Boot
 - pxe
 - provide all the resources for update on network 
 - linux kernel image
    - 
 - everytime the device reboots it grabs update from network
 - Expose artifacts on the network so devices can apply them
 - mender client
    - management server
    - uboot integration
    