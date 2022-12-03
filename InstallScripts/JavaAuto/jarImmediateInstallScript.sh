#!/bin/bash

#/****************************************************************************************/
#/*                                 PROPERTY OF FEDEX                                     /
#/*                                                                                       /
#/* PROGRAM: jarImmediateInstallScript.sh (SHOULD NOT BE CALLED DIRECTLY!)                /
#/* DESCRIPTION: Script that installs jar on current machine.                             /
#/*        Kills the old jar, starts the new one, waits to ensure jar stays running,      / 
#/*        and safely backouts to previous working state when any errors occur            /
#/                                                                                        /
#/                                                                                        /
#/* DATE WRITTEN: 02/2021                                                                 /
#/* DEPENDENCIES: Gets called by jarDowntimeInstallScript.sh                              /
#/* AUTHORS: Matt Cole, Chris Mazur                                                       /
#/*                                                                                       /
#/*                                                                                       /
#/****************************************************************************************/



usage(){
    # Prints out the options that the script takes in

    echo   "Usage: [-l <logLocation>][-a <appAbbrev>][-j <jarName>][-o <oldJarName>][-g <goal>][-c <callScript>][-r <revertScript][-u <uptimeToWaitFor>]"
    echo   "    -l  location to log output to (defaults to logfile)"
    echo   "    -a  app abbreviation (REQUIRED)"
    echo   "    -j  new jar to install (REQUIRED)"
    echo   "    -o  previous working jar (if applicable)"
    echo   "    -g  goal of the script (Install || Backout)"
    echo   "    -c  script to call. Can specify multiple"
    echo   "    -r  revert script. Can specify multiple"
    echo   "    -u  uptime to wait for new jar running (defaults to 120)"
}

printArguments(){
    # Prints all the arguments passed into the script

    logEcho ""
    logEcho "installScript IS NOW RUNNING WITH THE FOLLOWING ARGUMENTS: "
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

logEcho(){
    # Logs all arguments passed with a timestamp

    echo "$@"
    if [[ ! -e $(dirname "$logFile") ]]; then
        mkdir -p $(dirname "$logFile")
    fi
    echo "Immediate Script - $(date) - $*" >> "$logFile"
}

exitIfError(){
    # Exits the script if an error occurs
    
    errorCode=$1
    if [[ $errorCode -ne 0 ]]; then
        logEcho "Encountered Error Code $errorCode"
        backout
        exit $errorCode
    fi
}

moveJar(){
    # Moves the Jar from the staging directory to the jars directory
    
    logEcho "Moving ${jarName} from ${stagePath} to ${jarsDir}"
    if mv $stagePath/$jarName $jarsDir ; then
        logEcho "${jarName} moved successfully"
        return 0
    else
        logEcho "Failed to move ${jarName}. Exiting now"
        return 1
    fi
}

killJar(){
    # Turns off the old application 

    # Try to gracefully kill with systCsystemStop
    logEcho "SystemStopping the jar"
    /opt/fedex/iss/bin/servers/systCsystemStop $appNameAndInstanceNum
    sleep 10

    logEcho "Waiting for app to shut down..."

    # Check to see if the app is still running. If it is, obtain the PID and force-kill it
    setAppPID
    if [[ -n $appPID ]] ; then
        logEcho "App was not killed gracefully, force killing it now"
        kill -9 "$appPID"
    fi

    logEcho "App has been successfully killed"
    
}

executeCallScripts(){
    # Executes all the call scripts specified in the options

    logEcho "Executing call scripts..."
    for callScript in "${callScripts[@]}"
    do
        logEcho "Executing '${callScript}' ..."
        $callScript
        callScriptsErrorCode=$?
        if [[ $callScriptsErrorCode -ne 0 ]]; then
            return $callScriptsErrorCode
        fi
    done
    return 0
}

updateLink(){
    # Updates the link for the given abbreviation to the new version in the jars directory

    cd $jarsDir
    if ln -sf $jarsDir/$jarName $appName  ; then
        logEcho "Link updated to new version of Jar"
        return 0
    else
        logEcho "Failed to update link to new version of Jar. Exiting now"
        return 1
    fi
}

startJar(){
    # Starts running the desired jar

    setLineFromSystPFServerApps
    setProgram

    if [[ -z "$lineFromSystPFServerApps" ]]; then
        logEcho "Line from systPFserverApps is empty, must fail!"
        exitIfError 1
    fi

    logEcho "Starting program with command '$program'"
    nohup ${program} >/dev/null 2>&1 &
}

startOldJar(){

    # Starts running the previous working jar

    setLineFromSystPFServerApps
    setProgram

    if [[ -z "$lineFromSystPFServerApps" ]]; then
        logEcho "Line from systPFserverApps is empty, old jar could not be started."
        exit 1
    fi

    nohup ${program} >/dev/null 2>&1 &
}

startOldJar(){

    # Starts running the previous working jar

    setLineFromSystPFServerApps
    setProgram

    if [[ -z "$lineFromSystPFServerApps" ]]; then
        logEcho "Line from systPFserverApps is empty, old jar could not be started."
        exit 1
    fi

    nohup ${program} >/dev/null 2>&1 &
}

startOldJar(){

    # Starts running the previous working jar

    setLineFromSystPFServerApps
    setProgram

    if [[ -z "$lineFromSystPFServerApps" ]]; then
        logEcho "Line from systPFserverApps is empty, old jar could not be started."
        exit 1
    fi

    nohup ${program} >/dev/null 2>&1 &
}



setAppUptime(){
    # Sets the uptime for the application using the process checker (saves it in total seconds)

    setLineFromSystPFServerApps
    setAppPIDAndKillIfEmptyOrLarge

    fullappUptime=$(ps -p "$appPID" -o etime= | awk '{print $1;}')
    appUptimeMins=$(echo "$fullappUptime" | cut -d ":" -f 1)
    appUptimeSecs=$(echo "$fullappUptime" | cut -d ":" -f 2)
    sleep 5

    appUptime=$(( appUptimeMins*60 + appUptimeSecs ))

    logEcho "App is running with pid $appPID and has been running for ${appUptimeMins}:${appUptimeSecs}"

}

setProgram(){
    # Sets the program variable
    program=$(echo $lineFromSystPFServerApps | cut -f4- -d " ")
    logEcho "program: $program"
}

waitForJarUptime(){
    sleep 2
    setAppUptime
    prevAppUptime=$appUptime

    interval=10
    while true
    do
        sleep $interval
        setAppUptime
        if [[ ${appUptime} -lt ${prevAppUptime} ]]; then
            # App died and was restarted at some point
            logEcho "Application has died during the startup period, beginning backout"
            return 2
        elif [[ ${appUptime} -ge ${uptimeToWaitFor} ]]; then
            logEcho "App stayed running for at least ${uptimeToWaitFor} seconds. Moving on with process"
            return 0
        fi
        prevAppUptime=$appUptime

    done
}

revertLink(){
    # Reverts the link back to the old app

    cd $jarsDir
    ln -sf $jarsDir/$oldJarName $appName 
}

removeLink(){
    # Removes the link to the jar in the jars directory

    cd $jarsDir
    rm "$appName"
}

executeRevertScripts(){
    # Executes any revert scripts
    
    logEcho "Executing revert scripts..."
    for revertScript in "${revertScripts[@]}"
    do
        logEcho "Executing '${revertScript}' ..."
        $revertScript
        revertScriptsErrorCode=$?
        if [[ $revertScriptsErrorCode -ne 0 ]]; then 
            return 1
        fi
    done
    return 0
}

revertJarToStage(){
    # Moves the jar back to the stage directory


    mv $jarsDir/$jarName $stagePath
}

revertOldJarFromOld() {
    # Moves the archived old jar back to the jars directory

    if [[ "$oldJarName" != "$jarName" && -e "/opt/fedex/iss/bin/jars/old/$appAbbrev/$oldJarName" ]]; then
        logEcho "Moving $oldJarName back to .../jars"
        mv "/opt/fedex/iss/bin/jars/old/$appAbbrev/$oldJarName" "/opt/fedex/iss/bin/jars"
    else
        logEcho "oldJarName matches newly installed jar name, or was absent, should never have been moved to old"
    fi
}

backout(){
    # Reverts the machine to the state it was in before the installation attempt

    backoutAndStartOldJar(){
        # Backs out of the installation and reverts everything back to the previous working state

        logEcho "Reverting back to previous jar"

        # Kill the app (just in case it is still running)
        killJar

        # Reverts link back to the old Jar
        revertLink

        # Execute revert scripts
        executeRevertScripts

        # Revert new jar back to stage dir
        revertJarToStage

        # Revert old jar from .../jars/old
        revertOldJarFromOld

        # Start old Jar
        startOldJar
    }

    backoutWithoutOldJar(){
        # Makes it seem like the installation attempt never even happened

        logEcho "Backing out with no old jar"
        # Kill jar in case it is still running
        killJar

        # Remove link 
        removeLink

        # Execute any revert scripts
        executeRevertScripts

        # Move jar back to the stage directory
        revertJarToStage
    }

    # Determine which backout to run depending on whether there was a jar running before the installation
    if [[ -z "$oldJarName" ]];
    then
        backoutWithoutOldJar
    else
        backoutAndStartOldJar
    fi
}

setAppPID(){
    # Sets the appPID variable by checking the process checker

    appPID=$(ps -eaf | grep "$program" | grep -v jarDowntimeInstallScript | grep -v jarImmediateInstallScript | grep -v grep | grep -v tail | awk '{print $2}')
}

setAppPIDAndKillIfEmptyOrLarge() {
    logEcho "Grepping for program '$program'"
    appPID=$(ps -eaf | grep "$program" | grep -v jarDowntimeInstallScript | grep -v jarImmediateInstallScript | grep -v grep | grep -v tail | awk '{print $2}')
    numLinesPID=$(echo "$appPID" | wc -l)
    if [[ -z "$appPID" ]]; then
        logEcho "App PID empty - must fail!"
        exitIfError 1
    elif [[ $numLinesPID -gt 1 ]]; then
        logEcho "Multiple APP PID's detected - must fail"
        exitIfError 1
    fi
}

setVariables(){
    # Sets some necessary global variables
    
    setStagePath(){
        stagePath="${stageDir}${appAbbrev}"
    }

    setAppName(){
        # Sets the full application name based of of the abbreviation

        appName="${appNames[$appAbbrev]}"
    }

    setAppNameAndInstanceNumber(){
        # Gets and sets the app name and instance number from /var/fedex/iss/common/systPFserverApps

        appNameAndInstanceNum="$(grep $appName /var/fedex/iss/common/systPFserverApps | awk '{print $1;}')1"
    }

    setLineFromSystPFServerApps(){
        # Sets the lineFromSystPFServerApps variable

        lineFromSystPFServerApps=$(grep $appName /var/fedex/iss/common/systPFserverApps)
        logEcho "lineFromSystPFServerApps: $lineFromSystPFServerApps"
    }

    setProgram(){
        # Sets the program variable
        program=$(echo $lineFromSystPFServerApps | cut -f4- -d " ")
        logEcho "Program $program"
    }

    activateOasisProfile(){
    # Loads .profile for oasis
    #   This allows the shell to have access to oasis-specific variables such as ORACLE_HOME

    chmod 755 /home/oasis/.profile 
    . /home/oasis/.profile;
    }   

    setLogFile(){
        # Sets the logFile in case it wasn't specified

        if [[ -z "$logFile" ]]; then
            logFile="/var/fedex/iss/logs/installs/jar_install_${appAbbrev}_${appVersion}.log"
        fi
    }

    # CONSTANTS
    stageDir="/opt/fedex/iss/bin/stage/"
    jarsDir="/opt/fedex/iss/bin/jars"

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
        ["ldap"]="ldap-service"
        ["ncscan"]="nc-scan-service"
        )

    # Placeholders global variables to be filled in later
    stagePath=""                # Path to the stage directory
    appName=""                  # Full application name 
    appNameAndInstanceNum=""    # App name and instance number from /var/fedex/iss/common/systPFserverApps
    appPID=""                   # Process ID for the app
    lineFromSystPFServerApps="" # The specific line related to the app from systPFserverApps
    program=""                  # Line to use to start the app
    appUptime=""                # Holds the total seconds the app has been running for
    
    # Call some functions to set variables as needed
    setStagePath
    setAppName
    setAppNameAndInstanceNumber
    setLineFromSystPFServerApps
    setProgram
    setLogFile
    activateOasisProfile
}

removeOldJar() {
    mkdir -p "/opt/fedex/iss/bin/jars/old/${appAbbrev}"
    if [[ "$oldJarName" != "$jarName" && -e "/opt/fedex/iss/bin/jars/$oldJarName" ]]; then
        logEcho "Moving $oldJarName to .../jars/old/$appAbbrev"
        mv "/opt/fedex/iss/bin/jars/$oldJarName" "/opt/fedex/iss/bin/jars/old/${appAbbrev}"
    else
        logEcho "oldJarName matches newly installed jar name, or was absent, not moving to old"
    fi
}

setLineFromSystPFServerApps(){
    # Sets the lineFromSystPFServerApps variable

    lineFromSystPFServerApps=$(grep $appName /var/fedex/iss/common/systPFserverApps)
    logEcho "Line from systPFServerApps: $lineFromSystPFServerApps"
}

main(){
    setVariables
    
    if [[ $goal == "install" ]]; then
        
        # Copy Jar from staging
        moveJar
        exitIfError $?

        # Kill Old Jar if one exists
        killJar

        # Run call scripts
        executeCallScripts
        exitIfError $?

        # Point Link
        updateLink
        exitIfError $?

        # Start New Jar
        startJar
        
        # Wait for jar's uptime to reach uptimeToWaitFor
        waitForJarUptime
        exitIfError $?

        removeOldJar

        # Exit        

        logEcho "INSTALLATION COMPLETE"
        logEcho ""
        exit 0

    else # goal == backout

        backout
    fi
    exit 0
}

# SCRIPT OPTION DEFAULTS
appAbbrev=""                # App abbreviation (dmt, cls, etc.)
goal=""                     # Goal of script (install || backout)
jarName=""                  # Name of the jar to install
oldJarName=""               # Name of the previous working jar
uptimeToWaitFor=120         # Amount of time to wait to ensure app does not crash
declare -a callScripts      # Additional callable scripts that may be necessary for installations
declare -a revertScripts    # Additional callable scripts that may be necessary for backing out of an installation (basically reverts call scripts)

# ALLOWS SCRIPT TO TAKE IN OPTIONS
callScriptIndex=0
revertScriptIndex=0
while getopts l:v:a:t:c:r:g:u:o:j: flag; do
    case "${flag}" in
        l)
            logFile="${OPTARG}" ;;
        a)
            appAbbrev="${OPTARG}" ;;
        j)
            jarName="${OPTARG}" ;;
        o)
            oldJarName="${OPTARG}" ;;
        g)
            goal="${OPTARG}" ;;
        c)
            callScripts[callScriptIndex]="${OPTARG}" 
            ((callScriptIndex=callScriptIndex+1)) ;; 
        r)
            revertScripts[revertScriptIndex]="${OPTARG}" 
            ((revertScriptIndex=revertScriptIndex+1)) ;;
        u)
            uptimeToWaitFor="${OPTARG}" ;;
        *)
            usage
            exit 1 ;;
    esac
done



logEcho ""
logEcho ""
printArguments
main
logEcho ""
logEcho ""


