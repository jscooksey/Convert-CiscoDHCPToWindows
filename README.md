# Convert (Import) Cisco Configuration DHCP into Windows Server DHCP



## Version 0.0.9

### Justin S. Cooksey - 2024-10-13

Scripting to convert Cisco DHCP settings taken from an exported configuration file directly into a Windows DHCP Server.

## Usage

```Powershell
Convert-CiscoDHCPToWindows
```

- It will ask for the DHCP host servername.
- It will require to have administrtor privilegde to be able to export the DHCP scopes.
- Working files are stored under the current %TEMP% path
- Output file is stored in the execution path.



In 2021 I developed the reverse, to [migrate from Windows DHCP Server to Cisco configuration](https://github.com/jscooksey/Convert-WindowsDHCPToCisco) and my [blog post on the script](https://justincooksey.com/blog/2021/2021-03-04-windows-server-dhcp-conversion-to-cisco-cli).  This did get some recent fixes and updates in 2023.
