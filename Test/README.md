# R2D2 Testing  
 
Required LUA Libraries
------
```
luarocks install busted
luarocks install xml2lua
luarocks install penlight
```
Testing Framework 
------
|**File**|**Description**|
|----|---|
|`WowApi.lua`|Stubs and implementations of WOW API(s) for use during testing.|
|`WowAddonParser.lua`|Provides ability to parse WOW Addon TOC and XML, primarily for purposes of automating test imports.|
Test Listing 
------
```
cd [directory_with_test(s)]
busted --list --verbose [test_file]
```
Test Execution 
------
```
cd [directory_with_test(s)]
busted --verbose [test_file]
```