# Blusound Node 2 API Notes

These are my notes from investigating how the BluOS controller app inteacts with the Node 2 streamer.

## Endpoint Discovery

Node 2 [and presumably other compatible devices like the Node, Power Node and Vault] are exposed via mDNS / Bonjour. search for the _musc._tcp service.
see this thread https://helpdesk.bluesound.com/discussions/viewtopic.php?f=19&t=2594&sid=95050cc6b07151bbec98e3886935bf97

## Endpoint API

Discovery returns a service on port 11100, a look at the node 2 diagnostic output from the app, and some wireshark runs, show this is a HTTP service. Endpoints seem to return xml, or image binary data, and support gzip compression. It unfortuantly doesn't use HTTP all that well [GETs that have side-effects, lack of useful caching headers], no doubt leading to the artwork caching problems in the desktop app.


 * /SyncStatus returns high level info about the device, e.g.
 
    curl http://192.168.1.45:11000/SyncStatus
 
    ```<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
	    <SyncStatus icon="/images/players/N110_nt.png" 
		            volume="-1" 
					modelName="NODE 2" 
					name="Cave" 
					model="N110" 
					brand="Bluesound" 
					etag="3" 
					schemaVersion="15" 
					syncStat="3" 
					id="192.168.1.45:11000" 
					mac="90:56:82:3F:AA:A0">
		</SyncStatus>```
		
 * /Status returns detailed information about what the device is currently doing
 
    curl http://192.168.1.45:11000/Status

	```<?xml version="1.0" encoding="UTF-8" standalone="yes"?><status etag="ab5306d5f830e473252a22f5102df62d">
	<album>John Digweed Live in London</album>
	<artist>Phonogenic</artist>
	<canMovePlayback>true</canMovePlayback>
	<canSeek>1</canSeek>
	<cursor>92</cursor>
	<fn>/var/mnt/ANDROMEDA-music/iTunes/Music/Compilations/John Digweed Live in London/3-09 Tired Being.m4a</fn>
	<image>/Artwork?service=LocalMusic&amp;fn=%2Fvar%2Fmnt%2FANDROMEDA-music%2FiTunes%2FMusic%2FCompilations%2FJohn%20Digweed%20Live%20in%20London%2F3-09%20Tired%20Being.m4a</image>
	<indexing>0</indexing>
	<mid>10</mid>
	<mode>1</mode>
	<name>Tired Being</name>
	<pid>60</pid>
	<prid>0</prid>
	<quality>cd</quality>
	<repeat>2</repeat>
	<service>LocalMusic</service>
	<shuffle>0</shuffle>
	<sid>15</sid>
	<sleep></sleep>
	<song>71</song>
	<state>play</state>
	<syncStat>3</syncStat>
	<title1>Tired Being</title1>
	<title2>Phonogenic</title2>
	<title3>John Digweed Live in London</title3>
	<totlen>170</totlen>
	<volume>-1</volume>
	<secs>6</secs>
	</status>```
	
	this also takes an etag querystring param, and timeout value [not an HTTP header], this appears to provide a blocking get until there's a status change.
	
	curl "http://192.168.1.45:11000/Status?etag=1117370c37d450a8322e05f51358a0a4&timeout=60"
	
	
 * /Play & /Pause will cause the player to start or stop the current play queue, it returns the new state of the player
 
    curl http://192.168.1.45:11000/Play
 
    ```<?xml version="1.0" encoding="UTF-8" standalone="yes"?><state>play</state>``` 

    specifying an ID parameter will change the song being played, id appears to be a zero based index into the play queue.
	
	curl http://192.168.1.45:11000/Play?id=2

 * /Back and /Skip will go backward or forward one track.
 
 * /Shuffle?state=1 turns shuffle on, state=0 turns it off.
 
 * /Services returns details about the available sources for node, local library, internet radio services etc, this would seem to drive the main part of the UI.

 * /Presets
 
 * /GitVersion returns the version of the software on the devices? (this returns 2.8.3 for my node 2)
 
 * /Playlist returns the Play Queue 
 
 * /Clear deletes all the play queue entries
 
 * /Delete?id=x deletes an entry from the play queue, id is the zero offset into the play queue.
 
 * /Songs returns more detailed information about an album e.g.
 
        /Songs?service=LocalMusic&album=Waiting%20for%20the%20Sirens%27%20Call&artist=New%20Order
	
returns

	<?xml version="1.0" encoding="UTF-8" standalone="yes"?><songs service="LocalMusic" id="13">
	<album time="3804" quality="cd">
	<song>
	<track>1</track>
	<discno>1/1</discno>
	<title>Who's Joe?</title>
	<art>New Order</art>
	<alb>Waiting for the Sirens' Call</alb>
	<composer>New Order</composer>
	<fn>/var/mnt/ANDROMEDA-music/iTunes/Music/New Order/Waiting For The Sirens' Call/01 Who's Joe_.m4a</fn>
	<time>344</time>
	<date>2005</date>
	<quality>cd</quality>
	</song>
	<song>....
	
 * /Add adds items to the play queue and starts them, e.g.
 
 		 Play Now
	     /Add?playnow=1&where=nextAlbum&service=LocalMusic&album=%2A%2A%2Ak%20the%20Millenium&artist=The%20KLF
 
 		 Add Next
		 /Add?playnow=-1&where=nextAlbum&service=LocalMusic&album=Vs.%20T-World%20-%202000&artist=GusGus
		 
		 Play Last
		 /Add?playnow=-1&where=last&service=LocalMusic&album=Waiting%20for%20the%20Rights%20of%20Mu&artist=The%20KLF 
		 		 
		 
 * /Artwork returns the cover artwork for a specified album/artist,
 
		 GET /Artwork?service=LocalMusic&album=10%20Years%20%5BDisc%202%5D&artist=Banco%20De%20Gaia HTTP/1.1
		 Connection: Keep-Alive
		 Accept-Encoding: gzip, deflate
		 Accept-Language: en-US,*
		 User-Agent: Mozilla/5.0
		 Host: 192.168.1.45:11000

		 HTTP/1.0 200 ok
		 Connection: Keep-Alive
		 Access-Control-Allow-Origin: *
		 Content-Length: 36266
		 Cache-Control: max-age=0
		 Content-Type: image/jpeg
		 Date: Sun, 27 Nov 2016 21:33:58 GMT
		 Expires: Sun, 27 Nov 2016 21:33:58 GMT
		 
  Support topics seem to indicate that the node has local copies of the artwork in its internal index, which is only rebuilt on user command, its a pity it doesn't provide better caching headers for the artwork endpoint [like an etag]
  