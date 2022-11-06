#Load PowerCLI Modules
Import-module VMware.PowerCLI
 
#Variables
#vCenter or Host to Connect to 
$vCenter = "smt-lab-vcsa-01.smt-lab.local"
#ESX Host to target
$ESXHost = Get-VMHost "smt-lab-esx-01.smt-lab.local"
#Name of the iSCSI Switch
$iSCSISwitchName = "vSS_Storage_iSCSI"
#vmnic to be used for iSCSI Switch
$iSCSISwitchNIC = "vmnic2"
#MTU size
$MTU = "9000"
#Name of the Portgroup for the VMKernel Adapter
$iSCSIVMKPortGroupName = "vSS_VMK_iSCSI_A"
#iSCSI VMK IP
$iSCSIIP = "10.200.33.50"
#iSCSI VMK SubnetMask
$iSCSISubnetMask = "255.255.255.0"
#iSCSI VMK VLAN ID
$VLANID = "300"
#iSCSI Portal Target
$Target = "10.200.33.1:3260"
 
#Connect to vCenter
Connect-VIServer $vCenter -Credential (Get-Credential) -Force
 
#New Standard Switch for iSCSI
$NewSwitch = New-VirtualSwitch -VMHost $ESXHost -Name $iSCSISwitchName -Nic $iSCSISwitchNIC -Mtu $MTU
$NewPortGroup = New-VMHostNetworkAdapter -VMhost $ESXHost -PortGroup $iSCSIVMKPortGroupName -VirtualSwitch $NewSwitch -IP $iSCSIIP -SubnetMask $iSCSISubnetMask -Mtu $MTU
Set-VirtualPortGroup -VirtualPortGroup (Get-virtualPortGroup -VMhost $ESXHost | Where {$_.Name -eq $iSCSIVMKPortGroupName}) -VLanId $VLANID
 
#Enable Software iSCSI Adapter
Get-VMHostStorage -VMHost $ESXHost | Set-VMHostStorage -SoftwareIScsiEnabled $True
 
#Bind the iSCSI VMKernel Adapter to Software iSCSI Adapter (credit to Luc Dekens for this)
$esxcli = Get-EsxCli -V2 -VMHost $ESXHost
$bind = @{
    adapter = ($iscsiHBA = $ESXHost | Get-VMHostHba -Type iScsi | Where {$_.Model -eq "iSCSI Software Adapter"}).Device
    force = $true
    nic = $NewPortGroup.Name
}
$esxcli.iscsi.networkportal.add.Invoke($bind)
 
#Add Dynamic Discovery Target
$ESXHost | Get-VMHostHba $iscsiHBA | New-IScsiHbaTarget -Address $Target
 
#Rescan Hba
Get-VMHostStorage -VMHost $ESXHost -RescanAllHba