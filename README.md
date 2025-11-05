<p 
IPMI username:
ADMIN
IPMI password: 
YKHGYFQCHX 
></p>
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░███████╗██╗░░░██╗███████╗░░░░░██████╗░███████╗░██████╗░░░░░
░░░░██╔════╝╚██╗░██╔╝██╔════╝░░░░░╚════██╗██╔════╝██╔═████╗░░░░
░░░░███████╗░╚████╔╝░███████╗█████╗█████╔╝███████╗██║██╔██║░░░░
░░░░╚════██║░░╚██╔╝░░╚════██║╚════╝╚═══██╗╚════██║████╔╝██║░░░░
░░░░███████║░░░██║░░░███████║░░░░░██████╔╝███████║╚██████╔╝░░░░
░░░░╚══════╝░░░╚═╝░░░╚══════╝░░░░░╚═════╝░╚══════╝░╚═════╝░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

## Course Description:

This advanced course will concentrate on current server based virtualization solutions used in
the modern enterprise. This investigation will include VMWare's vSphere and how these
technologies can be leveraged for server consolidation and automation.

Upon completion of the course, students will be able to:
* Hypervisor installation
* Virtual networking
* Network Storage Integration (NFS, ISCSI)
* Clustering and Failover
* Virtualization API's and automation of deployment
* Integration of Server virtualization platforms with Microsoft Active Directory

## Course Outcomes:
* Deploy and Manage Enterprise Hypervisor systems
* Provide users with single sign-on access to systems and applications located across organizations

## IP Address Assignments 
| Host    | IPMI          | Host  (esxi, OpenStack, HyperV) | fw- eth0     | fw- eth1  | xubuntu-wan (MGMT) | vcenter-350x | dc1       | fw-bluex(eth0) 480-WAN | fw-bluex(eth1) BLUEX-LAN |
|---------|---------------|---------------------------------|--------------|-----------|--------------------|--------------|-----------|------------------------|--------------------------|
| super27 | 192.168.3.177 | 192.168.3.227                   | 192.168.3.37 | 10.0.17.2 | 10.0.17.100        | 10.0.17.3    | 10.0.17.4 | 10.0.17.200            | 10.0.5.2                 |

## Course Progression

### Module 01:
* [Course Intro](https://github.com/user-attachments/files/22219048/_Introduction.to.SYS350.1.pdf)
* [Introduction to Hypervisors & vSphere](https://github.com/user-attachments/files/22218043/SYS-350-Module1-Introduction.Continued.pdf)
#### [Milestone 01 ‐ ESXi and Basic Networking](https://github.com/Isaiah-River/SYS-350/wiki/Milestone-01-%E2%80%90-ESXi--and-Basic-Networking)
> **Overview:**
>
> In this [lab](https://github.com/user-attachments/files/22217834/_SYS350.-.Milestone.01.-.Hypervisor.Setup.-.FA25.pdf), I successfully deployed a complete virtual infrastructure on a physical SuperMicro server. The exercise involved installing ESXi 8.x on bare metal hardware, configuring network infrastructure, and establishing a virtualized environment with internal networking capabilities. I created a pfSense firewall VM to handle routing between internal and external networks, along with a management workstation running Xubuntu.

### Module 02:
#### [Milestone 02 ‐ AD and vCenter](https://github.com/Isaiah-River/SYS-350/wiki/Milestone-02-%E2%80%90-AD-and-vCenter)
> **Overview:**
>
> In this [lab](https://github.com/user-attachments/files/22515140/Milestone.2.-.AD.vCenter.and.SSO.Integration.FA25.pdf), I worked to expand my infrastructure by deploying and integrating Active Directory Domain Services with VMware vCenter Server. The lab focused on creating a Windows Server 2019 domain controller deployment, followed by vCenter Server Appliance installation and configuration. The final integration step involved configuring Single Sign-On (SSO) between vCenter and Active Directory.


### Module 03:
#### [Milestone 03 ‐ Additional Networks & Services](https://github.com/Isaiah-River/SYS-350/wiki/Milestone-03-%E2%80%90-Additional-Networks-&-Services)
> **Overview:**
>
> In this [lab](https://github.com/user-attachments/files/23362827/Milestone.3.-.Additional.Networks.Services.pdf), I implemented network segmentation by creating and configuring multiple virtual networks within a vSphere environment. The lab focused on establishing proper network isolation between different functional zones while maintaining appropriate access controls through pfSense firewall rules. I created three distinct network segments: LAN for general user access, DMZ for publicly accessible services, and MGMT for administrative functions. Each network was configured with specific firewall rules to enforce security policies and control inter-network communication.

### Module 04:
#### [Milestone 04 ‐ Nested Virtualization and Templates](https://github.com/Isaiah-River/SYS-350/wiki/Milestone-04-%E2%80%90-Nested-Virtualization-and-Templates)
> **Overview:**
>
> In this [lab](https://github.com/user-attachments/files/23367179/SYS-350.Milestone.4.-.Nested.Virtualization.and.Templates.FA24.1.pdf), I implemented nested virtualization and template-based virtual machine deployment within a vCenter environment. The lab consisted of two major components: first, deploying ESXi hypervisors as virtual machines (nested virtualization) to simulate a multi-host datacenter environment; and second, creating reusable VM templates for Ubuntu and Rocky Linux systems to enable rapid, standardized virtual machine provisioning. I configured DHCP services to support automated IP addressing, created customization specifications for personalized VM deployment, and used vCenter's cloning capabilities to deploy multiple virtual machines from templates with custom configurations.


### Module 05:
* [Automation for VMware](https://github.com/user-attachments/files/23362893/SYS-350.Lecture.4.1.-.Automation.for.VMware.-.FA24.pdf)
#### [Milestone 05.1 ‐ Automation With pyvmomi](https://github.com/Isaiah-River/SYS-350/wiki/Milestone-05.1-%E2%80%90-Automation-With-pyvmomi)
> **Overview:**
>
> In this [lab](https://github.com/user-attachments/files/23362732/SYS-350.Milestone.5.1.-.Automation.with.pyvmomi.-.FA25.pdf), I implemented automation for vCenter Server operations using Python and the pyvmomi library. The project focused on creating a command-line tool to retrieve and display virtual machine information from vCenter without manual point-and-click administration. I developed a Python program that connects to vCenter, retrieves session information, searches for virtual machines by name, and displays comprehensive metadata including CPU, memory, power state, and IP addresses. The implementation leveraged code patterns from the pyvmomi-community-samples repository to ensure best practices and proper API usage.


#### [Milestone 05.2 ‐ More Automation](https://github.com/Isaiah-River/SYS-350/wiki/Milestone-05.2-%E2%80%90-More-Automation)
> **Overview:**
>
> In this [lab](https://github.com/user-attachments/files/23362763/SYS-350.Milestone.5.2.-.More.Automation.with.pyvmomi.-.FA.24.pdf), I extended my Milestone 4.1 vCenter VM Manager program to perform actions on virtual machines rather than just reading information. The project focused on implementing six distinct actions that could be performed on filtered sets of VMs: power management (on/off), snapshot creation and restoration, resource modification (CPU/Memory), network changes, and VM deletion. I built upon the foundation from Milestone 4.1 by adding an actions submenu that allows users to filter VMs by name and then perform batch operations on the filtered results. The implementation continued to leverage code patterns from the pyvmomi-community-samples repository to ensure proper API usage and error handling.


### Module 06:
#### [Milestone 06 ‐ Hyper‐V](https://github.com/Isaiah-River/SYS-350/wiki/Milestone-06-%E2%80%90-Hyper%E2%80%90V)
> **Overview:**
>
> In this [lab](https://github.com/user-attachments/files/23363164/SYS-350.Milestone.6.-.Hyper.V.pdf), I deployed and configured a bare-metal Windows Server 2019 host as a virtualization platform using Microsoft Hyper-V. The lab focused on building a complete hypervisor environment from the ground up, starting with physical server installation and progressing through network configuration, Hyper-V role deployment, and virtual machine creation. I established both external and internal virtual network switches to enable proper network segmentation, installed Windows Admin Center for web-based management, and deployed virtual machines including a pfSense firewall and Windows 11 client to demonstrate a functional virtualized network environment.


### Module 07:
#### [Milestone 07.1 ‐ Hyper-V ‐ Linked Clones and Automation](https://github.com/Isaiah-River/SYS-350/wiki/Milestone-07.1-%E2%80%90-Hyper%E2%80%90V-%E2%80%90-Linked-Clones-and-Automation)
> **Overview:**
>
> In this [lab](https://github.com/user-attachments/files/23363267/SYS-350.Milestone.7.-.HyperV.-.Linked.Clones.and.Automation.pdf), I explored advanced Hyper-V disk management and automation techniques focused on virtual machine cloning and PowerShell scripting. The lab emphasized efficient virtual machine deployment through the use of differencing disks (also known as linked clones), which allow multiple virtual machines to share a common parent disk while maintaining individual changes. I created sealed base images of Ubuntu and Rocky Linux systems, generated child VMs using differencing disks, and developed PowerShell scripts to automate common Hyper-V management tasks including VM lifecycle operations and network configuration changes. This approach demonstrates enterprise-level virtualization practices for rapid deployment and resource optimization.

#### [Milestone 07.2 ‐ Hyper‐V - Automation Continued](https://github.com/Isaiah-River/SYS-350/wiki/Milestone-07.2-%E2%80%90-Hyper%E2%80%90V-%E2%80%90-Automation-Continued)
> **Overview:**
>
>

<!--Back to Top button-->
<p align="center";>
<a href="#"><img alt="Static Badge" src="https://img.shields.io/badge/Back%20to%20Top%20-%20Back%20to%20Top?style=flat&color=%23555"></a>
</p>
