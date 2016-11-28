# BluShepherd

BlueSound make a range of Hi-Fi components, including the "Node 2" a streamer [internet radio, local mp3s,flacs etc from a NAS, network share etc], with analog and digital outputs, and an controller app for many platforms (Win, OSX, Android, iOS). I recently replaced my Logitech Squeezebox with one of these. The node 2 itself runs a [stripped down linux](http://zensonic.dk/?p=675)

The OSX app, which is the one i'm most intersted is clearly the poor cousin to the mobile apps, and in particular has 2 serious issues for me


  1. When showing more than a few albums cover art, loading performance for these is terriable, making "a scan artwork to pick an album to play" type experience poor.
  2. There's an Albums view, and an artists view, but no albums by artists view [ala iTunes].

 
With small libraries these probably aren't big deals, but for larger libraries, and plenty of screen realestate they turn what could be a great user experience into frustration.
 
BluShepherd is an exploration by me to see if its possible to build a companion app that solves these 2 issues.
 
The Node exposes a HTTP based API, details of my exploration of that are in [api.md](api.md)
 
 