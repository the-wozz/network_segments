#!/bin/bash

# get 'network segments'/location
# what it do: gets the ip address of a machine and matches it against a list of known 'network segments' tied to a location [name]
# Author: Zachary 'Woz'nicki

# variables
version="1.1"
echo "Script version: $version" 
date="08/12/24"
echo "Last modified: $date"
# file containing all the network segments and locations. can be hosted online or locally but MUST BE in json format!
inputFile="https://raw.githubusercontent.com/the-wozz/network_segments/main/test.json"
# gets IP of currently in-use network device
ipAddress=$(/sbin/ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
# renames machine based on location, it prefixes the machine name with location-serialnumber | 1 = rename 0 = disabled
renameMachine=0
# enable more verbose logging to diagnose any possible issues
verboseMode=0 ;if [ $verboseMode -eq 1 ]; then echo "VERBOSE MODE: Enabled"; fi
# grabs serial number
serialNumber=$(/usr/sbin/system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
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
        if curl -o /dev/null -s -I -f "$inputFile"; then
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
# courtesy of Pedro Weinzettel from stackexchange for 'int_IP' function
int_IP() {
    OIFS=$IFS
    IFS='.'
    ip=($1)
    IFS=$OIFS
    echo "${ip[0]} * 256 ^ 3 + ${ip[1]} * 256 ^2 + ${ip[2]} * 256 ^1 + ${ip[3]} * 256 ^ 0" | bc
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
        locName=$(/usr/bin/plutil -extract "network_segments".$i."name" raw "$inputFile" | cut -d "(" -f2 | cut -d ")" -f1 )

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
### end functions

# SoS
    findNetworkSegment
echo "Location: $result"

    # this section renames a machine to the network segment name-serial number IF the 'renameMachine' variable is set to 1
    if [[ "$renameMachine" -eq 1 ]]; then
        echo "INFO: Rename Machine is ON!"

        locName=$(/usr/bin/plutil -extract "network_segments".$i."name" raw "$inputFile" | cut -d "(" -f2 | cut -d ")" -f1 )
            echo "Renaming machine to: $locName-$serialNumber"

            hostName=$(scutil --get HostName)
            if [[ $hostName == "$locName-$serialNumber" ]]; then
                echo "HostName = Good set!"
            else
                echo "HostName is NOT $locName-$serialNumber"
                echo "Setting 'HostName'..."
                scutil --set HostName "$locName-$serialNumber"
                    if [[ $hostName == "$locName-$serialNumber" ]]; then
                        echo "HostName = Good set!"
                    else
                        echo "HostName = NEEDS ATTENTION!"
                    fi
            fi
            computerName=$(scutil --get ComputerName)
            if [[ $computerName == "$locName-$serialNumber" ]]; then
                echo "ComputerName = Good set!"
            else
                echo "ComputerName is NOT $locName-$serialNumber"
                echo "Setting 'ComputerName'..."
                scutil --set ComputerName "$locName-$serialNumber"
                    if [[ $computerName == "$locName-$serialNumber" ]]; then
                        echo "ComputerName = Good set!"
                    else
                        echo "ComputerName = NEEDS ATTENTION!"
                    fi
            fi
            localHostName=$(scutil --get LocalHostName)
            if [[ $localHostName == "$locName-$serialNumber" ]]; then
                echo "LocalHostName = Good set!"
            else
                echo "LocalHostName is NOT $locName-$serialNumber"
                echo "Setting LocalHostName..."
                scutil --set LocalHostName "$locName-$serialNumber"
                    if [[ $localHostName == "$locName-$serialNumber" ]]; then
                        echo "LocalHostName = Good set!"
                    else
                        echo "LocalHostName = NEEDS ATTENTION!"
                    fi
            fi
    fi
    if [ "$removeLater" -eq 1 ]; then rm -rf "$temp_file"; fi
    exit 0
# EoS
