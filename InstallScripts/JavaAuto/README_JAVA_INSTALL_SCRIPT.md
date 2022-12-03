# Automated jar installation

## Overview
There are two scripts involved in the automated jar installation: jarInstall.sh and javaInstall.sh. The combination of these two bash scripts allows for an automatic, safe installation of Jars. It ensures that the jars stay up and running for a desired amount of time, and will backout to the previous stable jar if anything goes wrong in the process. The script is also versatile, as it can hit 4 different use cases explained below.

### jarDowntimeInstallScript.sh
This script determines the use case, sets parameters, and calls javaInstall.sh on the desired machine(s). Having this script allows for an easier installation on the remote machine. This script also has the capability to wait for downtime on the machines and to ensure that the installation is only happening on one machine at a time.

### jarImmediateInstallScript.sh
This script does the actual installation of the new jar. It moves the jar from the staging directory to the jars directory, updates the symbolic link, kils the old jar, starts the new jar, then ensures that the new jar stays running for an alloted time period. If the new jar crashes, the script will revert the process.

## Use Cases
1) (default) Wait for full staging on both machines, wait for downtime on both machines, install on both machines

2) Wait for full staging on both machines, then immediately install on both machines (does NOT wait for downtime)

3) Wait for downtime on local machine only, then install on local machine only

4) Immediately install on local machine only

## Arguments
Call "./jarDowntimeInstallScript.sh -h" to see all the options the script takes in