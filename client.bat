@echo off

pushd src
%~dp0/bin/lua client.lua
popd

pause