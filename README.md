## What this does:<br>
Grabs the IP of the machine and compares it to a JSON file of 'network segments' to check where the device is located and 'echoes' the location. The idea behind this is to be able to export the 'Network Segments' from Jamf Pro and use that same information elsewhere. 

# How to Use<br>
## Editable variables:<br>
MODIFY Line 13: inputFile="LOCAL FILE OR URL" <br>to either a local .json file or an online location that ends in .json format (like GitHub Raw)

## JSON File Format:<br>
The JSON format is the exact same format exported from Jamf Pro (via API) to make use of this tool easier. Make sure each id, name, starting and ending address' are all unique!
<br><br>
Example below:<br><br>
`{
  "network_segments": [
    {
      "id": #,
      "name": "LOCATION NAME",
      "starting_address": "x.x.x.x",
      "ending_address": "x.x.x.x"
    }
  ]
}`

### This script will run checks for [on both options]: 
+ if inputFile variable is NOT blank
+ if file is in .json format (exits if not)

### - When 'Local File' is provided:
+ if file exists

### - When 'Online File' is provided:
+ if URL is valid by testing
