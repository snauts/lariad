
Some notes on building the game on Ubuntu, Windows, and Mac OS X.


Building game on Ubuntu
-----------------------

Required software packages.

build-essential		(depends on gcc and libc-dev)
libsdl1.2-dev		(SDL)
libsdl-image1.2-dev	(SDL_image)
libsdl-mixer-dev	(SDL_mixer >= 1.2.10)
mesa-common-dev		(OpenGL)
readline-dev		(By default, Lua requires this command line editing
			 library when compiling on Linux. Not really necessary,
			 and luaconf.h can be modified to not use it)

Build Lua & game:
	$ make

Run:
	$ cd lariad
	$ ./lariad


Getting SDL headers on Windows
------------------------------

Download the Mingw32 development version of SDL:
	http://www.libsdl.org/release/SDL-devel-1.2.14-mingw32.tar.gz
Extract in the engine's root folder and rename 'SDL-X.Y.Z' to simply 'SDL'.

Downlaod SDL_image source:
	http://www.libsdl.org/projects/SDL_image/release/SDL_image-1.2.8.zip
from which the header file SDL_image.h goes into SDL/include/SDL. The
rest can be discarded.

Download SDL_mixer source:
	http://www.libsdl.org/projects/SDL_mixer/release/SDL_mixer-1.2.11.zip
Copy SDl_mixer.h from the extracted folder into SDL/include/SDL. The rest can be
discarded.


Getting SDL binaries on Windows (skip this)
-------------------------------------------

These steps are not necessary because the binaries are distributed with the lariad
application.

Download SDL Windows runtime:
	http://www.libsdl.org/release/SDL-1.2.14-win32.zip
Extract in the lariad/ folder.

Download SDL_image binaries:
        http://www.libsdl.org/projects/SDL_image/release/SDL_image-1.2.8-win32.zip
Extract in the lariad folder.

Downlaod SDL_mixer Windows libraries:
	http://www.libsdl.org/projects/SDL_mixer/release/SDL_mixer-1.2.11-win32.zip
Extract in the lariad folder.


Building game for Mac OS X >= 10.6 using Xcode
----------------------------------------------

Install Xcode. 

Download SDL.framework, SDL_image.framework, and SDL_mixer.framework.
Modify their linkage paths by doing:
        $ install_name_tool -id @executable_path/../Frameworks/SDL.framework/SDL /Library/Frameworks/SDL.framework/SDL
        $ install_name_tool -id @executable_path/../Frameworks/SDL_image.framework/SDL_image /Library/Frameworks/SDL_image.framework/SDL_image
        $ install_name_tool -id @executable_path/../Frameworks/SDL_mixer.framework/SDL_mixer /Library/Frameworks/SDL_mixer.framework/SDL_mixer

Build Lua:
	$ cd lua-5.1
	$ make clean && make macosx

Open Lariad.mac project from within Xcode. Build it to produce Lariad.app bundle.


Building game for Mac OS X >= 10.6 using MacPorts
-------------------------------------------------

Install Xcode to get development tools.
Install MacPorts app.

Install SDL, SDL_image, and SDL_mixer:
        $ sudo port install libsdl
        $ sudo port install libsdl_image
        $ sudo port install libsdl_mixer

Build Lua:
        $ cd lua-5.1 && make clean && make macosx

Build game:
        $ make

Run it:
        $ cd lariad && ./lariad

