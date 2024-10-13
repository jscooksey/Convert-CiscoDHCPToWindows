# Convert (Import) Cisco Configuration DHCP into Windows Server DHCP

## Version 0.0.9

### Justin S. Cooksey - 2024-10-13

Scripting to convert Cisco DHCP settings taken from an exported configuration file directly into a Windows DHCP Server.

## Usage

```Powershell
Convert-CiscoDHCPToWindows
```

- Manual entry of filename to mimport is in the script. **To be changed**
- It will require to have administrtor privilegde to be able to create DHCP scopes etc.



In 2021 I developed the reverse, to [migrate from Windows DHCP Server to Cisco configuration](https://github.com/jscooksey/Convert-WindowsDHCPToCisco) and my [blog post on the script](https://justincooksey.com/blog/2021/2021-03-04-windows-server-dhcp-conversion-to-cisco-cli).  This did get some recent fixes and updates in 2023.
