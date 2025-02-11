#!/bin/bash

# get 'network segments'/location
# what it do: gets the ip address of a machine and matches it against a list of known 'network segments' tied to a location [name]
# Author: Zachary 'Woz'nicki

# variables
version="1.6"
echo "Script version: $version" 
date="02/11/25"
echo "Last modified: $date"
# file containing all the network segments and locations. can be hosted online or locally but MUST BE in json format!
inputFile="https://raw.githubusercontent.com/the-wozz/network_segments/main/test.json"
# gets IP of currently in-use network device
ipAddress=$(/sbin/ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
# renames machine based on location, it prefixes the machine name with location-serialnumber | 1 = rename 0 = disabled
renameMachine=1
# enable more verbose logging to diagnose any possible issues
verboseMode=0 ;if [ $verboseMode -eq 1 ]; then echo "VERBOSE MODE: Enabled"; fi
# grabs serial number
serialNumber=$(/usr/sbin/system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
# set Swift Dialog icon
swiftIcon=""
# Swift Dialog location (default)
swiftDialogBin=/usr/local/bin/dialog
# Swift Dialog Github URL (always check for latest https://github.com/swiftDialog/swiftDialog/releases/ )
swiftDialogURL="https://github.com/swiftDialog/swiftDialog/releases/download/v2.5.5/dialog-2.5.5-4802.pkg"
# end variables

## extra processing
    if [[ -z $inputFile ]]; then
        echo "ERROR: No input file!"
        exit 1
    fi 

    if [[ "$inputFile" != *.json ]]; then
        echo "ERROR: File is NOT in JSON format!"
        exit 1
    fi

    if [[ "$inputFile" =~ https:// ]]; then
        echo "INFO: URL detected in inputFile! Processing..."
        echo "Checking URL: $inputFile"
            sleep 3
        if /usr/bin/curl -o /dev/null -s -I -f "$inputFile"; then
            echo "PASS: URL valid!"
        else
            echo "ERROR: URL unreachable!"
            exit 1
        fi

        temp_file=/tmp/ips.json
            removeLater=1
        if [ -e $temp_file ]; then
            rm -rf "$temp_file"
                wait
            echo "INFO: Found previous temp_file and removed."
        fi
        # downloading json file and storing locally
        curl -s $inputFile >> $temp_file
            wait
        inputFile=$temp_file
    else
        echo "INFO: Treating 'inputFile' as local file."
        removeLater=0
        if [[ ! -e $inputFile ]]; then
            echo "ERROR: File does not exist!"
            exit 1
        fi 
    fi
## end extra processing

### functions

# grabs the current IP
# courtesy of Pedro Weinzettel from stackexchange for 'int_IP' function
int_IP() {
    OIFS=$IFS
    IFS='.'
    ip=($1)
    IFS=$OIFS
    echo "${ip[0]} * 256 ^ 3 + ${ip[1]} * 256 ^2 + ${ip[2]} * 256 ^1 + ${ip[3]} * 256 ^ 0" | bc
}

# checks if Swift Dialog is installed AND the version desired, if older, deletes and then calls the download function
swiftDialogCheck() {
    echo "* SWIFT DIALOG CHECK *"
        if [[ ! -e "$swiftDialogBin" ]]; then
            echo "Swift Dialog NOT FOUND! Unable to prompt user."
        else
            echo "INITIAL CHECK PASSED: Swift Dialog found. Checking version..."
            swiftDInstalledVersion=$("$swiftDialogBin" --version | cut -c1-5)
            echo "Swift Dialog version: $swiftDInstalledVersion"
                if [[ "$swiftDInstalledVersion" < "$swiftVersion" ]]; then
                    echo "Swift Dialog version too old! $swiftVersion required."
                            # these commands make sure that any currently open Swift Dialog prompt is closed
                            /bin/echo quit: >> /var/tmp/dialog.log
                            pkill -f dialog
                            echo "Using Github as download source"
                            downloadSwiftDialog
                                #wait
                            #echo "*** ERROR: Unable to prompt user because of Swift Dialog failure above ***"
                            #exit 1
                else
                    echo "* Swift Dialog version PASSED *"
                fi
        fi
}

# downloads Swift Dialog via GitHub
downloadSwiftDialog(){
    echo "* SWIFT DIALOG: Flagged for DOWNLOAD! *"

    if [[ -n "$swiftDialogURL" ]]; then
        echo "SWIFT DIALOG: URL Provided: $swiftDialogURL"

        local filename
            filename=$(basename "$swiftDialogURL")
        local temp_file
            temp_file="/tmp/$filename"
        previous_umask=$(umask)
        umask 077

        /usr/bin/curl --retry 5 --retry-max-time 120 -Ls "$swiftDialogURL" -o "$temp_file" 2>&1
            if [[ $? -eq 0 ]]; then
                echo "SWIFT DIALOG: DOWNLOADED successfully! Installing..."
                        /usr/sbin/installer -verboseR -pkg "$temp_file" -target / 2>&1
                            if [[ $? -eq 0 ]]; then
                                echo "SWIFT DIALOG: INSTALLED!"
                            else
                                echo "**** ERROR: SWIFT DIALOG: Unable to instal! Can NOT continue! Exiting... *****"
                                exit 1
                            fi

                rm -Rf "${temp_file}" >/dev/null 2>&1
                umask "${previous_umask}"
                return
            else
                echo "**** ERROR: SWIFT DIALOG: Download FAILED!! Can NOT continue! Exiting... *****"
                exit 1
            fi
    else
        echo "* SWIFT DIALOG: ERROR: NO swiftDialogURL provided! *"
        echo "Exiting..."
        exit 1
    fi
}

# loop to go through all individual entries in the input file
findNetworkSegment() {
    echo "IP: $ipAddress"
    # counts the number of entries to go through
    index=$(/usr/bin/plutil -extract network_segments raw "$inputFile")

    echo "STATUS: Going through stored 'network segments'..."
    for ((i=0; i < index; i++)); do
        iD=$(/usr/bin/plutil -extract "network_segments".$i."id" raw "$inputFile")
            if [ $verboseMode -eq 1 ]; then echo "id: $iD"; fi
        name=$(/usr/bin/plutil -extract "network_segments".$i."name" raw "$inputFile")
            #echo "name: $name"
        ipRangeMin=$(/usr/bin/plutil -extract "network_segments".$i."starting_address" raw "$inputFile")
            #echo "starting_address: $ipRange"
        ipRangeMax=$(/usr/bin/plutil -extract "network_segments".$i."ending_address" raw "$inputFile")
            #echo "ending_address: $ipRange2"

            ipMin=$(int_IP "$ipRangeMin")
            ipMax=$(int_IP "$ipRangeMax")
            intIP=$(int_IP "$ipAddress")

            if [[ "$intIP" -le "$ipMax" ]] && [[ "$intIP" -ge "$ipMin" ]]; then
                echo "***** IP RANGE FOUND! *****"
                echo "id: $iD"
                #echo "name: $name" # shown at EOS as $result
                if [ $verboseMode -eq 1 ]; then echo "starting_address: $ipRangeMin"; echo "ending_address: $ipRangeMax"; fi
                result="$name"
                break
            fi
    done # end loop
}

# renames a machine to the network segment name-serial number IF the 'renameMachine' variable is set to 1
renameMachineFunc() {
    if [[ "$renameMachine" -eq 1 ]]; then
        echo "INFO: Rename Machine is ON!"
        
        # gathering Location Short Name
        locName=$(/usr/bin/plutil -extract "network_segments".$i."name" raw "$inputFile" | cut -d "(" -f2 | cut -d ")" -f1 )
            echo "Location short name: $locName"
                echo "Location Short Name Legnth: ${#locName}"
                if [ ${#locName} != 4 ]; then
                    echo "ERROR: 'Location Name (locName)' too big! Prompting user for location via Swift Dialog..."
                    locName=$($swiftDialogBin -i "$swiftIcon" -o -p --small -t "Location Name" --messagefont size="15" -m "Input location name in 4 characters or less." --alignment center --textfield "",required,regex="^[A-Z]{4}$",regexerror="Location MUST be 4 LETTERS and ALL CAPITAL." --buton1text "Submit")
                        case $? in
                        0)
                            echo "User inputted location: $locName"
                            # OLD LOGIC used to determine if variable was too long WITHOUT regex (= x_x)
                            # if [ "${#newName}" -ge 5 ]; then
                            #     echo "*** ERROR : New name TOO LONG! ***"
                            #     renameMachineFunc
                            # else
                            #     echo "NEW Location: $newName"
                            #     return
                            # fi
                        ;;
                        2)
                            echo "User pressed Exit button"
                            exit 0
                        ;;
                        *)
                            echo "Something unexpected occured"
                            exit 1
                        ;;
                    esac
                else 
                    echo "STATUS: Good location name!"
                fi

        # gather if machine is a laptop or desktop
        machineType=$(/usr/sbin/system_profiler SPHardwareDataType | grep 'Model Name: ' | tr -d " \t\n\r" | cut -d ':' -f 2)
            if [[ $machineType =~ .*Book.* ]]; then
                echo "INFO: Machine is a 'Laptop'! Prefixing with 'LM'..."
                prefix=LM
            else
                echo "INFO: Machine is a 'Desktop'! Prefixing with 'DM'..."
                prefix=DM
            fi

            echo "Renaming machine to: $prefix$locName$serialNumber"

        # check and rename of all the proper 'names (host name, computer name, and local host name)'
            hostName=$(/usr/sbin/scutil --get HostName)
            if [[ $hostName == "$prefix$locName$serialNumber" ]]; then
                echo "HostName = Good set!"
            else
                echo "HostName is NOT $prefix$locName$serialNumber"
                echo "Setting 'HostName'..."
                /usr/sbin/scutil --set HostName "$prefix$locName$serialNumber"
                sleep 1
                    if [[ $hostName == "$prefix$locName$serialNumber" ]]; then
                        echo "HostName = Good set!"
                    else
                        echo "HostName = NEEDS ATTENTION!"
                    fi
            fi
            computerName=$(/usr/sbin/scutil --get ComputerName)
            if [[ $computerName == "$prefix$locName$serialNumber" ]]; then
                echo "ComputerName = Good set!"
            else
                echo "ComputerName is NOT $prefix$locName$serialNumber"
                echo "Setting 'ComputerName'..."
                /usr/sbin/scutil --set ComputerName "$prefix$locName$serialNumber"
                sleep 1
                    if [[ $computerName == "$prefix$locName$serialNumber" ]]; then
                        echo "ComputerName = Good set!"
                    else
                        echo "ComputerName = NEEDS ATTENTION!"
                    fi
            fi
            localHostName=$(/usr/sbin/scutil --get LocalHostName)
            if [[ $localHostName == "$prefix$locName$serialNumber" ]]; then
                echo "LocalHostName = Good set!"
            else
                echo "LocalHostName is NOT $prefix$locName$serialNumber"
                echo "Setting LocalHostName..."
                /usr/sbin/scutil --set LocalHostName "$prefix$locName$serialNumber"
                sleep 1
                    if [[ $localHostName == "$prefix$locName$serialNumber" ]]; then
                        echo "LocalHostName = Good set!"
                    else
                        echo "LocalHostName = NEEDS ATTENTION!"
                    fi
            fi
    fi
}
### end functions

# Start of Script
swiftDialogCheck
    findNetworkSegment
echo "Location: $result"
    renameMachineFunc

    if [ "$removeLater" -eq 1 ]; then rm -rf "$temp_file"; fi
    exit 0
# End of Script
