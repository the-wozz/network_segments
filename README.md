What this does: 
Grabs the IP of the machine and compares it to a JSON file of 'network segments' to check where the device is located.

Editable variables:
MODIFY Line 13; inputFile="LOCAL FILE OR URL" to either a local .json file or an online location that ends in .json format (like GitHub Raw)

This script will run checks for [on both options]: 
+ if inputFile variable is NOT blank
+ if file is in .json format (exits if not)

When 'Local File' is provided:
+ if file exists

When 'Online File' is provided:
+ if URL is valid by testing
