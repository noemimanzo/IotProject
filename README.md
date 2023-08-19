# How to run
	To ensure optimal visualization, it is recommended to clear the ThingSpeak graphs by following these steps. You can utilize the <a href="https://www.postman.com/">POSTMAN </a> site to experiment with HTTP requests via the ThingSpeak RESTful API. The HTTP request format for deletion is as follows:
	DELETE https://api.thingspeak.com/channels/4/feeds.json
       api_key=XXXXXXXXXXXXXXXX
       
    1. In POSTMAN, select DELETE from the drop-down list of HTTP verbs.
	2. In the address bar, enter https://api.thingspeak.com/channels/<channelID>/feeds.json, replacing <channelID> with the ID of the channel you want to clear (in our case is 2227986).
	3. Under the Body, choose x-www-form-urlencoded.
	4. Enter the parameter api_key and your user API Key, which is found in Account > My Profile. 
	
	After completing the above steps, proceed with the following instructions:
	1. Cloning the repository and navigate to the directory using the terminal
	''' 
		git clone 
		cd 
	'''
	2. Execute the simulation
	'''
		make micaz sim 
	'''
	3. open node-red and import the flow contents in the clipboard "NAME OF CLIP"
	4. Launch the simulation by running
	''' 
		python RunSimulationScript.py
	'''
	Node-RED will receive messages, parse them, and transmit the data to ThingSpeak every 15 seconds. The collected data will become visible on your specified channel.
	
	**IMPORTANT:**To ensure proper functionality, Node-RED must remain active throughout the simulation. It is crucial to start Node-RED before initiating the simulation process.
	
	Our last simulation is contained in the file _TOSSIM___LOG.txt_ and the public channel is available at the <a href="https://thingspeak.com/channels/2227986">ThingSpeak channel</a>
	
