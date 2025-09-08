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

# Navigation
* [Course Description](#course-description)
* [Course Outcomes](#course-outcomes)
* [IP Address Assignments](#ip-address-assignments)
* [Course Progression](#course-progression)
    * [Module 01](#module-01)
        * [Milestone 01 - ESXi and Basic Networking](#milestone-01--esxi-and-basic-networking)

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
* [Course Intro](https://github.com/user-attachments/files/22218032/_SYS350.-.Milestone.1.-.Hypervisor.Setup.-.FA25.pdf)
* [Introduction to Hypervisors & vSphere](https://github.com/user-attachments/files/22218043/SYS-350-Module1-Introduction.Continued.pdf)
#### [Milestone 01 ‐ ESXi and Basic Networking](https://github.com/Isaiah-River/SYS-350/wiki/Milestone-01-%E2%80%90-ESXi--and-Basic-Networking)
> **Overview:**
>
> In this [lab](https://github.com/user-attachments/files/22217834/_SYS350.-.Milestone.01.-.Hypervisor.Setup.-.FA25.pdf), I successfully deployed a complete virtual infrastructure on a physical SuperMicro server. The exercise involved installing ESXi 8.x on bare metal hardware, configuring network infrastructure, and establishing a virtualized environment with internal networking capabilities. I created a pfSense firewall VM to handle routing between internal and external networks, along with a management workstation running Xubuntu.

<!--Back to Top button-->
<p align="center";>
<a href="#"><img alt="Static Badge" src="https://img.shields.io/badge/Back%20to%20Top%20-%20Back%20to%20Top?style=flat&color=%23555"></a>
</p>
