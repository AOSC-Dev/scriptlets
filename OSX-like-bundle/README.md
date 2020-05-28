Cross-platform .app bundle
====

**DO NOT WORK ON THIS THING**. GnuStep has a [multiarch bundle format](https://fedoraproject.org/wiki/PackagingDrafts/GNUstep#.22Fat.22_unflattened_layout)
that already does exactly what I want to do. It's been there for a long time.

I might be drunk when I wrote this.

The .app directory will has a layout almost the same to the one OS X .app
bundle has, but with a ${OS}/ (OS\_ARCH) folder instead of the MacOS/ 
folder. Of course it can support a fat bundle with MacOS/ and many other Arches.

Dependencies
---
This script Depends on:
 - libplist-utils (plistutil)
 - xml2
 - - libxml/libxml2
 - bash

Why do we need the bundle?
---
Bundling often makes distributing applications easier. In OS X, bundling
is also an important solution to provide built-in application icons and so
on.

But why are we using the OS X bundle format?
---
The current OS X format isn't really platform-specific. Of course it can be
simply extended, just like what I am doing now.


So...How will it be like?
---
Here is a directory tree of an example bundle with multi-platform support:
<pre>
MyApp.app/
  Contents/
    Info.plist
    MacOS/
      MyApp
    Linux_i386/
      MyApp
      Frameworks/
        (Linux_i386 libs)
    Linux_x86_64/
      MyApp
      Frameworks/
        (Linux_x86_64 libs)
    DotNET/ (I'm kidding)
      MyApp.exe
      App_Sup.dll
    Resources/
      foo.tiff
      bar.lproj/
    Frameworks/
      (OS X libs)
    Frameworks_common/
    PlugIns/
      (OS X PlugIns)
    PlugIns_common/
    SharedSupport/
</pre>
