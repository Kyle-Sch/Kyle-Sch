#!/bin/bash


#/****************************************************************************************/
#/*                                 PROPERTY OF FEDEX                                     /
#/*                                                                                       /
#/* PROGRAM: configDowntimeInstallScript.sh                                                  /
#/* DESCRIPTION: Script that safely installs a new config files with the following versatility:    /
#/             - Capable of installing on local and remote machines                       /
#/             - Can wait for site downtime                                               / 
#/             - Configurable arguments (type in -h to see all viable args)               /
#/                                                                                        /
#/                                                                                        /
#/* DATE WRITTEN: 02/2021                                                                 /
#/* DEPENDENCIES: Requires jarImmediateInstallScript.sh                                   /
#/* AUTHORS: Matt Cole, Chris Mazur                                                       /
#/*                                                                                       /
#/*                                                                                       /
#/****************************************************************************************/



usage(){
    # Prints out the options the script takes in

    echo   "Usage: [-l <logLocation>][-m <majorGoal>][-v <appVersion>][-a <appAbbrev>][-t <timeout>][-c <callScript>][-r <revertScript]"
    echo   "    -m  majorGoal of the script (REQUIRED). Choose one of the following:"
    echo   "            1) Wait for full staging on both machines, wait for downtime on both machines, install on both machines (DEFAULT)"
    echo   "            2) Wait for full staging on both machines, install on both machines"
    echo   "            3) Wait for downtime on local machine, then install on local machine"
    echo   "            4) Install on local machine immediately"
    echo   "    -l  location to log output to (defaults to logfile)"
    echo   "    -v  app version (REQUIRED)"
    echo   "    -a  app abbreviation (REQUIRED)"
    echo   "    -t  timeout (defaults to 120)"
    echo   "    -c  scripts to call. Can specify multiple"
    echo   "    -r  revert scripts. Can specify multiple"

}

logEcho(){
    # Logs all arguments passed with a timestamp

    echo "$@"
    if [[ ! -e $(dirname "$logFile") ]]; then
        mkdir -p $(dirname "$logFile")
    fi
    echo "Master Script - $(date) - $*" >> "$logFile"
}

printOptions(){
    # Logs all of the options given in

    logEcho ""
    logEcho "jarDowntime IS NOW RUNNING WITH THE FOLLOWING ARGUMENTS: "
    logEcho "----------------------------------------------------------"
    logEcho "goal:             $goal"
    logEcho "logLocation:      $logFile"
    logEcho "appAbbreviation:  $appAbbrev"
    logEcho "timeout:          $timeout"
    logEcho "uptimeToWaitFor:  $uptimeToWaitFor"
    logEcho "jarName:          $jarName"
    logEcho "oldJarName:       $oldJarName"
    logEcho "Call Scripts: "
    for callScript in "${callScripts[@]}"
    do
        logEcho "          $callScript"
    done
    logEcho ""
    logEcho "Revert Scripts: "
    for revertScript in "${revertScripts[@]}"
    do
        logEcho "          $revertScript"
    done
    logEcho "----------------------------------------------------------"
    logEcho ""
}

setLocalVariables(){
    # Sets some necessary global variables that are needed on the Local machine. Also runs some safety checks.
    
    safetyChecks() {
        # Runs safety checks to make sure scripts will run in an acceptable state

        paramsSafetyCheck(){
            # Ensures all required parameters were passed properly, exits if not
            #   NOTE: If app version or app abbreviation is empty, the log file is changed

            echo "PARAMS SAFETY CHECK HAPPENING"
            excludesPattern="([-*]|[ ])"
            if [[ "$appVersion" =~ $excludesPattern ]] || [[ -z "$appVersion" ]]
            then
                logFile=$errorLogFile
                logEcho "FAILED. AppVersion is $appVersion, which is invalid. Exiting now"
                exit 1
            fi

            # App Abbreviation
            if [[ "$appAbbrev" =~ $excludesPattern ]] || [[ -z "$appAbbrev" ]]
            then
                logFile=$errorLogFile
                logEcho "FAILED. AppAbbreviation is $appAbbrev, which is invalid. Exiting now"
                exit 1
            fi

            # Use Case
            if ! ([[ "$majorGoal" -eq "1" ]] || [[ "$majorGoal" -eq "2"  ]] || [[ "$majorGoal" -eq 3  ]] || [[ "$majorGoal" -eq 4  ]])
            then
                logEcho "FAILED. Major goal = $majorGoal, when it has to be in [1, 2, 3, 4]. Exiting now."
                exit 1
            fi
        }
        
        oasisSafetyCheck(){
            # Ensures script is being run as Oasis

            user=$(whoami)
            if [[ "$user" != "oasis" ]]
            then 
                logEcho "Install script was run as $user, not oasis. Exiting now."
                exit 1
            fi
        }


        ensureDowntimeScriptIsntAlreadyRunning(){
            # If the downtime script is already running with the same args, cancel the call of this script
                # NOTE: there are 2 PIDS for each script running
            


            numDowntimeScriptPIDs=$(ps -eaf | grep jarDowntimeInstallScript | grep $appAbbrev | grep $appVersion | grep -v grep | grep -iv daemon | grep -iv root | awk '{print $2}' | wc -l)
            
            # If there are more than 2 pids, script is already running.
            numPIDs=2
            if [[ $numDowntimeScriptPIDs -gt $numPIDs ]]; then
                logEcho "Downtime script is already running with the same args. Exiting now."
                exit 1            
            fi 

        }

        paramsSafetyCheck

        oasisSafetyCheck

        ensureDowntimeScriptIsntAlreadyRunning

        logEcho "Safety checks have been passed. Moving on with script"
    }

    createJarsDir(){
        # Creates jars directory if it doesn't exist already

        if [[ ! -e $jarsDir ]]; then
            logEcho "Jars dir missing, creating...."
            mkdir -p $jarsDir
        fi
    }

    setLogFile(){
        # Sets the log file name if it is empty

        if [[ -z "$logFile" ]]; then
            logFile="/var/fedex/iss/logs/installs/jar_install_${appAbbrev}_${appVersion}.log"
        fi

        echo "logFile: $logFile"
    }

    setJarName(){
        # Given the app's abbrevation, generates the name of the jar

        _jarName="${appNames[$appAbbrev]}-${appVersion}.jar"
        cd $stagePath
        jarName=$(ls ${_jarName})
        logEcho "Jar name = $jarName"
        cd /
    }

    setStagePath(){
        stagePath="${stageDir}${appAbbrev}"
    }

    setAppName(){
        appName="${appNames[$appAbbrev]}"
    }

    setAppNameAndInstanceNumber(){
        # Gets and sets the app name and instance number from /var/fedex/iss/common/systPFserverApps

        appNameAndInstanceNum="$(grep $appName /var/fedex/iss/common/systPFserverApps | awk '{print $1;}')1"
    }

    setOldJarName(){
        # Sets the oldJarName variable to the name of the previous working jar
        oldJarLink=$(ls -l $jarsDir/$appName | awk '{print $11}')
        oldJarName=$(echo ${oldJarLink##*/})

        logEcho "oldJarName = $oldJarName"
    }

    setLocalMachine(){
        # Sets the value for localMachine for which the script is running on
        
        localMachine=$(cat /var/fedex/iss/common/systPFnodeId)
    }

    createSystPFinstallActivelyRunningFileLocally(){
        # Creates the systPFinstallActivelyRunningFile if it doesn't exist in the stage dir on the local machine
        
        touch $stageDir/$appAbbrev/$systPFinstallActivelyRunning
    }

    setOldJarOptionString(){
        # Sets the Old Jar option (this makes it so the option never takes in an empty string)

        if [[ -z $oldJarName ]]; then
            oldJarOptionString=""
        else
            oldJarOptionString=" -o $oldJarName"
        fi
    }

    setCallScriptsString(){
        # Creates a string to hold all the call scripts (to pass into installScript.sh)
        # -c callScript1 -c callScript2 -c callScript3 ... -c callScriptN

        for callScript in "${scripts[@]}"
        do
            callScriptsString+=" -c ${callScript}"
        done

        logEcho $callScriptsString

    }

    setRevertScriptsString(){
        # Creates a string to hold all the revert scripts (to pass into installScript.sh)
        # -r revertScript1 -r revertScript2 -r revertScript3 ... -r revertScriptN
    
        for revertScript in "${revertScripts[@]}"
        do
            revertScriptsString+=" -r ${revertScript}"
        done

        logEcho $revertScriptsString

    }

    
    jarSafetyCheck(){
        # Ensures that jar exists in stage directory
        
        if [[ -z "$jarName" ]]; then
            logEcho "New jar not found in stage directory. Exiting now"
            exit 1
        fi
    }

    # CONSTANTS
    dockFile="/var/fedex/iss/common/systWFdockLoaded"        # Path that says whether or not a dock is loaded 
    stageDir="/opt/fedex/iss/bin/stage/"                      # Stage directory path
    jarsDir="/opt/fedex/iss/bin/jars"                         # Jars directory path
    systPFinstallActivelyRunning="systPFinstallActiveRunningSince" # File that says if the machine is running the script
    scriptPath="/opt/fedex/iss/bin/stage/${appAbbrev}/jarImmediateInstallScript.sh"           # Path to the javaInstall script
    errorLogFile="/var/fedex/iss/logs/installs/jar_install_ERROR.log"  # Logfile to be used for install error ONLY if empty app abbreviation / app version
    operatingSystem=$(uname)                                   # Operating system the script is running on

    echo "Operating system: $operatingSystem"

    # App abbreviation to full app name mapping
    declare -A appNames
    appNames=( 
        ["tls"]="trailerload-service"  
        ["hsc"]="health-status-client"
        ["hss"]="health-status-service"
        ["dmt"]="iss-dmtconsumerservice"
        ["sub"]="iss-subscriber"
        ["web"]="iss-web-service"
        ["zip"]="iss-zip-to-dest-dwlds"
        ["cls"]="IssClsSrvr"
        ["rest"]="rest-downloads-service"
        ["sort"]="sort-downloads"
        ["ssp"]="SSPAdapterService"
        ["pub"]="iss-publisher"
        ["wrapper"]="iss-wrapper-service"
        ["stv"]="iss-sorttovoiceservice"
        ["smalls"]="smallsservice"
        ["registry"]="iss-serviceregistry"
        ["adls"]="iss-assignmentdocklookupserver"
        ["ncp"]="nc-pickoff-service"
        ["dus"]="iss-dockupdateservice"
        ["bas"]="iss-bagattrservice"
        ["zipcorrect"]="zip-correct-service"
        ["sortassist"]="sort-assist-service"
        ["uiorch"]="uiOrchestrator"
        ["airops"]="air-ops-service"
        )

    # Placeholders global variables to be filled in later
    stagePath=""                  # Stage Path
    jarName=""                    # Name of the new jar to install
    oldJarName=""                 # Name of the currently running jar
    appName=""                    # Full application name
    appNameAndInstanceNum=""      # App name and instance number from systPFserverApps
    goal="install"                # The goal to pass to installScript (install | backout)
    oldJarOptionString=""
    callScriptsString=""          # A string concatenation of all the call scripts 
    revertScriptsString=""        # A string concatenation of all the revert scripts
    localMachine=""               # Name of the local machine
    localMachineActivityStatus="" # Holds the activity status of the local machine
    localAppCrashed="false"       # Whether or not the local app crashed
    localMachineTimeStamp=""      # Timestamp for when the local machine started running the script

    # Call some functions to set variables as needed
    createJarsDir
    setLogFile
    setStagePath
    safetyChecks
    setAppName
    setAppNameAndInstanceNumber
    setJarName
    jarSafetyCheck
    setOldJarName
    setLogFile
    setOldJarOptionString
    setCallScriptsString
    setRevertScriptsString
    setLocalMachine
    setLocalMachineActivityStatus

    createSystPFinstallActivelyRunningFileLocally
}

setRemoteVariables(){
    # Sets all variables that pertain to the remote machine

    setRemoteMachine(){
        # Sets the value for remoteMachine

        remoteMachine=$(cat /var/fedex/iss/common/systPFsmsMachines | grep -v $localMachine | cut -d "=" -f 2)
    }

    createSystPFinstallActivelyRunningFileRemotely(){
        # Creates the systPFinstallActivelyRunningFile if it doesn't exist in the stage dir on the remote machine
        
        ssh oasis@$remoteMachine "touch $stageDir/$appAbbrev/$systPFinstallActivelyRunning"
    }

    remoteMachine=""                # Name of the remote machine
    remoteMachineActivityStatus=""  # Holds the activity status of the remote machine
    remoteMachineRunningStatus=""   # Holds whether or not the script is running on the other machine
    remoteMachineTimeStamp=""       # Timestamp of when the remote machine started running the script
    remoteMachineJarName=""         # Holds the name of the jar on the remote machine (empty string if none)

    # Call some functions to set remote variables as needed
    setRemoteMachine
    setRemoteMachineActivityStatus
    createSystPFinstallActivelyRunningFileRemotely

    logEcho "Remote variables set successfully"
}

setLocalMachineActivityStatus(){
    # Sets the localMachineActivty to A if active, I if inactive 
    
    localMachineActivityStatus=$(cat /var/fedex/iss/common/systWFmachineSelect)
} 

setRemoteMachineActivityStatus(){
    # Sets the remoteMachineActivty to A if active, I if inactive

    remoteMachineActivityStatus=$(ssh oasis@$remoteMachine "cat /var/fedex/iss/common/systWFmachineSelect")
}

waitUntilDockUnloadedLocally(){
    # Sleeps until the dock is completely unloaded on the local machine
    
    dockLoadedCheckLocally
    while [[ -n "$dockLoadedLocally" ]] ; do
        logEcho "Dock is still loaded on $localMachine..."
        sleep 10
        dockLoadedCheckLocally
    done

    logEcho "Dock is unloaded"
    return 0
}

waitUntilDockUnloadedRemotely(){
    # Sleeps until the dock is completely unloaded on the remote machine

    dockLoadedCheckRemotely
    while [[ -n "$dockLoadedRemotely" ]] ; do
        logEcho "Dock is still loaded on $remoteMachine..."
        sleep 10
        dockLoadedCheckRemotely
    done
    logEcho "Dock is unloaded"
    return 0
}

dockLoadedCheckLocally(){
    # Sets the dockLoadedLocally variable

    logEcho "Checking if dock is loaded on local machine..."
    dockLoadedLocally="$(cat $dockFile)"

}

dockLoadedCheckRemotely(){
    # Sets the dockLoadedRemotely variable

    logEcho "Checking if dock is loaded on remote machine... "
    dockLoadedRemotely=$(ssh oasis@$remoteMachine "cat $dockFile")

}

ensureProperActvityStatuses(){
    # Make sure that exactly one machine is active. Exits if not

    logEcho "Checking machine activity statuses ..."
    # Are both machines active?
    if [[ $localMachineActivityStatus == "A" && $remoteMachineActivityStatus == "A" ]] ; then
        logEcho "Both machines are active. Exiting now."
        exit
    fi

    # Are both machines inactive?
    if [[ $localMachineActivityStatus != "A" && $remoteMachineActivityStatus != "A"  ]] ; then
        logEcho "Both machines are inactive. Exiting now."
        exit
    fi

    logEcho "Exactly one machine is active, moving on with the process"
}

markInstallAsSuccess(){
    # Installation has succeeded on both machines

    logEcho "Installation successful!"
}

setLocalRunningFlag(){
    # Sets running flag to time since epoch (in seconds) in file in local machine's stage directory

    date +%s | cut -b1-13 > "${stageDir}/$appAbbrev/${systPFinstallActivelyRunning}"
}

unsetLocalRunningFlag(){
    # Sets running flag to "" in file in local machine's stage directory

    echo "" > "${stageDir}/$appAbbrev/${systPFinstallActivelyRunning}"
}

setRemoteMachineRunningStatus(){
    # Checks the systPFinstallActivelyRunning on the remote machine to see if the script is running

    remoteMachineRunningStatus=$(ssh oasis@$remoteMachine "cat $stageDir/$appAbbrev/$systPFinstallActivelyRunning")
    logEcho $remoteMachineRunningStatus
    
}

getRemotesystPFInstallActiveRunningFile(){
    # Obtains the systPFinstallActiveRunning file from remote machine and copies it to local machine with preserved timestamp

    scp -p oasis@$remoteMachine:/$stageDir/$appAbbrev/$systPFinstallActivelyRunning $stageDir/$appAbbrev/remotesystPFInstallActiveSince
}

verifyScriptOnlyRunningOnOneMachine(){
    # Check other machine’s stage directory for the flag to ensure the installation is only happening on one machine

    setRemoteMachineRunningStatus
    # If both machines have the runningFlag set to "Y"
    if [[ -n "$remoteMachineRunningStatus" ]]; then
        logEcho "${remoteMachine} is also running this script. Checking timestamps now"
        
        # Compare the timestamps
        getRemotesystPFInstallActiveRunningFile
        remoteFile="$stageDir/$appAbbrev/remotesystPFInstallActiveSince"
        remoteFileS=$(cat "$remoteFile")
        localFileS=$(cat "$stageDir/$appAbbrev/$systPFinstallActivelyRunning")

        logEcho "$remoteMachine started at ${remoteFileS}s since epoch"
        logEcho "$localMachine started script at ${localFileS}s since epoch"
        # If the local machine started running the script more recently than the remote machine, exit on local machine
        if [[ $localFileS -gt $remoteFileS ]]; then
            logEcho "${remoteMachine} started running script before the ${localMachine}. Exiting now."
            unsetLocalRunningFlag
            exit 0
        fi
    fi
    logEcho "${localMachine} started running script before the remote machine. Continuing with process"
        
}

setRemoteMachineJarExists(){
    # Sets the remoteMachineJarExists variable to the name of the Jar if it exists, empty otherwise

    remoteMachineJarName="$appName-$appVersion.jar"
    remoteMachineJarExists=$(ssh oasis@$remoteMachine ls $stagePath | grep $remoteMachineJarName || echo "")
    logEcho "RemoteMachineJarExists = $remoteMachineJarExists"
}

waitForStageOnBoth(){
    # Waits for staging on both machines
    
    # Wait until there is a Jar in the staging directory on the remote machine
    setRemoteMachineJarExists
    while [[ -z $remoteMachineJarExists ]]; do
        sleep 10
        setRemoteMachineJarExists
    done

}

waitForDowntimeOnBoth(){
    # Waits for dock to be unloaded on both machines

    waitUntilDockUnloadedLocally
    waitUntilDockUnloadedRemotely
}

callInstallScriptLocally(){
    # Calls the installScript.sh on the local machine with the passed arguments

    logEcho "Calling installJava script on $localMachine"
    
    script="$scriptPath -l $logFile -a $appAbbrev -u $timeout -g $goal -j $jarName $oldJarOptionString $callScriptsString $revertScriptsString"
    output=$($script)
    errorCode=$?
    if [[ $errorCode -ne 0  ]]; then
        logEcho "INSTALLATION FAILED ON $localMachine. EXITING NOW"
        exit 1
    fi
    logEcho ""
}

callInstallScriptRemotely(){
    # Calls the installScript.sh on the remote machine with the passed arguments

    logEcho "Calling installJava script on $remoteMachine"
    ssh oasis@$remoteMachine "$scriptPath -l $logFile -a $appAbbrev -u $timeout -g $goal -j $jarName $oldJarOptionString $callScriptsString $revertScriptsString"
    errorCode=$?
    if [[ "$errorCode" != 0  ]]; then
        logEcho "INSTALLTION FAILED ON $remoteMachine. EXITING NOW"
        exit 1
    fi
}

installAppOnBothVerifyDowntimeBetween(){
    # Installs app on both machines, verifiying the activity statuses on both machines

    # Reverify which machine is active (waiting for dock could have changed this)
    setLocalMachineActivityStatus
    setRemoteMachineActivityStatus
    ensureProperActvityStatuses

    # Call install script on inactive machine
    goal="install"
    if [[ $localMachineActivityStatus != "A" ]]; then

        # Call install script locally
        callInstallScriptLocally

        # Verfiy Dock hasn't been loaded on remote machine
        dockLoadedCheckRemotely
        if [[ -n $dockLoadedRemotely ]]; then
            # Call installScript.sh with parameters to enable a backout on local machine
            goal="backout"
            callInstallScriptLocally

            # Go back to waitForDowntime then try again
            waitForDowntimeOnBoth
            installAppOnBothVerifyDowntimeBetween

        else
            # Call install script remotely
            callInstallScriptRemotely
        fi

    else # Local machine is inactive
        
        # Call install script remotely
        callInstallScriptRemotely

        # Verify Dock hasn't been loaded on local machine
        dockLoadedCheckLocally
        if [[ -n $dockLoadedLocally ]]; then
            # Call installScript.sh with parameters to enable a backout on remote machine
            goal="backout"
            callInstallScriptRemotely

            # Go back to waitForDowntime then try again
            waitForDowntimeOnBoth
            installAppOnBothVerifyDowntimeBetween

        else
            # Call install script locally
            callInstallScriptLocally
        fi
    fi

}

installAppOnBoth(){
    # Installs app on both machines (does NOT check if a dock is loaded)

    # Reverify which machine is active (waiting for dock could have changed this)
    setLocalMachineActivityStatus
    setRemoteMachineActivityStatus
    ensureProperActvityStatuses

    # Call install script on inactive machine
    if [[ $localMachineActivityStatus != "A" ]]; then
        logEcho "Installing on $localMachine first"
       
        # Call installScript on local machine
        callInstallScriptLocally

        # Call installScript on remote machine
        callInstallScriptRemotely

    else 
        logEcho "Installing on $remoteMachine first"
        
        # Call installScript on remote machine
        callInstallScriptRemotely

        # Call installScript on local machine
        callInstallScriptLocally 

    fi

    # If we got here, then everything was a success!
}

installAppOnLocal(){
    # Installs the app on the local machine

    callInstallScriptLocally
}

useCase1(){
    # WAIT FOR FULL STAGING ON BOTH, WAIT FOR DOWNTIME ON BOTH, INSTALL ON BOTH

    # Need some additional variables set for the remote machine
    setRemoteVariables

    # Set running flag to “Y” in file in local machine’s stage directory
    setLocalRunningFlag

    # Verify script is only running on one machine
    verifyScriptOnlyRunningOnOneMachine

    # Wait for staging process on both machines
    waitForStageOnBoth

    # Wait for dock to be unloaded
    waitForDowntimeOnBoth
    
    # Start the installation process
    installAppOnBothVerifyDowntimeBetween

    # Set the local running flag to "N" in file on local machine's stage directory
    unsetLocalRunningFlag

}

useCase2(){
    # WAIT FOR FULL STAGING ON BOTH, THEN INSTALL IMMEDIATELY ON BOTH

    # Need some additional variables set for the remote machine
    setRemoteVariables

    # Set running flag to “Y” in file in local machine’s stage directory
    setLocalRunningFlag

    # Verify script is only running on one machine
    verifyScriptOnlyRunningOnOneMachine

    # Wait for staging process on both machines
    waitForStageOnBoth
    
    # # Start the installation process
    installAppOnBoth

    # # Set the local running flag to "N" in file on local machine's stage directory
    unsetLocalRunningFlag

}

useCase3(){
    # WAIT FOR DOWNTIME, THEN INSTALL ON LOCAL MACHINE ONLY

    # Wait for dock to be unloaded
    waitUntilDockUnloadedLocally

    # Install the app on the local machine
    installAppOnLocal
}

useCase4(){
    # INSTALL ON LOCAL MACHINE ONLY

    # Install app on local machine
    installAppOnLocal

}

main(){
    # Implements the main flow
    
    setLocalVariables

    # Call the corresponding use case depending on the majorGoal option
    case "${majorGoal}" in 
        1)
            logEcho "RUNNING SCRIPT WITH THE FOLLOWING USE CASE: WAIT FOR FULL STAGING ON BOTH, WAIT FOR DOWNTIME ON BOTH, INSTALL ON BOTH"
            printOptions
            useCase1
            ;;
        2) 
            logEcho "RUNNING SCRIPT WITH THE FOLLOWING USE CASE: WAIT FOR FULL STAGING ON BOTH, THEN INSTALL IMMEDIATELY ON BOTH" 
            printOptions
            useCase2
            ;;
        3)
            logEcho "RUNNING SCRIPT WITH THE FOLLOWING USE CASE: WAIT FOR DOWNTIME, THEN INSTALL ON LOCAL MACHINE ONLY"
            printOptions 
            useCase3
            ;;
        4)
            logEcho "RUNNING SCRIPT WITH THE FOLLOWING USE CASE: INSTALL ON LOCAL MACHINE ONLY" 
            printOptions
            useCase4
            ;;
        *)
            logEcho "ERROR! Please choose a valid use case!"
            logEcho ""
            usage ;;
    esac
    logEcho "INSTALLATION SUCCESS"
    exit 0
}

# SCRIPT OPTIONS
appVersion=""
appAbbrev="" 
timeout=120
majorGoal=""
declare -a scripts
declare -a revertScripts

# ALLOWS SCRIPT TO TAKE IN OPTIONS
scriptIndex=0
revertScriptIndex=0
while getopts l:v:a:t:c:r:m: flag; do
    case "${flag}" in
        l)
            logFile="${OPTARG}" ;;
        v)
            appVersion="${OPTARG}" ;;
        a)
            appAbbrev="${OPTARG}" ;;
        t) 
            timeout="${OPTARG}";;
        c)
            scripts[scriptIndex]="${OPTARG}" 
            ((scriptIndex=scriptIndex+1)) ;; 
        r)
            revertScripts[revertScriptIndex]="${OPTARG}" 
            ((revertScriptIndex=revertScriptIndex+1)) ;;
        m)
            majorGoal="${OPTARG}";;
        *)
            usage
            exit 1 ;;
    esac
done 


echo "Script starting"
sleep 1

main

