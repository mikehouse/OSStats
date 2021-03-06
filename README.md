
# MacOS CPU Status

Just simple application that shows the most cpu consumable process in the system.

- info shown in system status bar
- info update interval is 10 seconds

## Why ?

Sometimes strange system processes eat a lot cpu power, for example **photoanalysisd**. To not spend time to open system Activity Monitor application to check what is going on, now it is just a brief look at system status bar.

<img src="Screenshot.png"/>

<img src="Screenshot3.png"/>

## Build from Xcode

Just clone this repo and build the app. Then move app bundle to */Application* directory. 

<img src="Screenshot1.png" width="50%" height="50%" />

## Manually

Unpack **Release.zip** and move app bundle to */Application* directory. Then in *System Preferences -> General* allow the app to run from untrusted developer.

## Launch on Login

- You can do autolaunch of this app at login time via *System Preferences*.

<img src="Screenshot2.png" width="60%" height="60%" />

## License

For source code is MIT, for CPU temperature part is GPL-2.0 License (see *Credits* section below). 

## Credits

Fetching the CPU Temperature based on https://github.com/lavoiesl/osx-cpu-temp with GPL-2.0 License. 
