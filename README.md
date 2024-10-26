# patterson-finalelua-scripts

Lua scripts for Finale for personal use by Robert Patterson.

---

Many of these scripts are dependent on the libraries at the main [Finale Lua-Scripts repository](https://github.com/finale-lua/lua-scripts). To make the libraries available to this script: 

- Download the Finale Lua-Scripts repository by cloning or downloading it as a zip file. (Use the `Code` button on the GitHub site.)
- Configure the libraries in the RGP System Prefix by adding a line to it as follows (where `<finale-lua-scripts-folder>` the folder of the Finale Lua-Scripts repository you just downloaded.

```lua
package.path = "<finale-lua-scripts-folder>/src/?.lua;" .. package.path
```

This should allow all the scripts to run.

