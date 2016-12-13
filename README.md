# BuildTools.* #

**BuildTools** is a set of NuGet packages to help you get a .NET project up and running.

Follow [@jonwagnerdotcom](http://twitter.com/#!jonwagnerdotcom) for latest updates on this library or [code.jonwagner.com](http://code.jonwagner.com) for more detailed writeups.

## Why You Want This ##

- You should be turning on Code Analysis & StyleCop on your projects.
- You could use BuildTools.MsBuild to write PowerShell scripts to tweak your own projects.

## How to Get It ##

* Install the appropriate package from NuGet. (See below.)

# Features #

* [BuildTools.FxCop](http://nuget.org/packages/BuildTools.FxCop) - automatically enables FxCop / Code Analysis in your project.
	* Requires Visual Studio with Code Analysis
	* Enables FxCop (default is for Release builds only)
	* Treats FxCop issues as Errors (default)
	* Use PowerShell functions to change the defaults
* [BuildTools.StyleCop](http://nuget.org/packages/BuildTools.StyleCop) - automatically installs StyleCop code analysis into your project.
	* Includes the StyleCop binaries, no need to install it separately
	* Works without Visual Studio
	* Enables StyleCop (default is for Release builds only)
	* Treats StyleCop issues as Errors (default)
	* Use PowerShell functions to change the defaults	
* [BuildTools.MsBuild](http://nuget.org/packages/BuildTools.MsBuild) - PowerShell scripts to make it easier to modify MsBuild files.

# Documentation #

**Full documentation is available on the [wiki](https://github.com/jonwagner/BuildTools.NET/wiki)!**

# Good References #

* The [Official StyleCop Project](http://stylecop.codeplex.com).
