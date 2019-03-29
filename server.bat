@echo off

pushd src
%~dp0/bin/lua server.lua
popd

pause